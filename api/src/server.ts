import * as Sentry from '@sentry/node'
import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { env } from './env.js'

/**
 * Errors go to Sentry when a DSN is set, alongside the log line. The DSN is
 * an address, not a secret, and without one nothing here does anything.
 * No personal data is attached: the student id is the only identifier and
 * it is our own.
 */
if (env.sentryDsn()) {
  Sentry.init({
    dsn: env.sentryDsn(),
    environment: process.env.RENDER ? 'render' : 'laptop',
    release: process.env.RENDER_GIT_COMMIT,
    tracesSampleRate: 0.2,
    sendDefaultPii: false,
  })
}
import { resolveSession, type Session } from './session.js'
import { entries } from './routes/entries.js'
import { reads } from './routes/reads.js'
import { graph } from './routes/graph.js'
import { cards } from './routes/cards.js'
import { transcription } from './routes/transcribe.js'
import { consent } from './routes/consent.js'
import { profile } from './routes/profile.js'
import { peopleRoutes } from './routes/people.js'
import { auth } from './routes/auth.js'
import { jobs } from './routes/jobs.js'
import { events } from './routes/events.js'
import { speech } from './routes/speech.js'
import { welcome } from './routes/welcome.js'

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
  '/auth/demo',
  '/auth/email/start',
  '/auth/email/verify',
  '/auth/apple',
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

// The account routes are let through by name above, and each resolves the
// bearer itself when it is there.
app.route('/', auth)

app.route('/', entries)
app.route('/', reads)
app.route('/', graph)
app.route('/', cards)
app.route('/', transcription)
app.route('/', consent)
app.route('/', profile)
app.route('/', peopleRoutes)
app.route('/', events)
app.route('/', speech)
app.route('/', welcome)

app.onError((error, c) => {
  console.error(`${c.req.method} ${c.req.path} failed:`, error)
  Sentry.captureException(error, {
    tags: { route: c.req.path, method: c.req.method },
    user: c.get('session') ? { id: c.get('session').studentId } : undefined,
  })
  return c.json({ error: 'something went wrong' }, 500)
})

serve({ fetch: app.fetch, port: env.port }, (info) => {
  console.log(`soul api listening on ${info.port}`)
})
