import { weatherWhere } from './now.js'
import type { Session } from '../../session.js'

/**
 * A reading of the sky, for development builds only.
 *
 * The app reads the weather from Apple on the device. WeatherKit needs a
 * provisioning profile carrying its entitlement, and a simulator build is
 * signed to run locally whatever is asked of it, so on a simulator Apple
 * declines and the card never appears. That made every simulator test look
 * like the feature was broken.
 *
 * This is the same reading from Open Meteo, which is free for what this is:
 * somebody developing the app. Release builds never call it. Their weather
 * comes from Apple and their position never leaves the phone.
 *
 * The shape matches what the Swift channel returns, so one mapping in the
 * app turns either into words.
 */
export type Reading = {
  condition: string
  celsius: number
  daylight: boolean
}

export async function reading(session: Session): Promise<Reading | null> {
  const where = await weatherWhere(session)
  if (!where) return null

  const url = new URL('https://api.open-meteo.com/v1/forecast')
  url.searchParams.set('latitude', where.latitude.toFixed(2))
  url.searchParams.set('longitude', where.longitude.toFixed(2))
  url.searchParams.set('current', 'temperature_2m,weather_code,is_day')

  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(8000) })
    if (!response.ok) {
      const detail = await response.text().catch(() => '')
      console.warn(`weather reading: open meteo returned ${response.status}: ${detail.slice(0, 200)}`)
      return null
    }
    const data = (await response.json()) as {
      current?: { temperature_2m?: number; weather_code?: number; is_day?: number }
    }
    const current = data.current
    if (!current || current.weather_code == null || current.temperature_2m == null) {
      console.warn(`weather reading: nothing usable in ${JSON.stringify(data).slice(0, 200)}`)
      return null
    }

    return {
      condition: conditionFor(current.weather_code),
      celsius: current.temperature_2m,
      daylight: current.is_day !== 0,
    }
  } catch (error) {
    console.warn(`weather reading: ${(error as Error).message}`)
    return null
  }
}

/**
 * World meteorological codes in Apple's own vocabulary, so the app has one
 * mapping from a condition to words rather than two.
 */
function conditionFor(code: number): string {
  if (code === 0) return 'clear'
  if (code <= 2) return 'mostlyclear'
  if (code === 3) return 'cloudy'
  if (code <= 48) return 'foggy'
  if (code <= 57) return 'drizzle'
  if (code <= 67) return 'rain'
  if (code <= 77) return 'snow'
  if (code <= 82) return 'rain'
  if (code <= 86) return 'snow'
  return 'thunderstorms'
}
