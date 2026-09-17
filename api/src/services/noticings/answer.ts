import { and, eq } from 'drizzle-orm'
import { db, noticings } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Yes, no and not sure, stored as equals. Decision 275.
 *
 * Every write here is scoped to the student as well as the id. This runs on
 * the pooled handle, outside asStudent, so row level security is not the
 * guard, and without the student a noticing id belonging to somebody else
 * could be answered from another account.
 */
export async function answerNoticing(
  session: Session,
  input: { noticingId: string; answer: 'yes' | 'no' | 'unsure' },
): Promise<void> {
  const status = { yes: 'confirmed', no: 'rejected', unsure: 'unsure' } as const

  const updated = await db
    .update(noticings)
    .set({ status: status[input.answer], answeredAt: new Date() })
    .where(
      and(
        eq(noticings.id, input.noticingId),
        eq(noticings.studentId, session.studentId),
        eq(noticings.status, 'open'),
      ),
    )
    .returning({ id: noticings.id })

  if (updated.length === 0) throw new Error('noticing not found')
}
