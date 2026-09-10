import { eq } from 'drizzle-orm'
import { db, entries, students } from '../db.js'
import type { Session } from '../session.js'
import type { SubmitEntry } from '../contracts.js'

/** Insert the entry and return its id. No audio, ever. The transcript is the record. */
export async function storeEntry(
  session: Session,
  input: SubmitEntry,
): Promise<string> {
  const rows = await db
    .insert(entries)
    .values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      text: input.text,
      inputMode: input.inputMode,
      transcriptConfirmed: input.transcriptConfirmed,
      durationMs: input.durationMs ?? null,
      localHour: input.localHour ?? null,
    })
    .returning({ id: entries.id })

  const row = rows[0]
  if (!row) throw new Error('entry insert returned no row')
  return row.id
}

export async function markProcessed(entryId: string): Promise<void> {
  await db.update(entries).set({ processed: true }).where(eq(entries.id, entryId))
}

/** Point the student row at the entry they introduced themselves with. */
export async function markIntroduction(session: Session, entryId: string): Promise<void> {
  await db
    .update(students)
    .set({ introductionEntryId: entryId })
    .where(eq(students.id, session.studentId))
}
