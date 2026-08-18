import { db, patternCandidates } from '../db.js'
import { findCandidates } from '../services/patterns/findCandidates.js'

/**
 * The nightly sweep. A query, not a model call.
 *
 * Writes candidates only. Nothing here is shown to a student until they open
 * the app and ask to look closer, and nothing becomes a pattern until they say
 * it is one.
 */
export async function sweep(): Promise<number> {
  const candidates = await findCandidates()

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
