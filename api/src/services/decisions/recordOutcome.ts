import { and, eq, sql as raw } from 'drizzle-orm'
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
  /**
   * The decision has to be this student's before anything is written about it.
   *
   * Checked rather than assumed: this runs outside asStudent, and without it an
   * outcome row could be attached to somebody else's decision and that decision
   * closed, which would end their check back and silently change what their
   * patterns screen says about them.
   */
  const owned = await db
    .select({ id: decisions.id })
    .from(decisions)
    .where(and(eq(decisions.id, input.decisionId), eq(decisions.studentId, session.studentId)))
    .limit(1)

  if (!owned[0]) throw new Error('decision not found')

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
    .where(and(eq(decisions.id, input.decisionId), eq(decisions.studentId, session.studentId)))
}

/**
 * Called by the runner when a check back went unanswered.
 *
 * Nothing calls this yet. It takes a session anyway, so that whatever does call
 * it has to have resolved a student first rather than reaching for a bare id.
 */
export async function recordIgnored(
  session: Session,
  decisionId: string,
): Promise<void> {
  await db
    .update(outcomes)
    .set({ ignoredCount: raw`${outcomes.ignoredCount} + 1` })
    .where(and(eq(outcomes.decisionId, decisionId), eq(outcomes.studentId, session.studentId)))
}
