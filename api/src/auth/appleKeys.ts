import { createPublicKey, type KeyObject } from 'node:crypto'

/**
 * Apple's signing keys.
 *
 * Apple publishes a small set of public keys and rotates them without notice.
 * They are held in memory for a few minutes rather than fetched per sign in,
 * because a sign in is not a moment to wait on someone else's network, and a
 * key that has just rotated is handled by the refetch below rather than by a
 * short cache.
 *
 * Nothing here is a secret. These are public keys and the cache can be lost at
 * any time with no consequence beyond one extra fetch.
 */
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys'
const CACHE_MS = 10 * 60 * 1000

type AppleJwk = {
  kty: string
  kid: string
  n: string
  e: string
}

let cache: { keys: Map<string, KeyObject>; fetchedAt: number } | null = null

/**
 * Apple is a third party on the request path, so it gets a deadline. Without
 * one a hung connection holds the request until the operating system gives up,
 * which is minutes.
 */
const FETCH_MS = 5000

/** How long a miss is believed before Apple is asked again. */
const REFETCH_MS = 60_000

let lastFetchAt = 0

async function fetchKeys(): Promise<Map<string, KeyObject>> {
  const response = await fetch(APPLE_KEYS_URL, {
    signal: AbortSignal.timeout(FETCH_MS),
  })
  if (!response.ok) throw new Error(`apple keys returned ${response.status}`)

  const body = (await response.json()) as { keys?: AppleJwk[] }
  const keys = new Map<string, KeyObject>()

  for (const jwk of body.keys ?? []) {
    // The modulus and the exponent are the whole key. Node builds it from the
    // JWK directly, which is why this file needs no library.
    if (jwk.kty !== 'RSA' || !jwk.kid || !jwk.n || !jwk.e) continue
    keys.set(jwk.kid, createPublicKey({ key: { kty: 'RSA', n: jwk.n, e: jwk.e }, format: 'jwk' }))
  }

  if (keys.size === 0) throw new Error('apple published no usable keys')
  return keys
}

/**
 * The key a token says it was signed with, or nothing if Apple has never
 * published it.
 *
 * A miss triggers exactly one refetch. Apple rotating a key mid cache looks
 * identical to a forged key identifier at this point, and the difference is
 * worth one request rather than a signed out student.
 */
export async function appleSigningKey(kid: string): Promise<KeyObject | undefined> {
  if (cache && Date.now() - cache.fetchedAt < CACHE_MS) {
    const cached = cache.keys.get(kid)
    if (cached) return cached
  }

  // A miss used to refetch every time, so anyone with a token could make this
  // service call Apple once per request by inventing key identifiers. A miss
  // is now believed for a minute, which is far shorter than any real rotation
  // and long enough that forged identifiers cost nothing.
  if (cache && Date.now() - lastFetchAt < REFETCH_MS) return undefined

  lastFetchAt = Date.now()
  cache = { keys: await fetchKeys(), fetchedAt: Date.now() }
  return cache.keys.get(kid)
}
