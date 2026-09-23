import { and, eq } from 'drizzle-orm'
import { db, entries, entryEmbeddings, tags } from '../../db.js'
import { enqueue } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'

/**
 * The words of a moment, changed by the person who wrote them.
 *
 * They said it in thirty seconds, or typed it on a phone, and it came out
 * wrong or carried a name they would rather it did not. The entry is theirs.
 *
 * What has to happen with it: everything read out of the old words is read
 * again. The tags are deleted and the tagger is booked afresh, and the
 * embedding goes the same way, because a vector of a sentence that is no
 * longer there is how an entry from April gets retrieved for a reason that
 * stopped being true.
 *
 * What does not happen: beat one and the reading are not written again. They
 * were an answer to what was said at the time and rewriting them would put
 * words in the app's mouth about a moment it never saw. The line they were
 * given stays as the line they were given.
 *
 * Facts already extracted are left alone too, and that is the known gap. A
 * fact read out of a sentence that has since changed keeps the sentence it
 * was read from, which is right for a record and wrong for a correction, and
 * the answer is probably to retire the facts standing on this entry alone
 * and let the extractor run again. It is not written yet. Decision 300.
 */
export async function rewordEntry(
  session: Session,
  entryId: string,
  text: string,
): Promise<void> {
  const said = text.trim()
  if (!said) throw new Error('a moment cannot be emptied, only deleted')
  if (said.length > 8000) throw new Error('too long')

  const mine = and(eq(entries.id, entryId), eq(entries.studentId, session.studentId))

  const rows = await db.select({ text: entries.text }).from(entries).where(mine).limit(1)
  if (!rows[0]) throw new Error('entry not found')
  if (rows[0].text.trim() === said) return

  await db.update(entries).set({ text: said }).where(mine)

  // Read again from the new words.
  await db.delete(tags).where(eq(tags.entryId, entryId))
  await db.delete(entryEmbeddings).where(eq(entryEmbeddings.entryId, entryId))
  await enqueue('tag_entry', { entryId }, session)
  await enqueue('embed_entry', { entryId }, session)
}
