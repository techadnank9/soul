import { randomUUID } from 'node:crypto'
import { and, eq, isNull } from 'drizzle-orm'
import { db, districts, schools, students, sessions, auditLog } from '../db.js'
import { hashSessionToken, mintSessionToken, sessionExpiry } from './tokens.js'

/**
 * Accounts that people make for themselves.
 *
 * Anybody can use the product. A phone that has never been seen asks for an
 * account on first launch and gets one, with a session, before it has said a
 * word. Signing in with Apple or with an email code later attaches an
 * identity to that account so it can be found again from another phone. A
 * district can still roster people, and those rows look the same.
 */
export type Account = { id: string; schoolId: string; districtId: string }
export type SignedIn = { token: string; expiresAt: string }

const SELF_DISTRICT = 'Self signup'
const SELF_SCHOOL = 'Self signup'

/**
 * Where self made accounts live. One district and one school, made the first
 * time they are needed, because every row in the database has to belong to
 * both and a person who downloaded the app belongs to neither.
 */
export async function selfSignupHome(): Promise<{ schoolId: string; districtId: string }> {
  const district =
    (
      await db
        .select({ id: districts.id })
        .from(districts)
        .where(eq(districts.name, SELF_DISTRICT))
        .limit(1)
    )[0] ??
    (
      await db
        .insert(districts)
        .values({ name: SELF_DISTRICT, consentModel: 'school', retentionDays: 365 })
        .returning({ id: districts.id })
    )[0]
  if (!district) throw new Error('district insert returned no row')

  const school =
    (
      await db
        .select({ id: schools.id })
        .from(schools)
        .where(and(eq(schools.districtId, district.id), eq(schools.name, SELF_SCHOOL)))
        .limit(1)
    )[0] ??
    (
      await db
        .insert(schools)
        .values({ districtId: district.id, name: SELF_SCHOOL })
        .returning({ id: schools.id })
    )[0]
  if (!school) throw new Error('school insert returned no row')

  return { schoolId: school.id, districtId: district.id }
}

/** A new account with nothing in it. The external reference is random and means nothing. */
export async function createAccount(): Promise<Account> {
  const home = await selfSignupHome()
  // Agreed from the moment it exists. Using the app is the agreement, and
  // nothing a person says or writes waits on a checkbox.
  const rows = await db
    .insert(students)
    .values({
      ...home,
      externalRef: `self_${randomUUID()}`,
      consentRecordedAt: new Date(),
      consentVersion: 'v1',
    })
    .returning({ id: students.id })
  const row = rows[0]
  if (!row) throw new Error('account insert returned no row')

  await db.insert(auditLog).values({
    actorId: row.id,
    actorRole: 'student',
    action: 'account_created',
    subjectStudentId: row.id,
    subjectType: 'student',
    subjectId: row.id,
  })

  return { id: row.id, ...home }
}

/**
 * A session for an account, and the end of every earlier one.
 *
 * Sessions live for six months, so without the revoke a device handed on or
 * lost keeps a working token for half a year. Districts have inspection
 * rights and will ask when a device was trusted, which is what the audit row
 * answers.
 */
export async function issueSession(account: Account): Promise<SignedIn> {
  await db
    .update(sessions)
    .set({ revokedAt: new Date() })
    .where(and(eq(sessions.studentId, account.id), isNull(sessions.revokedAt)))

  const token = mintSessionToken()
  const expiresAt = sessionExpiry()

  await db.insert(sessions).values({
    studentId: account.id,
    schoolId: account.schoolId,
    districtId: account.districtId,
    tokenHash: hashSessionToken(token),
    expiresAt,
  })

  await db.insert(auditLog).values({
    actorId: account.id,
    actorRole: 'student',
    action: 'session_issued',
    subjectStudentId: account.id,
    subjectType: 'student',
    subjectId: account.id,
  })

  return { token, expiresAt: expiresAt.toISOString() }
}

/** An audit row for an identity being attached, written once per identity. */
export async function auditLinked(accountId: string, action: string): Promise<void> {
  await db.insert(auditLog).values({
    actorId: accountId,
    actorRole: 'student',
    action,
    subjectStudentId: accountId,
    subjectType: 'student',
    subjectId: accountId,
  })
}
