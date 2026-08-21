import { createHash, randomBytes } from 'node:crypto'

/**
 * Session tokens.
 *
 * The prefix is what tells a session token apart from a roster reference in
 * one character comparison, so the resolver never has to guess which of the
 * two it is holding.
 *
 * Only the hash is ever written down. A stolen backup of the sessions table is
 * a list of hashes, and a hash cannot be sent as a bearer token.
 */
export const SESSION_TOKEN_PREFIX = 'soul_'

/** A hundred and eighty days. Long enough that a student never sees a login. */
export const SESSION_DAYS = 180

export function mintSessionToken(): string {
  return SESSION_TOKEN_PREFIX + randomBytes(32).toString('hex')
}

export function hashSessionToken(token: string): string {
  return createHash('sha256').update(token).digest('hex')
}

export function sessionExpiry(from: Date = new Date()): Date {
  return new Date(from.getTime() + SESSION_DAYS * 24 * 60 * 60 * 1000)
}
