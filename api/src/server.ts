import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { env } from './env.js'
import { resolveSession, type Session } from './session.js'
import { entries } from './routes/entries.js'
import { reads } from './routes/reads.js'
import { cards } from './routes/cards.js'
import { transcription } from './routes/transcribe.js'
import { consent } from './routes/consent.js'
import { profile } from './routes/profile.js'
import { peopleRoutes } from './routes/people.js'
import { auth } from './routes/auth.js'
import { jobs } from './routes/jobs.js'
import { events } from './routes/events.js'

type Vars = { Variables: { session: Session } }

const app = new Hono<Vars>()

app.get('/health', (c) => c.json({ ok: true }))

/**
 * Every route below this line has a student. There is no anonymous path into
 * the product, because every row in the database is scoped to one.
 */
/**
 * Five routes have no session. /health answers a load balancer, /jobs/drain
 * is driven by a scheduler and carries its own shared secret, and the three
 * account routes are how a session comes to exist: a phone asking for its
 * first account, an address asking for a code, and a code being checked.
 * Everything else below the middleware has a user, because every row does.
 */
const noSession = new Set([
  '/health',
  '/jobs/drain',
  '/auth/device',
  '/auth/email/start',
  '/auth/email/verify',
])

app.route('/', jobs)

app.use('*', async (c, next) => {
  if (noSession.has(c.req.path)) return next()

  const header = c.req.header('authorization')
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  const session = await resolveSession(token)

  if (!session) return c.json({ error: 'unknown user' }, 401)

  c.set('session', session)
  await next()
})

// Sign in with Apple needs the device's session, so it lives inside this
// block. The three account routes above are let through by name.
app.route('/', auth)

app.route('/', entries)
app.route('/', reads)
app.route('/', cards)
app.route('/', transcription)
app.route('/', consent)
app.route('/', profile)
app.route('/', peopleRoutes)
app.route('/', events)

app.onError((error, c) => {
  console.error(`${c.req.method} ${c.req.path} failed:`, error)
  return c.json({ error: 'something went wrong' }, 500)
})

serve({ fetch: app.fetch, port: env.port }, (info) => {
  console.log(`soul api listening on ${info.port}`)
})
