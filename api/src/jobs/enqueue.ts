import { db, jobs, sql } from '../db.js'
import type { Session } from '../session.js'

/**
 * The queue is Postgres, not Redis. Check backs fire days later and must
 * survive deploys. Fewer services also means a shorter sub processor list.
 */
export type JobType =
  | 'tag_entry'
  | 'embed_entry'
  | 'check_back'
  | 'pattern_sweep'
  | 'pattern_verdicts'
  | 'cue_cards'
  | 'people'
  | 'person_profile'

/** The hour the sweep runs. Late enough that a school day is long over. */
const SWEEP_HOUR = 3

export async function enqueue(
  type: JobType,
  payload: Record<string, unknown>,
  session: Session,
  runAt: Date = new Date(),
): Promise<void> {
  await db.insert(jobs).values({
    type,
    payload: JSON.stringify(payload),
    studentId: session.studentId,
    schoolId: session.schoolId,
    districtId: session.districtId,
    runAt,
  })
}

/**
 * The sweep is the one job with no student. It reads every student's tags in
 * a single query, so there is no row to scope it to and no session to carry.
 *
 * One is scheduled at a time. The runner books the next night at the end of
 * every run, so an insert that did not check would double the chain each time
 * the runner restarted, and a week of restarts would be a hundred sweeps a
 * night.
 */
export async function scheduleSweep(runAt: Date = nextNight()): Promise<void> {
  // The time goes over as text. Drizzle replaces the date serializer on this
  // connection with one that passes a Date object straight through, which the
  // driver cannot write, so raw queries send the string themselves.
  await sql`
    insert into jobs (type, payload, run_at)
    select 'pattern_sweep', '{}', ${runAt.toISOString()}::timestamptz
    where not exists (
      select 1 from jobs where type = 'pattern_sweep' and status = 'pending'
    )`
}

/**
 * The verdict run, booked for right after a sweep has finished.
 *
 * Like the sweep it has no student. It reads every student's themes in one
 * pass and writes the line each one is shown under, and it is booked by the
 * runner at the end of a sweep rather than on a clock of its own, so verdicts
 * are written against the themes that sweep just saw.
 *
 * One at a time, for the same reason the sweep is one at a time. Every run
 * costs a model call per theme that needs one, and a restart that doubled the
 * chain would double the bill with it.
 */
export async function scheduleVerdicts(runAt: Date = new Date()): Promise<void> {
  await sql`
    insert into jobs (type, payload, run_at)
    select 'pattern_verdicts', '{}', ${runAt.toISOString()}::timestamptz
    where not exists (
      select 1 from jobs where type = 'pattern_verdicts' and status = 'pending'
    )`
}

/**
 * Tonight if it has not passed, otherwise tomorrow.
 *
 * Server time, not a student's. Students are in several timezones and the
 * sweep is one query across all of them, so the hour is about when the
 * database is quiet rather than when anybody is asleep. Nothing it writes is
 * shown until the student next opens the app.
 */
export function nextNight(from: Date = new Date()): Date {
  const at = new Date(from)
  at.setHours(SWEEP_HOUR, 0, 0, 0)
  if (at <= from) at.setDate(at.getDate() + 1)
  return at
}

export function inDays(days: number, from: Date = new Date()): Date {
  const at = new Date(from)
  at.setDate(at.getDate() + days)
  // Late afternoon, when a school day is over and a student can answer honestly.
  at.setHours(17, 0, 0, 0)
  return at
}
