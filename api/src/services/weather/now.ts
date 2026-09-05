import { eq } from 'drizzle-orm'
import { db, students } from '../../db.js'
import { centreOf, timezoneFor, type Region } from '../../profile/regions.js'
import type { Session } from '../../session.js'

/**
 * Where to ask about the weather, and whether the card has been answered
 * today.
 *
 * The weather itself is not fetched here. The phone asks Apple for it
 * through WeatherKit, on the device, so no coordinates leave the phone at
 * all and no third party is told where somebody is. This answers the two
 * things the phone cannot work out for itself: which position to use when
 * only a region was picked, and whether today has already been answered.
 */
export type WeatherWhere = {
  latitude: number
  longitude: number

  /** Fahrenheit in the United States, because that is what is meant there. */
  fahrenheit: boolean

  /** Answered today, so home shows no card until tomorrow. */
  answeredToday: boolean
}

export async function weatherWhere(session: Session): Promise<WeatherWhere | null> {
  const rows = await db
    .select({
      latitude: students.latitude,
      longitude: students.longitude,
      region: students.region,
      timezone: students.timezone,
      answeredOn: students.weatherAnsweredOn,
    })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  const row = rows[0]
  if (!row) return null

  // Their own position when they shared one, the middle of the region they
  // picked when they did not, and nothing at all when there is neither.
  const centre = row.region ? centreOf(row.region as Region) : null
  const latitude = row.latitude ?? centre?.[0]
  const longitude = row.longitude ?? centre?.[1]
  if (latitude == null || longitude == null) return null

  return {
    latitude,
    longitude,
    fahrenheit: (row.region ?? '').startsWith('us_'),
    answeredToday: row.answeredOn === todayIn(row.timezone ?? timezoneFor('elsewhere')),
  }
}

/** Their own calendar day, so a card answered at eleven at night is not new at midnight. */
function todayIn(zone: string | null): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone ?? 'UTC',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  })
  return formatter.format(new Date())
}

/** Called when an entry is written from the card. */
export async function weatherAnswered(session: Session): Promise<void> {
  const rows = await db
    .select({ timezone: students.timezone })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  await db
    .update(students)
    .set({ weatherAnsweredOn: todayIn(rows[0]?.timezone ?? null) })
    .where(eq(students.id, session.studentId))
}
