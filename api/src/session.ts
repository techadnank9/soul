import type { TransactionSql } from 'postgres'
import { sql } from './db.js'

/**
 * Who is asking. Student, school and district, resolved once per request and
 * carried everywhere after that.
 *
 * There is no student sign up. Students are rostered by the district, and the
 * external reference is the rostering identifier.
 */
export type Session = {
  studentId: string
  schoolId: string
  districtId: string
}

export async function resolveSession(token: string | undefined): Promise<Session | null> {
  if (!token) return null

  const rows = await sql<{ id: string; school_id: string; district_id: string }[]>`
    select id, school_id, district_id
    from students
    where external_ref = ${token}
    limit 1`

  const row = rows[0]
  if (!row) return null
  return { studentId: row.id, schoolId: row.school_id, districtId: row.district_id }
}

/**
 * Runs a unit of work as the student, under row level security.
 *
 * The application is not the only guard. Inside this transaction the role is
 * soul_student and the policies decide what is visible, so a missing where
 * clause in a query above cannot leak another student's row.
 */
export async function asStudent<T>(
  session: Session,
  work: (tx: TransactionSql) => Promise<T>,
): Promise<T> {
  return sql.begin(async (tx) => {
    await tx`set local role soul_student`
    await tx`select set_config('app.student_id', ${session.studentId}, true)`
    return work(tx)
  }) as Promise<T>
}
