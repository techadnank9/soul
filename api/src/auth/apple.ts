import { createVerify } from 'node:crypto'
import { appleSigningKey } from './appleKeys.js'

/**
 * Apple's identity token, checked against Apple's own signature.
 *
 * The token arrives from the device and the device is not trusted, so nothing
 * inside it counts until the signature does. Order matters here: the claims
 * are only read after the signature has been verified, because an unverified
 * token is a string a stranger wrote.
 *
 * Every failure raises the same error with a short reason. The reason is for
 * the log, not for the client, which is told only that the token was rejected.
 */
export class AppleTokenInvalid extends Error {}

const APPLE_ISSUER = 'https://appleid.apple.com'

type AppleHeader = { alg?: string; kid?: string }
type AppleClaims = { iss?: string; aud?: string | string[]; exp?: number; sub?: string }

function decodeSegment<T>(segment: string): T {
  let value: unknown
  try {
    value = JSON.parse(Buffer.from(segment, 'base64url').toString('utf8'))
  } catch {
    throw new AppleTokenInvalid('token is not readable')
  }

  // Valid JSON is not the same as a header or a set of claims. A segment that
  // decodes to null or to a bare string parses cleanly and then throws on the
  // first property read, which turned a forged token into a 500.
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new AppleTokenInvalid('token segment is not an object')
  }
  return value as T
}

/**
 * Returns the Apple subject, which is the stable identifier for this student
 * on this developer account and the only value the caller should carry
 * forward.
 */
export async function verifyAppleIdentityToken(
  identityToken: string,
  appleUserId: string,
  bundleId: string,
): Promise<string> {
  const parts = identityToken.split('.')
  if (parts.length !== 3) throw new AppleTokenInvalid('token is not three parts')

  const [headerSegment, claimsSegment, signatureSegment] = parts
  if (!headerSegment || !claimsSegment || !signatureSegment) {
    throw new AppleTokenInvalid('token has an empty part')
  }

  const header = decodeSegment<AppleHeader>(headerSegment)

  // RS256 and nothing else. Reading the algorithm out of the token and
  // trusting it is how none and HS256 attacks get in.
  if (header.alg !== 'RS256') throw new AppleTokenInvalid('token is not RS256')
  if (!header.kid) throw new AppleTokenInvalid('token names no key')

  const key = await appleSigningKey(header.kid)
  if (!key) throw new AppleTokenInvalid('token names a key apple does not publish')

  const verifier = createVerify('RSA-SHA256')
  verifier.update(`${headerSegment}.${claimsSegment}`)
  verifier.end()

  if (!verifier.verify(key, Buffer.from(signatureSegment, 'base64url'))) {
    throw new AppleTokenInvalid('signature does not match')
  }

  const claims = decodeSegment<AppleClaims>(claimsSegment)

  if (claims.iss !== APPLE_ISSUER) throw new AppleTokenInvalid('issuer is not apple')

  // A token minted for another app is a valid Apple token and still not ours.
  const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud]
  if (!audience.includes(bundleId)) throw new AppleTokenInvalid('audience is another app')

  if (!claims.exp || claims.exp * 1000 <= Date.now()) {
    throw new AppleTokenInvalid('token has expired')
  }

  // The device sends the subject alongside the token. They have to agree, or
  // the caller is telling us about an account the token does not describe.
  if (!claims.sub || claims.sub !== appleUserId) {
    throw new AppleTokenInvalid('subject does not match the account')
  }

  return claims.sub
}
