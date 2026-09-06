import { createHash, randomInt } from 'node:crypto'
import { and, desc, eq, gt, isNull, sql as raw } from 'drizzle-orm'
import { db, phoneCodes, students } from '../db.js'
import type { Session } from '../session.js'
import { auditLinked, createAccount, issueSession, type SignedIn } from './accounts.js'
import { sendSignInCodeBySms } from './sms.js'

/**
 * Signing in with a code sent by text.
 *
 * The same shape as the email path, deliberately: a six digit code, hashed
 * with the number before it is stored, ten minutes, used once, five
 * attempts, five codes an hour. The table read in full lets nobody in.
 *
 * On a first sign in the number attaches to the account this device already
 * has. On a later one the number decides which account this is, because it
 * is what was just proven.
 */
export class PhoneRefused extends Error {}

const CODE_MINUTES = 10
const MAX_ATTEMPTS = 5
const MAX_CODES_PER_HOUR = 5

function hashCode(phone: string, code: string): string {
  return createHash('sha256').update(`${phone}:${code}`).digest('hex')
}

export async function startPhoneSignIn(phone: string): Promise<void> {
  const since = new Date(Date.now() - 60 * 60 * 1000)
  const recent = await db
    .select({ n: raw<number>`count(*)::int` })
    .from(phoneCodes)
    .where(and(eq(phoneCodes.phone, phone), gt(phoneCodes.createdAt, since)))
  if ((recent[0]?.n ?? 0) >= MAX_CODES_PER_HOUR) throw new PhoneRefused('too many codes')

  const code = String(randomInt(0, 1_000_000)).padStart(6, '0')

  await db.insert(phoneCodes).values({
    phone,
    codeHash: hashCode(phone, code),
    expiresAt: new Date(Date.now() + CODE_MINUTES * 60 * 1000),
  })

  await sendSignInCodeBySms(phone, code)
}

export async function verifyPhoneSignIn(
  phone: string,
  code: string,
  current: Session | null,
): Promise<SignedIn> {
  const rows = await db
    .select({ id: phoneCodes.id, codeHash: phoneCodes.codeHash, attempts: phoneCodes.attempts })
    .from(phoneCodes)
    .where(
      and(
        eq(phoneCodes.phone, phone),
        isNull(phoneCodes.consumedAt),
        gt(phoneCodes.expiresAt, new Date()),
      ),
    )
    .orderBy(desc(phoneCodes.createdAt))
    .limit(1)

  const row = rows[0]
  if (!row) throw new PhoneRefused('no code')
  if (row.attempts >= MAX_ATTEMPTS) throw new PhoneRefused('too many attempts')

  // Counted before it is checked, so a wrong guess costs an attempt whatever
  // happens next.
  await db
    .update(phoneCodes)
    .set({ attempts: row.attempts + 1 })
    .where(eq(phoneCodes.id, row.id))

  if (row.codeHash !== hashCode(phone, code)) throw new PhoneRefused('wrong code')

  await db.update(phoneCodes).set({ consumedAt: new Date() }).where(eq(phoneCodes.id, row.id))

  const known = await db
    .select({ id: students.id, schoolId: students.schoolId, districtId: students.districtId })
    .from(students)
    .where(eq(students.phone, phone))
    .limit(1)
  if (known[0]) return issueSession(known[0])

  // A new number. It attaches to the account this device already has, if
  // that account has no number yet. Otherwise it is a new person on a shared
  // phone, and they get an account of their own.
  if (current) {
    const claimed = await db
      .update(students)
      .set({ phone })
      .where(and(eq(students.id, current.studentId), isNull(students.phone)))
      .returning({ id: students.id })
    if (claimed[0]) {
      await auditLinked(current.studentId, 'phone_linked')
      return issueSession({
        id: current.studentId,
        schoolId: current.schoolId,
        districtId: current.districtId,
      })
    }
  }

  const account = await createAccount()
  await db.update(students).set({ phone }).where(eq(students.id, account.id))
  await auditLinked(account.id, 'phone_linked')
  return issueSession(account)
}
