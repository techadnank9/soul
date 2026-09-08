import { eq } from 'drizzle-orm'
import { db, students, auditLog } from '../../db.js'
import { nearestRegion, timezoneFor } from '../../profile/regions.js'
import type { Session } from '../../session.js'
import { intentAreaTheme, type SaveProfile } from '../../contracts.js'

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

  if (input.intentArea !== undefined) patch.intentArea = input.intentArea
  if (input.intentReason !== undefined) patch.intentReason = input.intentReason

  if (Object.keys(patch).length === 0) return

  patch.profileRecordedAt = new Date()

  await db.update(students).set(patch).where(eq(students.id, session.studentId))

  if (input.intentArea !== undefined) await frontOfRing(session, input.intentArea)

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

/**
 * Put what they said they came for at the front of the week ring.
 *
 * The ring is filled by the themes the welcome call named from the baseline
 * answers, until the tagger has named one from something they actually wrote.
 * This is the same list with one theme moved to the front of it, in the app's
 * own words, so somebody who said the people close to them sees that first
 * rather than whatever the model put first.
 *
 * No model call and no new column: it rewrites the list already there. A
 * theme by the same name is dropped rather than shown twice, and the weight
 * is the largest one already in the list, so the answer is the biggest slice
 * without being a bigger number than anything the model could produce.
 *
 * Emptying the area in the profile tab takes the theme out again, and an
 * account whose entries have already named a theme is untouched by any of
 * this, because the ring stops reading this list the moment there is a real
 * one.
 */
type OpeningTheme = { name: string; weight: number }

async function frontOfRing(session: Session, area: string | null): Promise<void> {
  const rows = await db
    .select({ themes: students.openingThemes })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  const held = (rows[0]?.themes ?? []) as OpeningTheme[]
  if (!Array.isArray(held)) return

  const name = area === null ? null : intentAreaTheme[area] ?? null

  // Every name this function has ever put in front, so switching from one
  // area to another leaves one theme rather than two.
  const ours = new Set(
    Object.values(intentAreaTheme)
      .filter((t): t is string => t !== null)
      .map((t) => t.toLowerCase()),
  )

  const rest = held.filter(
    (t) => !ours.has(String(t.name).toLowerCase()),
  )

  if (name === null) {
    await db
      .update(students)
      .set({ openingThemes: rest })
      .where(eq(students.id, session.studentId))
    return
  }

  const weight = rest.reduce((top, t) => Math.max(top, t.weight ?? 0), 0) || 1

  await db
    .update(students)
    .set({ openingThemes: [{ name, weight }, ...rest] })
    .where(eq(students.id, session.studentId))
}
