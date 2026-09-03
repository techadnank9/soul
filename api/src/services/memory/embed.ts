import { and, eq } from 'drizzle-orm'
import { db, entries, entryEmbeddings } from '../../db.js'
import { embed } from '../../gateway/call.js'
import type { Session } from '../../session.js'

/**
 * One entry, one vector.
 *
 * The semantic layer of memory. An entry from April about the same situation
 * as today's is invisible to the context builder unless a tag happens to
 * match, and this is what makes it visible: the Mirror asks for the nearest
 * entries by meaning and this row is what it measures against.
 *
 * Runs in the background, off the request path, booked by submit the same
 * way the tagger is. An entry that is not yet embedded is simply not found
 * by meaning until it is, and nothing waits on it.
 *
 * Written with an upsert, so a job that runs twice on one entry overwrites
 * one row rather than failing on a key it already wrote.
 */
export async function embedEntry(entryId: string, session: Session): Promise<boolean> {
  const rows = await db
    .select({ text: entries.text })
    .from(entries)
    .where(and(eq(entries.id, entryId), eq(entries.studentId, session.studentId)))
    .limit(1)

  const entry = rows[0]
  if (!entry) return false

  const result = await embed({ text: entry.text, session, entryId })

  await db
    .insert(entryEmbeddings)
    .values({
      entryId,
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      embedding: result.vector,
      modelVersion: result.model,
    })
    .onConflictDoUpdate({
      target: entryEmbeddings.entryId,
      set: { embedding: result.vector, modelVersion: result.model },
    })

  return true
}
