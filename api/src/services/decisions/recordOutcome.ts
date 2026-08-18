import { eq, sql as raw } from 'drizzle-orm'
import { db, decisions, outcomes } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * The outcome, stored either way.
 *
 * An ignored check back is written too. A student who does not answer has told
 * us something, and a pattern built only on the times they replied would be a
 * pattern about replying.
 */
export async function recordOutcome(
  session: Session,
  input: {
    decisionId: string
    whatHappened?: string
    felt?: 'lighter' | 'same' | 'worse'
  },
): Promise<void> {
  await db.insert(outcomes).values({
    decisionId: input.decisionId,
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    whatHappened: input.whatHappened ?? null,
    felt: input.felt ?? null,
    respondedAt: new Date(),
  })

  await db
    .update(decisions)
    .set({ status: 'closed' })
    .where(eq(decisions.id, input.decisionId))
}

/** Called by the runner when a check back went unanswered. */
export async function recordIgnored(decisionId: string): Promise<void> {
  await db
    .update(outcomes)
    .set({ ignoredCount: raw`${outcomes.ignoredCount} + 1` })
    .where(eq(outcomes.decisionId, decisionId))
}
