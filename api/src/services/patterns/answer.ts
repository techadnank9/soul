import { eq } from 'drizzle-orm'
import { db, patternCandidates, confirmedPatterns, patternRejections } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Confirmations and rejections are both stored.
 *
 * A rejection is not a failure. It is training signal, and it stops us
 * offering the same wrong idea twice. Nothing is written to confirmed_patterns
 * without a student confirmation and at least three supporting entry ids.
 */
export async function answerCandidate(
  session: Session,
  input: { candidateId: string; answer: 'fits' | 'not_the_same' | 'later'; reason?: string },
): Promise<void> {
  const rows = await db
    .select({
      theme: patternCandidates.theme,
      supporting: patternCandidates.supportingEntryIds,
    })
    .from(patternCandidates)
    .where(eq(patternCandidates.id, input.candidateId))
    .limit(1)

  const candidate = rows[0]
  if (!candidate) throw new Error('candidate not found')

  if (input.answer === 'later') {
    await db
      .update(patternCandidates)
      .set({ status: 'pending', surfacedAt: null })
      .where(eq(patternCandidates.id, input.candidateId))
    return
  }

  if (input.answer === 'fits') {
    if (candidate.supporting.length < 3) {
      throw new Error('a pattern needs at least three supporting entries')
    }

    await db.insert(confirmedPatterns).values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      theme: candidate.theme,
      supportingEntryIds: candidate.supporting,
    })

    await db
      .update(patternCandidates)
      .set({ status: 'confirmed' })
      .where(eq(patternCandidates.id, input.candidateId))
    return
  }

  await db.insert(patternRejections).values({
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    theme: candidate.theme,
    reason: input.reason ?? null,
  })

  await db
    .update(patternCandidates)
    .set({ status: 'rejected' })
    .where(eq(patternCandidates.id, input.candidateId))
}
