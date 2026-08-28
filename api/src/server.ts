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

type Vars = { Variables: { session: Session } }

const app = new Hono<Vars>()

app.get('/health', (c) => c.json({ ok: true }))

/**
 * Every route below this line has a student. There is no anonymous path into
 * the product, because every row in the database is scoped to one.
 */
/**
 * Two routes have no student. /health answers a load balancer, and /jobs/drain
 * is driven by a scheduler and carries its own shared secret. Everything else
 * below the middleware has a student, because every row does.
 */
const noSession = new Set(['/health', '/jobs/drain'])

app.route('/', jobs)

app.use('*', async (c, next) => {
  if (noSession.has(c.req.path)) return next()

  const header = c.req.header('authorization')
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  const session = await resolveSession(token)

  if (!session) return c.json({ error: 'unknown student' }, 401)

  c.set('session', session)
  await next()
})

// Signing in is above the rest because it is the one route whose bearer is
// still the roster reference. It needs a student to attach an Apple account
// to, which is why it lives inside this block rather than in front of it.
app.route('/', auth)

app.route('/', entries)
app.route('/', reads)
app.route('/', cards)
app.route('/', transcription)
app.route('/', consent)
app.route('/', profile)
app.route('/', peopleRoutes)

app.onError((error, c) => {
  console.error(error)
  return c.json({ error: 'something went wrong' }, 500)
})

serve({ fetch: app.fetch, port: env.port }, (info) => {
  console.log(`soul api listening on ${info.port}`)
})
