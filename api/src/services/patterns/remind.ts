import { and, desc, eq, inArray } from 'drizzle-orm'
import { db, confirmedPatterns, entries, reminders } from '../../db.js'
import { copingWays, meaningsTaken } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The one notification this product is happy about.
 *
 * It exists because somebody confirmed a pattern and then asked to be told
 * about it next time, at an hour they picked themselves. Nothing here is a
 * streak, a nudge or a come back and write something, and nothing watches
 * for the moment: the app cannot know when the thing is about to happen, so
 * it does not pretend to. They choose when the interruption arrives, and it
 * arrives before an evening rather than in the middle of one.
 *
 * It is written into `reminders`, the table that already holds the times
 * somebody named out loud, for one reason: the phone reads that table and
 * books a local notification for each row. No push, no device token, nothing
 * about anybody told to a notification service. A pattern reminder is the
 * same kind of thing as a reminder they spoke, so it is the same row.
 *
 * Anchored to the newest moment behind the pattern, because the table hangs
 * a reminder on an entry and takes it away when the entry goes. That is the
 * right behaviour here too: a person who deletes the moment has taken back
 * the thing the reminder is about.
 *
 * Decision 295.
 */
export async function armPatternReminder(
  session: Session,
  patternId: string,
  at: Date,
): Promise<{ said: string }> {
  const rows = await db
    .select({
      theme: confirmedPatterns.theme,
      supporting: confirmedPatterns.supportingEntryIds,
    })
    .from(confirmedPatterns)
    .where(
      and(
        eq(confirmedPatterns.id, patternId),
        eq(confirmedPatterns.studentId, session.studentId),
      ),
    )
    .limit(1)

  const pattern = rows[0]
  if (!pattern) throw new Error('pattern not found')
  if (at.getTime() <= Date.now()) throw new Error('that time has gone')

  const anchors = pattern.supporting.length
    ? await db
        .select({ id: entries.id })
        .from(entries)
        .where(
          and(
            inArray(entries.id, pattern.supporting),
            eq(entries.studentId, session.studentId),
          ),
        )
        .orderBy(desc(entries.createdAt))
        .limit(1)
    : []

  const anchor = anchors[0]
  if (!anchor) throw new Error('nothing to hang it on')

  const said = line(pattern.theme)

  await db.insert(reminders).values({
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    entryId: anchor.id,
    dueAt: at,
    said,
  })

  await db
    .update(confirmedPatterns)
    .set({ reminderArmed: true })
    .where(
      and(
        eq(confirmedPatterns.id, patternId),
        eq(confirmedPatterns.studentId, session.studentId),
      ),
    )

  return { said }
}

/**
 * What the lock screen says. Their theme, in their own words, and a plain
 * statement that they asked for it, so nobody wonders why their phone is
 * talking to them.
 *
 * Nothing else about them goes on it. A notification is read by whoever is
 * standing near the phone.
 */
function line(theme: string): string {
  if (MEANINGS.has(theme)) {
    return `You asked me to remind you about this one: ${theme}.`
  }
  if (COPING.has(theme)) {
    return `You asked me to remind you about this one: you ${theme}.`
  }
  return `You asked me to remind you about this one: ${theme}.`
}

const COPING: ReadonlySet<string> = new Set(copingWays)
const MEANINGS: ReadonlySet<string> = new Set(meaningsTaken)
