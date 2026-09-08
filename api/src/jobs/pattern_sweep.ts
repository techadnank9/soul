import { db, patternCandidates } from '../db.js'
import { findCandidates } from '../services/patterns/findCandidates.js'

/**
 * The sweep. A query, not a model call.
 *
 * Writes candidates only. Nothing here is shown to a student until they open
 * the app and ask to look closer, and nothing becomes a pattern until they say
 * it is one.
 *
 * Runs two ways. Nightly over everybody, as it always has, and again for one
 * person the moment their entry has been tagged, so a third entry on the same
 * theme is offered back that evening rather than after the next three in the
 * morning. The one person run reads the same query with the same threshold,
 * so neither can be a looser definition of a pattern than the other.
 * Decision 258.
 */
export async function sweep(studentId?: string): Promise<number> {
  const candidates = await findCandidates(studentId)

  for (const candidate of candidates) {
    await db.insert(patternCandidates).values({
      studentId: candidate.studentId,
      schoolId: candidate.schoolId,
      districtId: candidate.districtId,
      theme: candidate.theme,
      supportingEntryIds: candidate.supportingEntryIds,
    })
  }

  return candidates.length
}

if (process.argv[1]?.endsWith('pattern_sweep.ts')) {
  sweep()
    .then((count) => {
      console.log(`${count} candidates proposed`)
      process.exit(0)
    })
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
}
