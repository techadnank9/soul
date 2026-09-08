import { Hono } from 'hono'
import { and, eq } from 'drizzle-orm'
import { db, reminders as remindersTable } from '../db.js'
import { upcomingReminders } from '../services/reminders/extract.js'
import type { Session } from '../session.js'

/**
 * What somebody said they would do, and when.
 *
 * The phone reads this and schedules a local notification for each one. The
 * server never sends a push: there is no device token anywhere in this
 * system, nothing about a person leaves for a notification service, and a
 * phone that is switched off simply rings when it is next on rather than
 * having been tracked. Decision 256.
 *
 * GET returns only what is still ahead. DELETE takes one back, which is a
 * thing a person is allowed to do about anything the app holds.
 */
type Vars = { Variables: { session: Session } }

export const reminders = new Hono<Vars>()

reminders.get('/reminders', async (c) => {
  const rows = await upcomingReminders(c.get('session'))
  return c.json({
    reminders: rows.map((r) => ({
      id: r.id,
      dueAt: r.dueAt.toISOString(),
      said: r.said,
    })),
  })
})

reminders.delete('/reminders/:id', async (c) => {
  const session = c.get('session')

  // The id from the request is matched against the session's student as well
  // as being the id. The write side runs on the pooled handle, so the where
  // clause is what scopes it rather than row level security. Decision 188.
  const done = await db
    .update(remindersTable)
    .set({ cancelledAt: new Date() })
    .where(
      and(
        eq(remindersTable.id, c.req.param('id')),
        eq(remindersTable.studentId, session.studentId),
      ),
    )
    .returning({ id: remindersTable.id })

  if (done.length === 0) return c.json({ error: 'no such reminder' }, 404)
  return c.json({ ok: true })
})
