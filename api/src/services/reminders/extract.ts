import { and, eq, gt, isNull } from 'drizzle-orm'
import { db, entries, reminders, students } from '../../db.js'
import { call } from '../../gateway/call.js'
import { remindersResult } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * Anything somebody said they would do, at a time they named themselves.
 *
 * Booked by the tagger, off the request path, and empty for almost every
 * entry. Somebody describing their day has not asked to be reminded of
 * anything, and the prompt says so at length because a model handed an entry
 * will always find something it could ring about.
 *
 * The one rule this service exists to hold: a row is written only when the
 * person named a time out loud. Nothing here is inferred from a mood, a
 * habit or a pattern. The app never decides on its own that somebody ought
 * to be reminded of something, and that is the whole difference between this
 * and an app that nags.
 */
export async function extractReminders(
  entryId: string,
  session: Session,
): Promise<number> {
  const rows = await db
    .select({ text: entries.text, writtenAt: entries.createdAt })
    .from(entries)
    .where(eq(entries.id, entryId))
    .limit(1)

  const entry = rows[0]
  if (!entry) return 0

  const zone = await zoneOf(session)

  // What time it is where they are, in words the model can count from. It
  // answers in their local time and this service turns it back into an
  // instant, so two o'clock tomorrow is two o'clock to them.
  const now = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    weekday: 'long',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(entry.writtenAt)

  const result = await call('reminders', {
    user: `Where they are it is ${now}.\n\nThey wrote:\n${entry.text}`,
    schema: remindersResult,
    session,
    entryId,
  })

  let written = 0
  for (const found of result.value.reminders) {
    const dueAt = instantOf(found.at, zone)

    // A time that has already gone by, or one the zone maths could not make
    // sense of. A reminder that rings the moment it is written is worse than
    // none, and the prompt already says to return nothing in that case.
    if (!dueAt || dueAt.getTime() <= Date.now()) continue

    await db.insert(reminders).values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      entryId,
      dueAt,
      said: found.said,
    })
    written += 1
  }

  return written
}

/**
 * The reminders a phone has not rung yet.
 *
 * Only what is still ahead. One that has already passed belongs to the
 * notification that was scheduled for it, not to this list, and handing it
 * back would have a phone ring about lunch at bedtime.
 */
export async function upcomingReminders(session: Session) {
  return db
    .select({
      id: reminders.id,
      dueAt: reminders.dueAt,
      said: reminders.said,
    })
    .from(reminders)
    .where(
      and(
        eq(reminders.studentId, session.studentId),
        isNull(reminders.cancelledAt),
        gt(reminders.dueAt, new Date()),
      ),
    )
    .orderBy(reminders.dueAt)
    .limit(50)
}

async function zoneOf(session: Session): Promise<string> {
  const rows = await db
    .select({ timezone: students.timezone })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  return rows[0]?.timezone ?? 'UTC'
}

/**
 * A wall clock time in somebody's zone, as an instant.
 *
 * There is no way to ask JavaScript for this directly. Guess that the local
 * time is the instant, ask what that instant reads as in their zone, and
 * correct by the difference. Twice, because the offset itself can change
 * between the guess and the answer, which is what a clock going forward on a
 * Sunday morning does to the first pass.
 */
function instantOf(local: string, zone: string): Date | null {
  const guess = new Date(`${local.length === 16 ? `${local}:00` : local}Z`)
  if (Number.isNaN(guess.getTime())) return null

  let instant = guess
  for (let pass = 0; pass < 2; pass++) {
    const offset = instant.getTime() - new Date(readIn(instant, zone)).getTime()
    instant = new Date(guess.getTime() + offset)
  }

  return Number.isNaN(instant.getTime()) ? null : instant
}

/** What an instant reads as on a clock in that zone, as a parseable string. */
function readIn(instant: Date, zone: string): string {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: zone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).formatToParts(instant)

  const at = (type: string) => parts.find((p) => p.type === type)?.value ?? '00'
  return `${at('year')}-${at('month')}-${at('day')}T${at('hour')}:${at('minute')}:${at('second')}Z`
}
