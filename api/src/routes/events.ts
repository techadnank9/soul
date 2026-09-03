import { Hono } from 'hono'
import { z } from 'zod'
import { db, appEvents } from '../db.js'
import type { Session } from '../session.js'

/**
 * The app reporting what it did.
 *
 * One row per event and one log line per event, so a failure on a phone can
 * be read live in the service logs and later in the table. The name is one of
 * a fixed set the client chooses. The detail is small and never carries what
 * a person wrote or said: a status code, a byte count, a screen name.
 */
type Vars = { Variables: { session: Session } }

export const events = new Hono<Vars>()

const body = z.object({
  name: z.string().regex(/^[a-z_]{2,60}$/),
  detail: z.record(z.string(), z.union([z.string().max(300), z.number(), z.boolean(), z.null()])).optional(),
  appVersion: z.string().max(40).optional(),
})

events.post('/events', async (c) => {
  const parsed = body.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid event' }, 400)

  const session = c.get('session')
  const { name, detail, appVersion } = parsed.data

  console.log(`app ${name} ${JSON.stringify(detail ?? {})} user=${session.studentId.slice(0, 8)}`)

  await db.insert(appEvents).values({
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    name,
    detail: detail ?? null,
    appVersion: appVersion ?? null,
  })

  return c.json({ ok: true })
})
