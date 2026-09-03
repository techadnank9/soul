import { createHash, randomInt } from 'node:crypto'
import { and, desc, eq, gt, isNull, sql as raw } from 'drizzle-orm'
import { db, emailCodes, students } from '../db.js'
import type { Session } from '../session.js'
import { auditLinked, createAccount, issueSession, type SignedIn } from './accounts.js'
import { sendSignInCode } from './resend.js'

/**
 * Signing in with an email code.
 *
 * The address is asked for, a six digit code is sent to it, and the code is
 * the credential. It is hashed with the address before it is stored, lives
 * ten minutes, is used once, and counts its attempts, so the table read in
 * full still lets nobody in and a code cannot be guessed at leisure.
 *
 * On a first sign in the address is attached to the account this device
 * already has. On a later one the address decides which account this is,
 * because it is what was just proven.
 */
export class EmailRefused extends Error {}

const CODE_MINUTES = 10
const MAX_ATTEMPTS = 5
const MAX_CODES_PER_HOUR = 5

function hashCode(email: string, code: string): string {
  return createHash('sha256').update(`${email}:${code}`).digest('hex')
}

export async function startEmailSignIn(email: string): Promise<void> {
  const since = new Date(Date.now() - 60 * 60 * 1000)
  const recent = await db
    .select({ n: raw<number>`count(*)::int` })
    .from(emailCodes)
    .where(and(eq(emailCodes.email, email), gt(emailCodes.createdAt, since)))
  if ((recent[0]?.n ?? 0) >= MAX_CODES_PER_HOUR) throw new EmailRefused('too many codes')

  const code = String(randomInt(0, 1_000_000)).padStart(6, '0')

  await db.insert(emailCodes).values({
    email,
    codeHash: hashCode(email, code),
    expiresAt: new Date(Date.now() + CODE_MINUTES * 60 * 1000),
  })

  await sendSignInCode(email, code)
}

export async function verifyEmailSignIn(
  email: string,
  code: string,
  current: Session | null,
): Promise<SignedIn> {
  const rows = await db
    .select({ id: emailCodes.id, codeHash: emailCodes.codeHash, attempts: emailCodes.attempts })
    .from(emailCodes)
    .where(
      and(
        eq(emailCodes.email, email),
        isNull(emailCodes.consumedAt),
        gt(emailCodes.expiresAt, new Date()),
      ),
    )
    .orderBy(desc(emailCodes.createdAt))
    .limit(1)

  const row = rows[0]
  if (!row) throw new EmailRefused('no live code')
  if (row.attempts >= MAX_ATTEMPTS) throw new EmailRefused('too many attempts')

  // Counted before it is compared, so a wrong guess always costs one.
  await db
    .update(emailCodes)
    .set({ attempts: row.attempts + 1 })
    .where(eq(emailCodes.id, row.id))

  if (row.codeHash !== hashCode(email, code)) throw new EmailRefused('wrong code')

  await db.update(emailCodes).set({ consumedAt: new Date() }).where(eq(emailCodes.id, row.id))

  const known = await db
    .select({ id: students.id, schoolId: students.schoolId, districtId: students.districtId })
    .from(students)
    .where(eq(students.email, email))
    .limit(1)
  if (known[0]) return issueSession(known[0])

  // A new address. It attaches to the account this device already has, if
  // that account has no address yet. Otherwise it is a new person on a shared
  // phone, and they get an account of their own.
  if (current) {
    const claimed = await db
      .update(students)
      .set({ email })
      .where(and(eq(students.id, current.studentId), isNull(students.email)))
      .returning({ id: students.id })
    if (claimed[0]) {
      await auditLinked(current.studentId, 'email_linked')
      return issueSession({
        id: current.studentId,
        schoolId: current.schoolId,
        districtId: current.districtId,
      })
    }
  }

  const account = await createAccount()
  await db.update(students).set({ email }).where(eq(students.id, account.id))
  await auditLinked(account.id, 'email_linked')
  return issueSession(account)
}
