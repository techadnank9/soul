import { db, safetyFlags } from '../db.js'
import { call } from '../gateway/call.js'
import { safetyResult } from '../contracts.js'
import type { Session } from '../session.js'

/**
 * The safety classifier. Blocking, on the write path, before any generation
 * exists so it can never be skipped later.
 *
 * It records. It does not stop anything. Decision 276: no verdict puts a
 * screen between a person and their reflection. Every entry still gets a
 * safety_flags row, a medium or high one is left open for a human to read,
 * and the cue cards still refuse to read an entry rated medium or above.
 *
 * The threshold is biased toward false positives. It reads a transcript that
 * may be imperfect. Since a flag no longer costs the person anything, the
 * bias is free.
 */
export const CLASSIFIER_VERSION = 'safety-2026-08-a'

export type Classification = {
  riskLevel: 'none' | 'low' | 'medium' | 'high'
  categories: string[]
}

/** medium and above is left open in safety_flags for a person to review. */
function worthReview(riskLevel: Classification['riskLevel']): boolean {
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
    actionTaken = 'reflected'
  } catch {
    // If the classifier cannot answer, the entry is recorded as unread rather
    // than as safe: high, with the reason in the categories, and left open.
    // The reflection still happens. Before decision 276 this showed the help
    // screen to everybody whenever a provider key was missing.
    riskLevel = 'high'
    categories = ['classifier_unavailable']
    actionTaken = 'reflected_classifier_unavailable'
  }

  const open = worthReview(riskLevel)

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
    resourcesShown: false,
    status: open ? 'open' : 'closed',
  })

  return { riskLevel, categories }
}
