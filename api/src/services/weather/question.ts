import { call } from '../../gateway/call.js'
import { weatherQuestion, type WeatherAsk } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The one question on the card at the top of home, written from what the
 * sky is doing where they are.
 *
 * The phone reads the weather from Apple and says what it found. This turns
 * that into a sentence that says the weather and asks about their day in
 * the same breath, so the card is one line rather than three.
 *
 * Held per person, per sky, per part of the day. Home is opened many times
 * a day and the sky changes a few times, so this is a handful of calls
 * rather than one per open. Nothing waits on it: the card appears when it
 * lands and the app has a plain question of its own if it never does.
 */
const HELD_MS = 3 * 60 * 60 * 1000
const held = new Map<string, { at: number; question: string }>()

export async function weatherQuestionFor(
  session: Session,
  ask: WeatherAsk,
): Promise<string | null> {
  const key = `${session.studentId}:${ask.condition}:${part(ask)}`
  const cached = held.get(key)
  if (cached && Date.now() - cached.at < HELD_MS) return cached.question

  const said = [
    `The sky: ${ask.condition}.`,
    `Temperature: ${ask.degrees} degrees ${ask.fahrenheit ? 'fahrenheit' : 'celsius'}.`,
    `Part of the day: ${part(ask)}.`,
    ask.place ? `Where: ${ask.place}.` : null,
  ]
    .filter(Boolean)
    .join('\n')

  try {
    const result = await call('weather_question', {
      user: said,
      schema: weatherQuestion,
      session,
    })
    held.set(key, { at: Date.now(), question: result.value.question })
    return result.value.question
  } catch (error) {
    console.warn(`weather question: ${(error as Error).message}`)
    return null
  }
}

/**
 * Morning, afternoon, evening or night, from the phone's own idea of
 * daylight and nothing else. It is the one thing that makes the same sky
 * read differently at eight and at ten.
 */
function part(ask: WeatherAsk): string {
  const hour = new Date().getUTCHours()
  if (!ask.daylight) return 'after dark'
  if (hour < 11) return 'morning'
  if (hour < 16) return 'afternoon'
  return 'late afternoon'
}
