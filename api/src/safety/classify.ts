import { db, safetyFlags } from '../db.js'
import { call } from '../gateway/call.js'
import { safetyResult } from '../contracts.js'
import type { Session } from '../session.js'

/**
 * The safety classifier. Blocking, on the write path, before any generation
 * exists so it can never be skipped later.
 *
 * The threshold is biased toward false positives. It reads a transcript that
 * may be imperfect, on a population where speech recognition is weakest. A
 * wrongly flagged entry costs a student one screen. A missed one costs much
 * more.
 */
export const CLASSIFIER_VERSION = 'safety-2026-08-a'

export type Classification = {
  riskLevel: 'none' | 'low' | 'medium' | 'high'
  categories: string[]
  blocked: boolean
}

/** medium and above shows the help screen instead of a reflection. */
function blocks(riskLevel: Classification['riskLevel']): boolean {
  return riskLevel === 'medium' || riskLevel === 'high'
}

export async function classify(
  text: string,
  session: Session,
  entryId: string,
): Promise<Classification> {
  let riskLevel: Classification['riskLevel']
  let categories: string[]
  let actionTaken: string

  try {
    const result = await call('safety', {
      user: text,
      schema: safetyResult,
      session,
      entryId,
    })
    riskLevel = result.value.riskLevel
    categories = result.value.categories
    actionTaken = blocks(riskLevel) ? 'help_screen' : 'reflected'
  } catch {
    // If the classifier cannot answer, the entry is treated as unsafe to
    // reflect on. Failing open here would mean generating a response to an
    // entry nobody has checked, which is the one outcome this path exists to
    // prevent.
    riskLevel = 'high'
    categories = ['classifier_unavailable']
    actionTaken = 'help_screen_classifier_unavailable'
  }

  const blocked = blocks(riskLevel)

  // Written on every entry, hit or miss. Its own record with a status field,
  // because it becomes a workflow when the counsellor console exists.
  await db.insert(safetyFlags).values({
    entryId,
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    riskLevel,
    categories,
    classifierVersion: CLASSIFIER_VERSION,
    actionTaken,
    resourcesShown: blocked,
    status: blocked ? 'open' : 'closed',
  })

  return { riskLevel, categories, blocked }
}
