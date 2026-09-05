import { and, eq, isNull } from 'drizzle-orm'
import { db, cueCards } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Later.
 *
 * A card that is not the thing somebody wants to think about right now is
 * put off rather than answered, and comes back tomorrow. It is a statement
 * about timing and not about the question, so nothing is written down about
 * what they think and no decision is booked.
 *
 * Scoped to the student and to cards not already answered, so an id from
 * somewhere else defers nothing.
 */
const A_DAY = 24 * 60 * 60 * 1000

export async function deferCard(session: Session, cardId: string): Promise<boolean> {
  const rows = await db
    .update(cueCards)
    .set({ deferredUntil: new Date(Date.now() + A_DAY) })
    .where(
      and(
        eq(cueCards.id, cardId),
        eq(cueCards.studentId, session.studentId),
        isNull(cueCards.answeredAt),
      ),
    )
    .returning({ id: cueCards.id })

  return rows.length > 0
}
