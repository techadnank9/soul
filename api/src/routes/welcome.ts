import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { welcomeLine } from '../services/welcome/line.js'
import type { Session } from '../session.js'

/**
 * The last screen of first run asks for this the moment the baseline ends,
 * so it is written while the person is still recording an introduction and
 * there is nothing to wait for when the screen arrives.
 *
 * A failure here costs the screen one paragraph and nothing else, so the
 * client asks once and shows the rest of the screen either way.
 */
type Vars = { Variables: { session: Session } }

export const welcome = new Hono<Vars>()

welcome.post('/welcome', async (c) => {
  const parsed = contracts.welcomeAnswers.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid answers' }, 400)

  const startedAt = Date.now()
  try {
    const line = await welcomeLine(c.get('session'), parsed.data)
    console.log(`welcome: ${line.split(/\s+/).length} words, ${Date.now() - startedAt}ms`)
    return c.json({ line })
  } catch (error) {
    console.warn(`welcome: failed after ${Date.now() - startedAt}ms: ${(error as Error).message}`)
    return c.json({ error: 'no line' }, 502)
  }
})
