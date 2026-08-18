import { db, jobs } from '../db.js'
import type { Session } from '../session.js'

/**
 * The queue is Postgres, not Redis. Check backs fire days later and must
 * survive deploys. Fewer services also means a shorter sub processor list.
 */
export type JobType = 'tag_entry' | 'embed_entry' | 'check_back'

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

export function inDays(days: number, from: Date = new Date()): Date {
  const at = new Date(from)
  at.setDate(at.getDate() + days)
  // Late afternoon, when a school day is over and a student can answer honestly.
  at.setHours(17, 0, 0, 0)
  return at
}
