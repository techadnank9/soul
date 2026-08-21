import { db, sql, cueCards } from '../../db.js'
import { call } from '../../gateway/call.js'
import { cueCardsResult } from './schema.js'
import type { Session } from '../../session.js'

/**
 * Cue cards, async.
 *
 * Runs after the entry has been tagged, never on the request path. A student
 * has had their response and gone by the time this starts, which is what lets
 * it read a week of entries and take a hundred seconds to decide that most of
 * them point at nothing.
 *
 * Three rules hold the feature up and all three are enforced here rather than
 * in the prompt alone:
 *
 *   a card is only ever about something the student actually named, so every
 *   card has to name the entry it came from and that entry has to be one of
 *   the ones we sent
 *
 *   only entries that passed the safety classifier are read, so a flagged
 *   entry cannot become a question about what to do next
 *
 *   nothing already asked is asked again, and the same thing worded a second
 *   way is still the same thing
 *
 * What is not enforced here is how many. A day carries the cards it has,
 * which is usually none and occasionally three, and the bar a card clears is
 * about meaning rather than a count. That bar lives in the prompt because it
 * is a judgement about what is still open and what a person could say back,
 * and no query can make it.
 *
 * The card now asks one question the student answers yes or no. The shape of
 * that question is checked in schema.ts, which can see a question mark and a
 * list and nothing else. Whether no is a real answer, which is the half that
 * decides if the card should exist, is in the prompt for the same reason the
 * rest of the bar is.
 */

/** How much of the recent past the model gets to look forward from. */
const RECENT_ENTRIES = 12

/**
 * How far back the already asked list reaches.
 *
 * Long enough that a thing named again next week is not asked about twice,
 * short enough that a term old card does not silence a real one.
 */
const ALREADY_ASKED_DAYS = 30

/**
 * How much of the shorter of two cards has to be the same words before they
 * are one thing. Set so that two words of three are the same thing and one
 * word of two is not: the coursework due Friday and the coursework due on
 * Friday are one card, the exam on Tuesday and the exam on Friday are two.
 */
const SAME_THING = 0.6

type EntryRow = { id: string; on: string; text: string }

/**
 * The student's own timezone, UTC when they have not given one.
 *
 * The dates on the entries the model reads are theirs, not the server's, for
 * the same reason the week screen is: an entry written at nine on Sunday
 * evening in Los Angeles is Sunday, and a model told it was Monday would
 * write a card about a day that has already gone.
 */
async function zoneOf(session: Session): Promise<string> {
  const rows = await sql<{ timezone: string | null }[]>`
    select timezone from students where id = ${session.studentId} limit 1`
  return rows[0]?.timezone ?? 'UTC'
}

/**
 * Whether this entry is one the model is allowed to read.
 *
 * An entry with no safety row has not passed anything. Written entries always
 * have one, because the classifier writes on every entry, hit or miss.
 */
async function passedSafety(entryId: string, session: Session): Promise<boolean> {
  const rows = await sql<{ id: string }[]>`
    select e.id
    from entries e
    join safety_flags f on f.entry_id = e.id
    where e.id = ${entryId}
      and e.student_id = ${session.studentId}
      and f.risk_level in ('none', 'low')
    limit 1`
  return rows.length > 0
}

/**
 * The context. Recent entries that passed safety, oldest first, numbered so a
 * card can point back at one of them.
 *
 * Dates are formatted by the database in the student's zone, so the model can
 * tell Friday from today without anything on this side parsing a timestamp.
 */
async function recentEntries(session: Session, zone: string): Promise<EntryRow[]> {
  const rows = await sql<EntryRow[]>`
    select
      e.id,
      to_char(e.created_at at time zone ${zone}, 'Dy DD Mon YYYY') as "on",
      e.text
    from entries e
    join safety_flags f on f.entry_id = e.id
    where e.student_id = ${session.studentId}
      and f.risk_level in ('none', 'low')
    order by e.created_at desc
    limit ${RECENT_ENTRIES}`

  return rows.reverse()
}

/** What this student has already been asked, so nothing is asked twice. */
async function alreadyAsked(session: Session): Promise<string[]> {
  const rows = await sql<{ about: string }[]>`
    select about
    from cue_cards
    where student_id = ${session.studentId}
      and created_at > now() - (interval '1 day' * ${ALREADY_ASKED_DAYS})
    order by created_at desc`
  return rows.map((row) => row.about)
}

/**
 * The words a student puts around a thing rather than the thing itself.
 *
 * Taking these out is what lets the coursework due Friday and the coursework
 * that is due on Friday come down to the same three words. Nothing here names
 * anything, so nothing here can be the reason two cards look alike.
 */
const EMPTY_WORDS = new Set([
  'a', 'an', 'the', 'this', 'that', 'these', 'those', 'my', 'me', 'i', 'im',
  'our', 'your', 'their', 'about', 'and', 'or', 'but', 'for', 'from', 'of',
  'on', 'in', 'at', 'to', 'with', 'by', 'is', 'are', 'was', 'were', 'be',
  'been', 'am', 'do', 'does', 'did', 'have', 'has', 'had', 'it', 'its',
  'still', 'again', 'yet', 'not', 'no', 'so', 'then', 'there', 'they', 'them',
  'thing', 'things', 'something', 'before', 'after', 'next', 'last', 'one',
  'up', 'out', 'who', 'what', 'when', 'we', 'us',
])

/**
 * What a card is about, reduced to the words that carry it.
 *
 * Lowercased, punctuation dropped, plurals folded onto the singular, and the
 * words above taken out. The trials on Tuesday and the trial on Tuesday come
 * out the same, which is the whole point.
 */
function thingWords(about: string): Set<string> {
  const words = about
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .split(/\s+/)
    .filter((word) => word.length > 0 && !EMPTY_WORDS.has(word))
    .map((word) => (word.length > 3 && word.endsWith('s') ? word.slice(0, -1) : word))
  return new Set(words)
}

/**
 * Whether two cards are about the same thing.
 *
 * The guard used to be an exact string match, which meant a card reworded by
 * one word was a second card about a thing the student had already been
 * asked. This asks how much of the shorter card is inside the longer one
 * instead, so a rewording is caught and a different day is not.
 *
 * One word in common is only enough when it is the whole of the shorter card.
 * Two longer cards that share a single word share a coincidence.
 *
 * The model is told the same rule in stronger words and is the first thing
 * that should catch this. This is what happens when it does not. It is meant
 * to lean towards refusing, because no card is an acceptable answer here and
 * being asked twice about one thing is not.
 */
export function sameThing(one: string, other: string): boolean {
  const a = thingWords(one)
  const b = thingWords(other)
  if (!a.size || !b.size) return false

  // A different day makes it a different thing, whatever else the words share.
  //
  // The overlap rule alone called the maths test on Monday and the maths test
  // on Thursday the same thing, because two of the three words matched, and
  // silently dropped the second one. Two exams in one week is exactly the
  // situation this feature exists for, so the day settles it before the word
  // counting starts.
  const whenA = whenWords(a)
  const whenB = whenWords(b)
  if (whenA.size && whenB.size) {
    let sharedWhen = 0
    for (const word of whenA) if (whenB.has(word)) sharedWhen += 1
    if (sharedWhen === 0) return false
  }

  let shared = 0
  for (const word of a) if (b.has(word)) shared += 1
  if (!shared) return false

  const smaller = Math.min(a.size, b.size)
  if (shared === 1 && smaller > 1) return false

  return shared / smaller >= SAME_THING
}

/** The words in a card that say when, if it says when at all. */
function whenWords(words: Set<string>): Set<string> {
  const when = new Set<string>()
  for (const word of words) if (WHEN_WORDS.has(word)) when.add(word)
  return when
}

const WHEN_WORDS = new Set([
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
  'today',
  'tonight',
  'tomorrow',
  'weekend',
  'january',
  'february',
  'march',
  'april',
  'may',
  'june',
  'july',
  'august',
  'september',
  'october',
  'november',
  'december',
])

function render(today: string, entries: EntryRow[], asked: string[]): string {
  const numbered = entries
    .map((entry, index) => `  ${index + 1}. [${entry.on}] ${entry.text}`)
    .join('\n')

  const list = asked.length ? asked.map((about) => `  ${about}`).join('\n') : '  none'

  return [
    `Today is ${today}.`,
    `Recent entries, oldest first:\n${numbered}`,
    `Cards already asked:\n${list}`,
  ].join('\n\n')
}

/**
 * Writes the cards this student's entries point at, which is usually none.
 *
 * Returns how many were written, which is what the runner logs. Nothing is
 * returned to a student from here: the cards are read off the day screen the
 * next time they look at it.
 */
export async function generateCards(entryId: string, session: Session): Promise<number> {
  if (!(await passedSafety(entryId, session))) return 0

  const zone = await zoneOf(session)

  const entries = await recentEntries(session, zone)
  if (!entries.length) return 0

  const dates = await sql<{ today: string }[]>`
    select to_char(now() at time zone ${zone}, 'Dy DD Mon YYYY') as today`
  const today = dates[0]?.today ?? ''

  const asked = await alreadyAsked(session)

  const result = await call('cue_cards', {
    user: render(today, entries, asked),
    schema: cueCardsResult,
    session,
    entryId,
  })

  // Grows as the reply is read, so two cards in one answer about the same
  // thing land the same way a card repeated a week later does.
  const seen = [...asked]
  let written = 0

  for (const card of result.value.cards) {
    // The card has to point at an entry we actually sent. A number outside
    // the list means the model wrote about something it made up, and that
    // card is dropped rather than the whole set, because another one may be
    // about a thing the student really did name.
    const source = entries[card.from - 1]
    if (!source) continue

    if (seen.some((other) => sameThing(card.about, other))) continue
    seen.push(card.about)

    await db.insert(cueCards).values({
      entryId: source.id,
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      about: card.about,
      question: card.question,
      promptVersion: result.promptVersion,
      modelVersion: result.model,
    })

    written += 1
  }

  return written
}
