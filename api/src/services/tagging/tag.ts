import { eq } from 'drizzle-orm'
import { db, entries, tags } from '../../db.js'
import { call } from '../../gateway/call.js'
import { taggerResult } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * Flow 4. Tagging, async.
 *
 * Runs after the student has already seen their response, so tagging quality
 * never costs latency. Never move this onto the request path to make the code
 * simpler.
 *
 * Values describe situations, never traits. "Avoided a conflict", not
 * "avoidant". The prompt enforces it and the review in task 9 checks it.
 */
export const TAGGER_VERSION = 'tagger-2026-08-a'

export async function tagEntry(entryId: string, session: Session): Promise<void> {
  const rows = await db
    .select({ text: entries.text })
    .from(entries)
    .where(eq(entries.id, entryId))
    .limit(1)

  const entry = rows[0]
  if (!entry) return

  const result = await call('tagger', {
    user: entry.text,
    schema: taggerResult,
    session,
    entryId,
  })

  await db.insert(tags).values({
    entryId,
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    trigger: result.value.trigger,
    feeling: result.value.feeling,
    coping: result.value.coping,
    domain: result.value.domain,
    confidence: result.value.confidence,
    taggerVersion: TAGGER_VERSION,
  })
}
