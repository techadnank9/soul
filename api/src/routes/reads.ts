import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { week } from '../services/reads/week.js'
import { day } from '../services/reads/day.js'
import { days } from '../services/reads/days.js'
import { patterns } from '../services/reads/patterns.js'
import { reflection } from '../services/reads/reflection.js'
import type { Session } from '../session.js'

/**
 * The read side. The screens that show a student their own life.
 *
 * No path carries a student id. Every one of these answers for the session
 * student and for nobody else, so there is no id to get wrong.
 */
type Vars = { Variables: { session: Session } }

export const reads = new Hono<Vars>()

reads.get('/week', async (c) => {
  return c.json(await week(c.get('session')))
})

reads.get('/days', async (c) => {
  return c.json(await days(c.get('session')))
})

reads.get('/day/:date', async (c) => {
  const parsed = contracts.dayDate.safeParse(c.req.param('date'))
  if (!parsed.success) return c.json({ error: 'invalid date' }, 400)

  return c.json(await day(c.get('session'), parsed.data))
})

/**
 * One reflection, with the entries behind it.
 *
 * The theme arrives as a query parameter rather than a path segment because it
 * is the student's own words from the tagger and carries spaces and
 * apostrophes.
 */
reads.get('/reflection', async (c) => {
  const theme = c.req.query('theme')
  if (!theme || theme.length > 200) return c.json({ error: 'invalid theme' }, 400)

  const view = await reflection(c.get('session'), theme)
  if (!view) return c.json({ error: 'no such reflection' }, 404)

  return c.json(view)
})

reads.get('/patterns', async (c) => {
  return c.json(await patterns(c.get('session')))
})
