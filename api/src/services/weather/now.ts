import { eq } from 'drizzle-orm'
import { db, students } from '../../db.js'
import { centreOf, type Region } from '../../profile/regions.js'
import type { Session } from '../../session.js'

/**
 * The weather where somebody is, and a question that follows from it.
 *
 * Open Meteo, which needs no key and no account. What leaves is a pair of
 * coordinates rounded to two places, which is about a kilometre, and nothing
 * that says who they are. Exact coordinates are held for other reasons and
 * this is not one of them.
 *
 * Held for twenty minutes per person, because home is opened more often than
 * the sky changes and a home screen should not wait on somebody else's
 * service twice in a minute.
 *
 * The line is written here rather than by a model. It is four words about
 * the sky, it has to be right rather than interesting, and a model call on
 * the home path would cost a second every time the app is opened.
 */
export type Weather = {
  line: string
  question: string
}

type Held = { at: number; weather: Weather | null }

const HELD_MS = 20 * 60 * 1000
const held = new Map<string, Held>()

export async function weatherNow(session: Session): Promise<Weather | null> {
  const cached = held.get(session.studentId)
  if (cached && Date.now() - cached.at < HELD_MS) return cached.weather

  const weather = await look(session)
  held.set(session.studentId, { at: Date.now(), weather })
  return weather
}

async function look(session: Session): Promise<Weather | null> {
  const rows = await db
    .select({
      latitude: students.latitude,
      longitude: students.longitude,
      region: students.region,
      place: students.place,
    })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  const row = rows[0]
  if (!row) return null

  // Their own coordinates when they shared them, the middle of the region
  // they picked when they did not, and nothing at all when there is neither.
  const centre = row.region ? centreOf(row.region as Region) : null
  const latitude = row.latitude ?? centre?.[0]
  const longitude = row.longitude ?? centre?.[1]
  if (latitude == null || longitude == null) return null

  // Fahrenheit for the United States, because that is what is meant there by
  // a number about the weather.
  const american = (row.region ?? '').startsWith('us_')

  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', latitude.toFixed(2))
  url.searchParams.set('longitude', longitude.toFixed(2))
  url.searchParams.set('current', 'temperature_2m,weather_code,is_day')
  url.searchParams.set('temperature_unit', american ? 'fahrenheit' : 'celsius')

  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(4000) })
    if (!response.ok) {
      console.warn(`weather: open meteo returned ${response.status}`)
      return null
    }
    const data = (await response.json()) as {
      current?: { temperature_2m?: number; weather_code?: number; is_day?: number }
    }
    const current = data.current
    if (!current || current.weather_code == null || current.temperature_2m == null) return null

    const sky = skyFor(current.weather_code, current.is_day === 0)
    const degrees = Math.round(current.temperature_2m)
    // The place if the phone named one, otherwise no place at all rather
    // than the name of a region nobody says out loud.
    const where = row.place ? ` in ${row.place.split(',')[0]!.trim()}` : ''

    return {
      line: `${sky.words}${where}, ${degrees} degrees.`,
      question: sky.question,
    }
  } catch (error) {
    console.warn(`weather: ${(error as Error).message}`)
    return null
  }
}

/**
 * The world meteorological codes, in the words somebody would use looking
 * out of a window, and one question that fits that kind of day.
 *
 * The questions ask and do not tell. None of them names a feeling, suggests
 * one, or implies the weather ought to have done something to them.
 */
function skyFor(code: number, night: boolean): { words: string; question: string } {
  if (code === 0) {
    return night
      ? { words: 'Clear tonight', question: 'How has today ended up?' }
      : { words: 'Clear', question: 'How is today going so far?' }
  }
  if (code <= 2) return { words: 'Mostly clear', question: 'How is today going so far?' }
  if (code === 3) return { words: 'Overcast', question: 'How is today going so far?' }
  if (code <= 48) return { words: 'Fog', question: 'What is today like so far?' }
  if (code <= 57) return { words: 'Drizzle', question: 'How is it going in that?' }
  if (code <= 67) return { words: 'Rain', question: 'How is it going in that?' }
  if (code <= 77) return { words: 'Snow', question: 'How is it going in that?' }
  if (code <= 82) return { words: 'Showers', question: 'How is it going in that?' }
  if (code <= 86) return { words: 'Snow showers', question: 'How is it going in that?' }
  return { words: 'Thunderstorms', question: 'How is it going in that?' }
}
