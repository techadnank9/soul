import { and, eq } from 'drizzle-orm'
import { db, patternCandidates } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Attaches a waiting candidate to a Mirror, as a question.
 *
 * A pattern is never asserted. It is proposed, hedged, and stored only when
 * the student confirms it. The wording here has to be rejectable without the
 * student feeling they got something wrong.
 */
export async function surfaceCandidate(
  session: Session,
): Promise<{ candidateId: string; proposal: string } | null> {
  const rows = await db
    .select({ id: patternCandidates.id, theme: patternCandidates.theme })
    .from(patternCandidates)
    .where(
      and(
        eq(patternCandidates.studentId, session.studentId),
        eq(patternCandidates.status, 'pending'),
      ),
    )
    .limit(1)

  const row = rows[0]
  if (!row) return null

  await db
    .update(patternCandidates)
    .set({ status: 'surfaced', surfacedAt: new Date() })
    .where(eq(patternCandidates.id, row.id))

  return {
    candidateId: row.id,
    proposal:
      `This feels close to something you have written before, around ` +
      `${row.theme}. Does that connection fit for you?`,
  }
}
