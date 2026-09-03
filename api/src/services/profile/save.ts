import { eq } from 'drizzle-orm'
import { db, students, auditLog } from '../../db.js'
import { nearestRegion, timezoneFor } from '../../profile/regions.js'
import type { Session } from '../../session.js'
import type { SaveProfile } from '../../contracts.js'

/**
 * The profile, written once at first run and editable after.
 *
 * Only the fields that arrived are written. A student who answered two
 * questions and closed the app keeps those two answers, and finishing later
 * fills in the rest rather than starting again.
 *
 * A field that arrived as null is emptied. Taking an answer back is a thing a
 * student is allowed to do, and it has to reach the column rather than only
 * the screen.
 *
 * The timezone is derived from the region here. It is never taken from the
 * client.
 */
export async function saveProfile(
  session: Session,
  input: SaveProfile,
): Promise<void> {
  const patch: Record<string, unknown> = {}

  if (input.displayName !== undefined) patch.displayName = input.displayName
  if (input.place !== undefined) patch.place = input.place
  if (input.ageBand !== undefined) patch.ageBand = input.ageBand
  if (input.gender !== undefined) patch.gender = input.gender
  if (input.region !== undefined) {
    patch.region = input.region
    // The zone is derived, so it goes when the region it came from goes.
    patch.timezone = input.region === null ? null : timezoneFor(input.region)
  }

  // Coordinates decide the region rather than accompanying it. They are
  // handled after the picked region on purpose, so a measured location wins
  // and the two can never disagree in the same row.
  if (input.latitude !== undefined || input.longitude !== undefined) {
    const both =
      typeof input.latitude === 'number' && typeof input.longitude === 'number'

    // A pair or nothing. Half a pair is a position the profile tab cannot show
    // and therefore cannot delete, which is the one thing this column must
    // never be.
    patch.latitude = both ? input.latitude : null
    patch.longitude = both ? input.longitude : null

    if (both) {
      const region = nearestRegion(input.latitude as number, input.longitude as number)
      patch.region = region
      patch.timezone = timezoneFor(region)
    }
  }

  if (Object.keys(patch).length === 0) return

  patch.profileRecordedAt = new Date()

  await db.update(students).set(patch).where(eq(students.id, session.studentId))

  // Districts have inspection rights and will ask what is held about a child
  // and when it was given. The field names are recorded, never the values.
  await db.insert(auditLog).values({
    actorId: session.studentId,
    actorRole: 'student',
    action: `profile_recorded:${Object.keys(patch).sort().join(',')}`,
    subjectStudentId: session.studentId,
    subjectType: 'student',
    subjectId: session.studentId,
  })
}
