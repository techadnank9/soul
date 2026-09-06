import { and, desc, eq, isNotNull } from 'drizzle-orm'
import { db, entries, students, tags } from '../../db.js'
import { call } from '../../gateway/call.js'
import { weatherQuestion, type WeatherAsk } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The one question on the card at the top of home.
 *
 * It is the first thing somebody reads when they open the app, so it is not
 * a prompt asking how they are. It is written from what is true around them
 * at that moment: the part of the day, the day of the week, the season,
 * what the sky is doing when the phone could read it, and what they last
 * wrote about when there is one.
 *
 * The last part is the one that makes it feel familiar rather than
 * generated. It is the situation they were in, from the tagger, never the
 * feeling that was named on it and never their own sentence quoted back at
 * them.
 *
 * Held per person, per context, per part of the day. Home is opened many
 * times a day, so this is a handful of calls rather than one per open.
 * Nothing waits on it: the card appears when it lands and the app has a
 * plain question of its own if it never does.
 */
const HELD_MS = 3 * 60 * 60 * 1000
const held = new Map<string, { at: number; question: string }>()

export async function weatherQuestionFor(
  session: Session,
  ask: WeatherAsk,
): Promise<string | null> {
  const last = await lastTime(session)
  const key = [
    session.studentId,
    ask.condition ?? 'nosky',
    part(ask),
    ask.weekday,
    last?.entryId ?? 'first',
  ].join(':')
  const cached = held.get(key)
  if (cached && Date.now() - cached.at < HELD_MS) return cached.question

  // One angle, chosen here rather than by the model. Given everything it
  // knows it writes everything it knows, and the card read "What has this
  // mostly clear autumn Saturday evening in Union Square held?", which is
  // five facts and no question anybody would ask.
  const chosen = angle(ask, last, await season(session, ask.month))

  for (let go = 0; go < 2; go++) {
    let written: string
    try {
      const result = await call('weather_question', {
        user: chosen.said,
        schema: weatherQuestion,
        session,
      })
      // It is a question and it is read at a glance, so it ends the way a
      // question ends whatever came back.
      written = result.value.question.trim().replace(/[.?!]*$/, '') + '?'
    } catch (error) {
      console.warn(`weather question: ${(error as Error).message}`)
      return chosen.plain
    }

    const wrong = wrongWith(written)
    if (!wrong) {
      held.set(key, { at: Date.now(), question: written })
      return written
    }
    console.warn(`weather question rejected, ${wrong}: ${written}`)
  }

  // Twice is enough. The written question is the better one when it comes,
  // and the plain one always makes sense, which is the part that matters.
  held.set(key, { at: Date.now(), question: chosen.plain })
  return chosen.plain
}

/**
 * The one thing the question is about, and the sentence to fall back on.
 *
 * Where they left off first, because it is the only thing on the card that
 * could not have been written by any app on the phone. Then the sky, which
 * is at least about today. Then the day itself, which is always true.
 *
 * The model is told this one thing and nothing else, so it cannot stack
 * them.
 */
function angle(
  ask: WeatherAsk,
  last: { ago: string; about: string } | null,
  season: string,
): { said: string; plain: string } {
  const when = part(ask)
  const day = WEEKDAYS[ask.weekday - 1] ?? 'today'

  if (last) {
    return {
      said: [
        `They last wrote ${last.ago}, about ${last.about}.`,
        `It is ${when} for them.`,
        'Write the question about that, as somebody who was there would ask it.',
      ].join('\n'),
      plain: `Where did ${last.about} get to?`,
    }
  }

  if (ask.condition) {
    const sky = ask.condition.toLowerCase()
    return {
      said: [
        `The sky is ${sky}, and it is ${when} for them.`,
        ask.place ? `They are in ${ask.place}.` : null,
        'Write the question about the sky and the time, and nothing else.',
      ]
        .filter(Boolean)
        .join('\n'),
      plain: `What has this ${sky} ${when} been like?`,
    }
  }

  return {
    said: [
      `It is ${day} ${when} for them, in ${season}.`,
      'Write the question about the day itself, and nothing else.',
    ].join('\n'),
    plain: `What has ${day} held so far?`,
  }
}

/**
 * Why a written question cannot go on the card, or nothing when it can.
 *
 * The card is the first thing somebody reads, so it is checked before it is
 * shown rather than hoped about. Every one of these has actually come back
 * from the model at least once.
 */
function wrongWith(question: string): string | null {
  const words = question.split(/\s+/).filter(Boolean)
  if (words.length > 11) return 'too long'
  if (words.length < 3) return 'too short'
  if (!question.endsWith('?')) return 'not a question'
  if (/\d/.test(question)) return 'has a number'
  if (/[.!]/.test(question.slice(0, -1))) return 'more than one sentence'
  if (/[-\u2010-\u2015]/.test(question)) return 'has a dash'

  const said = question.toLowerCase()
  const banned = [
    'how are you',
    'how do you feel',
    'feeling',
    'your day',
    'your mood',
    'energy',
    'vibe',
    'unfolding',
    'i noticed',
    'i remember',
    'thinking about you',
    'where you are',
    'your area',
  ]
  for (const phrase of banned) {
    if (said.includes(phrase)) return `says ${phrase}`
  }

  // Four adjectives about the sky and the calendar in one breath is the
  // failure this whole path exists to stop.
  const stacked = ['clear', 'cloudy', 'rain', 'autumn', 'winter', 'spring', 'summer'].filter(
    (word) => said.includes(word),
  ).length
  const days = WEEKDAYS.filter((day) => said.includes(day.toLowerCase())).length
  if (stacked + days > 2) return 'stacks the context'

  return null
}

/**
 * Where they left off: the situation behind the last thing they wrote, and
 * roughly how long ago in words rather than a count.
 *
 * The trigger is what was going on. The domain is the part of life it was
 * in, and it stands in when the tagger found no trigger. The feeling is
 * deliberately not read: the card never names one back at somebody, and a
 * question built on top of a feeling from four days ago is a question about
 * a person rather than about a situation.
 *
 * Null when there is nothing yet, which is most of somebody's first day.
 */
async function lastTime(
  session: Session,
): Promise<{ entryId: string; ago: string; about: string } | null> {
  try {
    const rows = await db
      .select({
        id: entries.id,
        createdAt: entries.createdAt,
        trigger: tags.trigger,
        domain: tags.domain,
      })
      .from(entries)
      .leftJoin(tags, eq(tags.entryId, entries.id))
      .where(eq(entries.studentId, session.studentId))
      .orderBy(desc(entries.createdAt))
      .limit(1)

    const row = rows[0]
    const about = row?.trigger ?? row?.domain
    if (!row || !about) return null

    const days = Math.floor((Date.now() - row.createdAt.getTime()) / 86_400_000)
    const ago =
      days < 1 ? 'earlier today' : days < 2 ? 'yesterday' : days < 8 ? 'this week' : 'a while ago'
    return { entryId: row.id, ago, about }
  } catch (error) {
    console.warn(`weather question, last time: ${(error as Error).message}`)
    return null
  }
}

/**
 * The season where they are, which is the opposite one below the equator.
 * Read from the position the profile holds, because the phone's own is
 * never sent here.
 */
async function season(session: Session, month: number): Promise<string> {
  const north = ['winter', 'spring', 'summer', 'autumn'] as const
  const turn = Math.floor(((month % 12) / 3) % 4)

  let below = false
  try {
    const rows = await db
      .select({ latitude: students.latitude })
      .from(students)
      .where(and(eq(students.id, session.studentId), isNotNull(students.latitude)))
      .limit(1)
    below = (rows[0]?.latitude ?? 1) < 0
  } catch {
    // The north is where most of them are, and the season is one of five
    // things in the prompt rather than the whole of it.
  }

  return below ? north[((turn + 2) % 4) as 0 | 1 | 2 | 3] : north[turn as 0 | 1 | 2 | 3]
}

const WEEKDAYS = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
]

/**
 * Morning, afternoon, evening or night, from the hour on the phone. It is
 * the one thing that makes the same day read differently at eight and at
 * ten, and it is theirs rather than the server's idea of the time.
 *
 * The words are the ones somebody says. Late afternoon was one of these
 * once and the model put it in the sentence, which is not a thing anybody
 * says about a day.
 */
function part(ask: WeatherAsk): string {
  if (ask.hour < 5) return 'night'
  if (ask.hour < 12) return 'morning'
  if (ask.hour < 17) return 'afternoon'
  if (ask.hour < 22) return 'evening'
  return 'night'
}
