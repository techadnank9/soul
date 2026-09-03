import { Hono } from 'hono'
import { env } from '../env.js'
import * as contracts from '../contracts.js'
import { AppleTokenInvalid, verifyAppleIdentityToken } from '../auth/apple.js'
import { AlreadyLinked, SignInRefused, signInWithApple } from '../auth/signIn.js'
import { createAccount, issueSession } from '../auth/accounts.js'
import { EmailRefused, startEmailSignIn, verifyEmailSignIn } from '../auth/email.js'
import { EmailUnavailable } from '../auth/resend.js'
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

/** A new account for a phone that has never been seen. The session comes with it. */
auth.post('/auth/device', async (c) => {
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
