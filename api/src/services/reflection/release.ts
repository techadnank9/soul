import { and, eq, notExists } from 'drizzle-orm'
import { db, entries, safetyFlags } from '../../db.js'
import { classify } from '../../safety/classify.js'
import { markProcessed } from '../../entries/store.js'
import { enqueue } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'

/**
 * Entries written before consent was recorded, let through once it is.
 *
 * A person makes an account on first launch and writes their introduction
 * before they reach the screen that asks them to agree, so that entry is
 * stored held with nothing sent out. When they agree, this runs in the queue
 * and does what submit() would have done, in the same order: the safety
 * classifier first, blocking, and only then the tagger and the embedding.
 * Nothing is written back, because nobody is waiting on a screen for it.
 */
export async function releaseHeld(session: Session): Promise<number> {
  const held = await db
    .select({ id: entries.id, text: entries.text })
    .from(entries)
    .where(
      and(
        eq(entries.studentId, session.studentId),
        eq(entries.processed, false),
        notExists(db.select().from(safetyFlags).where(eq(safetyFlags.entryId, entries.id))),
      ),
    )

  let released = 0
  for (const entry of held) {
    const verdict = await classify(entry.text, session, entry.id)
    if (verdict.blocked) continue
    await markProcessed(entry.id)
    await enqueue('tag_entry', { entryId: entry.id }, session)
    await enqueue('embed_entry', { entryId: entry.id }, session)
    released += 1
  }
  return released
}
