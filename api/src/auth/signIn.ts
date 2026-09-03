import { and, eq, isNull } from 'drizzle-orm'
import { db, students } from '../db.js'
import type { Session } from '../session.js'
import { auditLinked, issueSession, type SignedIn } from './accounts.js'

/**
 * Signing in with Apple attaches an Apple account to the account this device
 * already has, or finds the account that Apple account was attached to before.
 *
 * The bearer on the call is the device's own session, made on first launch,
 * or a roster reference in development. Either way it names the row the Apple
 * account attaches to on a first sign in. On a later sign in the Apple account
 * is the credential that was just proven, so it decides which account this
 * is, whatever the bearer said.
 */
export class SignInRefused extends Error {}

/**
 * The account already belongs to a different Apple account.
 *
 * Its own error because it is the one refusal a person can do nothing about
 * by trying again. Telling them plainly beats telling them to retry forever.
 */
export class AlreadyLinked extends Error {}

export type { SignedIn }

export async function signInWithApple(current: Session, appleSub: string): Promise<SignedIn> {
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
  // decides which account this is.
  if (linked[0]) return issueSession(linked[0])

  const rows = await db
    .select({ appleUserId: students.appleUserId })
    .from(students)
    .where(eq(students.id, current.studentId))
    .limit(1)

  if (!rows[0]) throw new SignInRefused('unknown user')

  // The row is already somebody's. Overwriting would hand one person's
  // entries to another Apple account, so the link is written once and only
  // once. Claimed in one statement rather than checked and then written, so
  // two sign ins racing on the same account cannot both proceed.
  if (rows[0].appleUserId) throw new AlreadyLinked()

  const claimed = await db
    .update(students)
    .set({ appleUserId: appleSub })
    .where(and(eq(students.id, current.studentId), isNull(students.appleUserId)))
    .returning({ id: students.id })

  if (!claimed[0]) throw new AlreadyLinked()

  await auditLinked(current.studentId, 'apple_account_linked')

  return issueSession({
    id: current.studentId,
    schoolId: current.schoolId,
    districtId: current.districtId,
  })
}
