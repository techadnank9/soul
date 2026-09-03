import { env } from '../env.js'

/**
 * One email, through Resend, over plain fetch. No SDK, for the same reason no
 * other provider has one: a package is a dependency tree and Resend is
 * already a name in the data agreement for what it does, which is deliver
 * this one message.
 */
export class EmailUnavailable extends Error {}

export async function sendSignInCode(to: string, code: string): Promise<void> {
  const key = env.providers.resendKey
  if (!key) throw new EmailUnavailable('RESEND_API_KEY is not set')

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      from: env.resendFrom(),
      to: [to],
      subject: `${code} is your Soul code`,
      text:
        `Your code is ${code}. It works for ten minutes.\n\n` +
        `If you did not ask for it, you can ignore this. Nothing else will ever be sent to this address.`,
    }),
    signal: AbortSignal.timeout(10_000),
  })

  if (!response.ok) {
    const detail = await response.text().catch(() => '')
    throw new Error(`resend returned ${response.status}: ${detail.slice(0, 200)}`)
  }
}
