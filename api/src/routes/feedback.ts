import { Hono } from 'hono'
import { z } from 'zod'
import { db, feedback as feedbackTable } from '../db.js'
import type { Session } from '../session.js'

/**
 * What somebody said about the app itself.
 *
 * The one thing a person writes that is addressed to us rather than to
 * themselves, which is why it is the one thing that goes to the funnels as
 * text as well as into this table. Everything they write about their own
 * life stays out of there.
 *
 * No model call, no classifier and no consent gate. Nothing leaves for a
 * third party on this path except the funnels, which the person is opting
 * into by writing to us, and nothing is generated from it. It is a row and a
 * log line.
 */
type Vars = { Variables: { session: Session } }

export const feedback = new Hono<Vars>()

const body = z.object({
  text: z.string().trim().min(1).max(4000),

  /// Which screen they were on. A fixed name from the client, never free
  /// text, so it can be grouped without being cleaned.
  surface: z.string().regex(/^[a-z_]{2,40}$/).optional(),
  appVersion: z.string().max(40).optional(),
})

feedback.post('/feedback', async (c) => {
  const parsed = body.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid feedback' }, 400)

  const session = c.get('session')
  const { text, surface, appVersion } = parsed.data

  // The length rather than the words. What they said is in the table and in
  // the funnels, and the service log is read over somebody's shoulder.
  console.log(
    `feedback ${text.length} chars from=${surface ?? 'unknown'} user=${session.studentId.slice(0, 8)}`,
  )

  await db.insert(feedbackTable).values({
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    text,
    surface: surface ?? null,
    appVersion: appVersion ?? null,
  })

  return c.json({ ok: true })
})
