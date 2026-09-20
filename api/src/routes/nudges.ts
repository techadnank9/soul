import { Hono } from 'hono'
import { NUDGE_HOUR, nudgeLines } from '../services/nudges/lines.js'
import type { Session } from '../session.js'

type Vars = { Variables: { session: Session } }

/**
 * The evening question, for the phone to book itself.
 *
 * No dates and no times go out from here. The phone knows what tomorrow is
 * on its own clock and books the list against its own days, so nothing has
 * to be right about a timezone on this side for the right thing to ring at
 * eight in the evening where the person actually is.
 *
 * Nothing about the person goes out either. The same list, in an order that
 * is theirs, and not one word of it read from anything they wrote.
 */
export const nudges = new Hono<Vars>()

nudges.get('/nudges', async (c) => {
  return c.json({ hour: NUDGE_HOUR, lines: nudgeLines(c.get('session')) })
})
