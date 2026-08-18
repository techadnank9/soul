import { eq } from 'drizzle-orm'
import { db, students, districts } from '../db.js'
import type { Session } from '../session.js'

/**
 * Nothing leaves for a third party before consent is confirmed for that
 * student.
 *
 * This sits in front of every outbound call, transcription and models both.
 * Without it the entry is stored unprocessed and nothing goes out.
 */
export type ConsentPurpose = 'third_party_processing'

export async function checkConsent(
  session: Session,
  _purpose: ConsentPurpose,
): Promise<boolean> {
  const rows = await db
    .select({
      recordedAt: students.consentRecordedAt,
      version: students.consentVersion,
      model: districts.consentModel,
    })
    .from(students)
    .innerJoin(districts, eq(students.districtId, districts.id))
    .where(eq(students.id, session.studentId))
    .limit(1)

  const row = rows[0]
  if (!row) return false

  // Consent is a recorded event with a version, not a flag. A student whose
  // district changed its agreement has not consented to the new one.
  return Boolean(row.recordedAt && row.version)
}
