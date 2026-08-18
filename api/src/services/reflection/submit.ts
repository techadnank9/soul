import { checkConsent } from '../../consent/gate.js'
import { classify } from '../../safety/classify.js'
import { helpScreen } from '../../safety/help.js'
import { storeEntry, markProcessed } from '../../entries/store.js'
import { beatOne } from '../../generate/beatOne.js'
import { enqueue } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'
import type { SubmitEntry, SubmitResult } from '../../contracts.js'

/**
 * The orchestrator. This is the path that matters, and the order is the point.
 *
 *   1. consent      no consent, nothing goes out, entry stored unprocessed
 *   2. store        the entry exists before anything is said about it
 *   3. safety       blocking, always written, hit or miss
 *   4. beat one     only reached if safety passed
 *   5. enqueue      tagging and embedding, nobody waits
 *
 * Consent and safety come before generation, so there is no code path where
 * they can be skipped. This function does not call the tagger. It enqueues it.
 */
export async function submit(
  session: Session,
  input: SubmitEntry,
): Promise<SubmitResult> {
  // 1. Consent. Checked before the entry is written, so a held entry is never
  //    mistaken for a processed one.
  const consented = await checkConsent(session, 'third_party_processing')

  const entryId = await storeEntry(session, input)

  if (!consented) {
    return { state: 'held', entryId }
  }

  // 2. Safety. Blocking. Nothing is generated before this returns.
  const verdict = await classify(input.text, session, entryId)

  if (verdict.blocked) {
    const help = await helpScreen()
    return { state: 'help', entryId, ...help }
  }

  // 3. Beat one. The first thing the student reads.
  const { line } = await beatOne(input.text, session, entryId)

  // 4. Everything that can happen later, happens later. The student already
  //    has their response by the time any of this runs.
  await markProcessed(entryId)
  await enqueue('tag_entry', { entryId }, session)
  await enqueue('embed_entry', { entryId }, session)

  return { state: 'reflected', entryId, line }
}
