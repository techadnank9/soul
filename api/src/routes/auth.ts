import { Hono } from 'hono'
import { env } from '../env.js'
import * as contracts from '../contracts.js'
import { AppleTokenInvalid, verifyAppleIdentityToken } from '../auth/apple.js'
import { AlreadyLinked, SignInRefused, signInWithApple } from '../auth/signIn.js'
import { createAccount, issueSession } from '../auth/accounts.js'
import { db, students } from '../db.js'
import { eq } from 'drizzle-orm'
import { EmailRefused, startEmailSignIn, verifyEmailSignIn } from '../auth/email.js'
import { EmailUnavailable } from '../auth/resend.js'
import { SmsUnavailable } from '../auth/sms.js'
import { PhoneRefused, startPhoneSignIn, verifyPhoneSignIn } from '../auth/phone.js'
import { resolveSession, type Session } from '../session.js'

/**
 * Accounts and sign in.
 *
 * Three routes have no session, and server.ts lists them: a phone asking for
 * its first account, an address asking for a code, and a code being checked.
 * Sign in with Apple keeps a session, the device's own, because it needs an
 * account to attach the Apple account to.
 *
 * Every rejection is one status and one shape. The reason is logged and never
 * returned, because a caller working out which check it failed is being
 * helped to pass it.
 */
type Vars = { Variables: { session: Session } }

export const auth = new Hono<Vars>()

/**
 * A new account for a phone that has never been seen. The session comes with
 * it.
 *
 * Held to a rate per address, because this is the one route that makes rows
 * with nothing asked of the caller: no session, no code, no Apple. Without a
 * ceiling anybody who found the url could make accounts until the database
 * was full, and every account they made carries a session that can call the
 * routes that talk to a model.
 *
 * In memory, not in the database. One web instance runs at a time, so a map
 * is the whole of what is needed, and a limiter that needs a table is a
 * limiter that stops working the first time the table is slow. It resets on
 * deploy, which is the right failure: a real first launch after a deploy is
 * let through, and a flood has to start again.
 *
 * Decision 293.
 */
const NEW_ACCOUNTS_PER_HOUR = 20
const anHour = 60 * 60 * 1000
const madeBy = new Map<string, number[]>()

function tooMany(who: string): boolean {
  const now = Date.now()
  const recent = (madeBy.get(who) ?? []).filter((at) => now - at < anHour)
  recent.push(now)
  madeBy.set(who, recent)

  // The map only ever holds the last hour, so a busy day does not leave it
  // holding every address that ever asked.
  if (madeBy.size > 5000) {
    for (const [key, times] of madeBy) {
      if (times.every((at) => now - at >= anHour)) madeBy.delete(key)
    }
  }

  return recent.length > NEW_ACCOUNTS_PER_HOUR
}

auth.post('/auth/device', async (c) => {
  const who = c.req.header('x-forwarded-for')?.split(',')[0]?.trim() || 'unknown'

  if (tooMany(who)) {
    console.log(`account: refused, too many from ${who}`)
    return c.json({ error: 'try later' }, 429)
  }

  const account = await createAccount()
  console.log(`account: created ${account.id.slice(0, 8)}`)
  return c.json(await issueSession(account))
})

auth.post('/auth/email/start', async (c) => {
  const parsed = contracts.emailStart.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid email' }, 400)

  try {
    await startEmailSignIn(parsed.data.email)
    return c.json({ ok: true })
  } catch (error) {
    if (error instanceof EmailRefused) {
      console.log(`email sign in refused: ${error.message}`)
      return c.json({ error: 'try later' }, 429)
    }
    if (error instanceof EmailUnavailable) {
      console.error(error.message)
      return c.json({ error: 'email sign in is not available' }, 503)
    }
    throw error
  }
})

auth.post('/auth/email/verify', async (c) => {
  const parsed = contracts.emailVerify.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid code' }, 401)

  // The bearer is optional here. A phone mid first run carries its device
  // session and the address attaches to it. A fresh install carries nothing
  // and the address finds, or makes, the account.
  const header = c.req.header('authorization')
  const bearer = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  const current = await resolveSession(bearer)

  try {
    return c.json(await verifyEmailSignIn(parsed.data.email, parsed.data.code, current))
  } catch (error) {
    if (error instanceof EmailRefused) {
      console.log(`email code refused: ${error.message}`)
      return c.json({ error: 'sign in refused' }, 401)
    }
    throw error
  }
})

/**
 * A code by text. The same two calls as the email path and the same
 * answers, so the client can hold one shape for both.
 */
auth.post('/auth/phone/start', async (c) => {
  const parsed = contracts.phoneStart.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid number' }, 400)

  try {
    await startPhoneSignIn(parsed.data.phone)
    return c.json({ ok: true })
  } catch (error) {
    if (error instanceof PhoneRefused) {
      console.log(`phone sign in refused: ${error.message}`)
      return c.json({ error: 'try later' }, 429)
    }
    if (error instanceof SmsUnavailable) {
      console.error(error.message)
      return c.json({ error: 'text sign in is not available' }, 503)
    }
    // A number AWS will not send to reads as a bad number rather than as a
    // fault in the app. In the sandbox that is every number but the ones
    // that have been verified there.
    console.error(`sms send failed: ${(error as Error).message}`)
    return c.json({ error: 'that number did not go through' }, 502)
  }
})

auth.post('/auth/phone/verify', async (c) => {
  const parsed = contracts.phoneVerify.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid code' }, 401)

  const header = c.req.header('authorization')
  const bearer = header?.startsWith('Bearer ') ? header.slice(7) : undefined
  const current = await resolveSession(bearer)

  try {
    return c.json(await verifyPhoneSignIn(parsed.data.phone, parsed.data.code, current))
  } catch (error) {
    if (error instanceof PhoneRefused) {
      console.log(`phone code refused: ${error.message}`)
      return c.json({ error: 'sign in refused' }, 401)
    }
    throw error
  }
})

auth.post('/auth/apple', async (c) => {
  const parsed = contracts.appleSignIn.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid sign in' }, 401)

  try {
    const appleSub = await verifyAppleIdentityToken(
      parsed.data.identityToken,
      parsed.data.appleUserId,
      env.appleBundleId(),
    )

    // The bearer is optional here too, for the same reason as the email code.
    const header = c.req.header('authorization')
    const bearer = header?.startsWith('Bearer ') ? header.slice(7) : undefined
    const current = await resolveSession(bearer)

    const signedIn = await signInWithApple(current, appleSub)
    return c.json(signedIn)
  } catch (error) {
    // The one refusal a person cannot fix by trying again, so it is told
    // apart from the rest rather than folded into the same opaque 401.
    if (error instanceof AlreadyLinked) {
      console.error('sign in refused: already linked')
      return c.json({ error: 'already linked' }, 409)
    }

    if (error instanceof AppleTokenInvalid || error instanceof SignInRefused) {
      console.log(`apple sign in refused: ${error.message}`)
      return c.json({ error: 'sign in refused' }, 401)
    }
    throw error
  }
})
