import type { TransactionSql } from 'postgres'
import type { Session } from '../../session.js'

/**
 * The two things the read side settles before it reads anything: which
 * timezone bounds a day, and which tags are solid enough to show.
 */

/**
 * The confidence floor for a tag that reaches a screen.
 *
 * The same floor the nightly sweep applies before a theme can support a
 * pattern. A theme on the week and a feeling under an entry are both the app
 * saying something about the student, so a guess the tagger was unsure of
 * stays out of sight rather than being read as fact.
 */
export const MIN_TAG_CONFIDENCE = 0.6

/**
 * How an instant goes onto the wire.
 *
 * Formatted by the database rather than by JavaScript. Drizzle turns off date
 * parsing on this connection, so a timestamp arrives as the string Postgres
 * printed and anything reading it has to parse that string first. Asking for
 * the format we want costs nothing and removes the step.
 *
 * UTC, because the day and the week were already bounded on this side and the
 * client has no boundary left to work out.
 */
export const ISO_INSTANT = 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'

/**
 * The student's own timezone, UTC when they have not given one.
 *
 * Every week and day boundary in this directory is drawn with it. A student in
 * Los Angeles writes on Sunday evening and that entry belongs to Sunday, which
 * is not what happens when the server's clock decides.
 */
export async function studentZone(
  tx: TransactionSql,
  session: Session,
): Promise<string> {
  const rows = await tx<{ timezone: string | null }[]>`
    select timezone from students where id = ${session.studentId} limit 1`

  return rows[0]?.timezone ?? 'UTC'
}
