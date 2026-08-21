import type { TransactionSql } from 'postgres'
import { sql } from './db.js'
import { SESSION_TOKEN_PREFIX, hashSessionToken } from './auth/tokens.js'

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

/**
 * Two kinds of bearer arrive here and the prefix tells them apart.
 *
 * A signed in device sends a session token. A debug build with no sign in
 * behind it sends the roster reference, which is how the product has been
 * driven from a laptop since the first day and is still how it is driven now.
 * The roster path is the development path and it stays.
 */
export async function resolveSession(token: string | undefined): Promise<Session | null> {
  if (!token) return null
  if (token.startsWith(SESSION_TOKEN_PREFIX)) return resolveSessionToken(token)

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
 * The token itself is never stored, so the lookup is on its hash. A revoked or
 * expired row resolves to nobody rather than to a student, which is the one
 * behaviour in this file worth a test.
 */
async function resolveSessionToken(token: string): Promise<Session | null> {
  const rows = await sql<{ student_id: string; school_id: string; district_id: string }[]>`
    select student_id, school_id, district_id
    from sessions
    where token_hash = ${hashSessionToken(token)}
      and revoked_at is null
      and expires_at > now()
    limit 1`

  const row = rows[0]
  if (!row) return null
  return { studentId: row.student_id, schoolId: row.school_id, districtId: row.district_id }
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
