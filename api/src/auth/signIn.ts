import { and, eq, isNull } from 'drizzle-orm'
import { db, students, sessions, auditLog } from '../db.js'
import type { Session } from '../session.js'
import { hashSessionToken, mintSessionToken, sessionExpiry } from './tokens.js'

/**
 * Signing in attaches a device to a student who already exists.
 *
 * There is no sign up here and there never will be. The district rosters the
 * student, the roster reference says which row this is, and Apple says which
 * device is allowed back into it later. That is the whole of it.
 */
export class SignInRefused extends Error {}

/**
 * The roster row already belongs to a different Apple account.
 *
 * Its own error because it is the one refusal a student can do nothing about.
 * Every other failure here means try again; this one means somebody has to
 * unlink it, and telling a student to try again forever is worse than telling
 * them plainly that it needs the school.
 */
export class AlreadyLinked extends Error {}

export type SignedIn = { token: string; expiresAt: string }

export async function signInWithApple(roster: Session, appleSub: string): Promise<SignedIn> {
  const linked = await db
    .select({
      id: students.id,
      schoolId: students.schoolId,
      districtId: students.districtId,
    })
    .from(students)
    .where(eq(students.appleUserId, appleSub))
    .limit(1)

  // A second device, or the same one after a reinstall. The Apple account
  // decides which student this is, not the roster reference the build happens
  // to carry, because the account is the credential that was just proven.
  let student = linked[0]
  const firstSignIn = !student

  if (!student) {
    const rows = await db
      .select({ appleUserId: students.appleUserId })
      .from(students)
      .where(eq(students.id, roster.studentId))
      .limit(1)

    if (!rows[0]) throw new SignInRefused('unknown student')

    // The row is already somebody's. Overwriting would hand one student's
    // entries to another Apple account, so the link is written once and only
    // once and a second account has to be sorted out by the district.
    //
    // Claimed in one statement rather than checked and then written. Two sign
    // ins racing on the same roster token could both read an empty column and
    // both proceed, and the loser still walked away with a working session.
    if (rows[0].appleUserId) throw new AlreadyLinked()

    const claimed = await db
      .update(students)
      .set({ appleUserId: appleSub })
      .where(and(eq(students.id, roster.studentId), isNull(students.appleUserId)))
      .returning({ id: students.id })

    if (!claimed[0]) throw new AlreadyLinked()

    student = {
      id: roster.studentId,
      schoolId: roster.schoolId,
      districtId: roster.districtId,
    }
  }

  // A new sign in ends the old ones. Sessions live for six months, so without
  // this a device handed on or lost keeps a working token for half a year.
  await db
    .update(sessions)
    .set({ revokedAt: new Date() })
    .where(and(eq(sessions.studentId, student.id), isNull(sessions.revokedAt)))

  const token = mintSessionToken()
  const expiresAt = sessionExpiry()

  await db.insert(sessions).values({
    studentId: student.id,
    schoolId: student.schoolId,
    districtId: student.districtId,
    tokenHash: hashSessionToken(token),
    expiresAt,
  })

  // Districts have inspection rights and will ask when a device was trusted
  // and when an account was first attached. These are the rows that answer.
  if (firstSignIn) {
    await db.insert(auditLog).values({
      actorId: student.id,
      actorRole: 'student',
      action: 'apple_account_linked',
      subjectStudentId: student.id,
      subjectType: 'student',
      subjectId: student.id,
    })
  }

  await db.insert(auditLog).values({
    actorId: student.id,
    actorRole: 'student',
    action: 'session_issued',
    subjectStudentId: student.id,
    subjectType: 'student',
    subjectId: student.id,
  })

  return { token, expiresAt: expiresAt.toISOString() }
}
