import { Hono } from 'hono'
import { env } from '../env.js'
import * as contracts from '../contracts.js'
import { AppleTokenInvalid, verifyAppleIdentityToken } from '../auth/apple.js'
import { AlreadyLinked, SignInRefused, signInWithApple } from '../auth/signIn.js'
import type { Session } from '../session.js'

/**
 * Sign in with Apple.
 *
 * This route sits inside the authenticated block on purpose. A student signing
 * in for the first time has no session token yet, but they do have the roster
 * reference the build carries, and that is what says which student row the
 * Apple account attaches to. Without a bearer there is nothing to attach to
 * and the call has no meaning.
 *
 * Every rejection is one status and one shape. The reason is logged and never
 * returned, because a caller working out which of the checks it failed is
 * being helped to pass them.
 */
type Vars = { Variables: { session: Session } }

export const auth = new Hono<Vars>()

auth.post('/auth/apple', async (c) => {
  const parsed = contracts.appleSignIn.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid sign in' }, 401)

  try {
    const appleSub = await verifyAppleIdentityToken(
      parsed.data.identityToken,
      parsed.data.appleUserId,
      env.appleBundleId(),
    )

    const signedIn = await signInWithApple(c.get('session'), appleSub)
    return c.json(signedIn)
  } catch (error) {
    // The one refusal a student cannot fix by trying again, so it is told
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
