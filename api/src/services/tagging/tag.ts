import { eq } from 'drizzle-orm'
import { db, entries, tags } from '../../db.js'
import { call } from '../../gateway/call.js'
import { enqueue } from '../../jobs/enqueue.js'
import { taggerResult } from '../../contracts.js'
import { renderTone } from '../tone/render.js'
import { loadTone } from '../tone/store.js'
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

  // A spoken entry is described with how it sounded. The words still come
  // first and the prompt says the voice may sharpen the feeling or lower the
  // confidence, never replace what was said.
  const tone = await loadTone(entryId, session)
  const user = tone
    ? `${entry.text}\n\nHow they sounded, from their voice:\n${renderTone(tone)}`
    : entry.text

  const result = await call('tagger', {
    user,
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

  // Cue cards go last and in their own job, so a card is never the reason an
  // entry ends up untagged. The tags are what the rest of the system is built
  // on and this call is the longest one in the queue.
  await enqueue('cue_cards', { entryId }, session)

  // The people in the entry, from the entry's own words. Booked here for the
  // same reason the cards are: the tagger is the last thing that has to
  // succeed, and neither of these can be the reason an entry goes untagged.
  await enqueue('people', { entryId }, session)
}
