import type { Session } from '../../session.js'

/**
 * The one notification a day, and the argument for it.
 *
 * Everything else this app sends rings because a person named a time out
 * loud. This does not. It is the app deciding somebody might have something
 * to say, which is the thing `data/reminders.dart` says flatly that it never
 * does, and it is a founder decision taken against that. Decision 288.
 *
 * Three rules hold it to something defensible.
 *
 * It says nothing about the person. A notification is read on a locked
 * screen, face up on a table, by whoever is standing there. Nothing here is
 * written from an entry, a fact, a pattern or a name, and nothing here ever
 * should be. That is why these are written lines and not a model call: a
 * model given a person's history will eventually put some of it on a lock
 * screen, and there is no prompt that reliably stops it.
 *
 * It asks, it does not chase. No streak, no count, no how many days it has
 * been, nothing that reads as an app keeping score of somebody. A question
 * they can ignore without having lost anything.
 *
 * It is quiet on a day they already wrote. The phone cancels the evening
 * when an entry lands, so the only people who hear this are the ones who
 * have not said anything yet today.
 */

/** The hour, on the phone's own clock. Evening, after a day has happened. */
export const NUDGE_HOUR = 20

/**
 * How many days the phone books ahead. iOS keeps sixty four pending local
 * notifications per app and silently drops the rest, and the reminders a
 * person actually asked for share that budget and matter more.
 */
export const NUDGE_DAYS = 14

/**
 * The lines. Short, concrete, and a question rather than an invitation.
 *
 * They are here in code rather than in the prompts table because nothing
 * generates them. Changing one is an api deploy, which is under a minute,
 * rather than an app release, which is days behind Apple.
 */
const LINES = [
  'Thirty seconds on today. Start anywhere.',
  'Something happened today that you have not told anybody.',
  'What took longer than it should have today.',
  'Anything you almost said today and did not.',
  'Who did you think about today and say nothing to.',
  'What was the smallest annoying thing today.',
  'Did today go the way you thought it would this morning.',
  'What is still open from today.',
  'What happened at about four in the afternoon.',
  'Who was hard to be around today.',
  'What did you get away with today.',
  'What surprised you today, even slightly.',
  'What did you keep putting off today.',
  'Say the part you would not put in a message.',
  'What is the one thing from today you are still carrying.',
  'Anything today that you are going to think about later anyway.',
  'What did somebody else decide for you today.',
  'What was the longest you were quiet today.',
  'Anything you changed your mind about today.',
  'What would you do again tomorrow, and what would you not.',
  'Where did today actually go.',
  'What did you not get to today.',
  'Who made today easier.',
  'What is the first thing you would say about today out loud.',
]

/**
 * The lines this person gets next, in an order that is theirs.
 *
 * Two people who install on the same day should not be read the same
 * question on the same evening, and the same person should not meet one
 * twice inside a fortnight. A stable offset from the account id gives both,
 * and it needs nothing stored.
 */
export function nudgeLines(session: Session, days = NUDGE_DAYS): string[] {
  let offset = 0
  for (const character of session.studentId) {
    offset = (offset * 31 + character.charCodeAt(0)) % LINES.length
  }

  return Array.from(
    { length: Math.min(days, LINES.length) },
    (_, day) => LINES[(offset + day) % LINES.length]!,
  )
}
