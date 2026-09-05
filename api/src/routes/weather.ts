import { Hono } from 'hono'
import { weatherNow } from '../services/weather/now.js'
import type { Session } from '../session.js'

/**
 * What the sky is doing where they are, and a question that follows from it.
 *
 * Home asks for this on its own rather than as part of the week, so a slow
 * or unreachable weather service costs the card and nothing else. Null when
 * there is no position, no region, or nothing came back, and the card is
 * simply not there.
 */
type Vars = { Variables: { session: Session } }

export const weather = new Hono<Vars>()

weather.get('/weather', async (c) => {
  const now = await weatherNow(c.get('session'))
  return c.json(now)
})
