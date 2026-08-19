import { serve } from '@hono/node-server'
import { Hono } from 'hono'
import { env } from './env.js'
import { resolveSession, type Session } from './session.js'
import { entries } from './routes/entries.js'
import { transcription } from './routes/transcribe.js'
import { consent } from './routes/consent.js'

type Vars = { Variables: { session: Session } }

const app = new Hono<Vars>()

app.get('/health', (c) => c.json({ ok: true }))

/**
 * Every route below this line has a student. There is no anonymous path into
 * the product, because every row in the database is scoped to one.
 */
app.use('*', async (c, next) => {
  if (c.req.path === '/health') return next()

  const header = c.req.header('authorization')
  const token = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  const session = await resolveSession(token)

  if (!session) return c.json({ error: 'unknown student' }, 401)

  c.set('session', session)
  await next()
})

app.route('/', entries)
app.route('/', transcription)
app.route('/', consent)

app.onError((error, c) => {
  console.error(error)
  return c.json({ error: 'something went wrong' }, 500)
})

serve({ fetch: app.fetch, port: env.port }, (info) => {
  console.log(`soul api listening on ${info.port}`)
})
