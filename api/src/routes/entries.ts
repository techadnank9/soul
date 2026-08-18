import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { submit } from '../services/reflection/submit.js'
import { lookCloser } from '../services/reflection/mirror.js'
import { createDecision } from '../services/decisions/create.js'
import { recordOutcome } from '../services/decisions/recordOutcome.js'
import { answerCandidate } from '../services/patterns/answer.js'
import type { Session } from '../session.js'

/**
 * The HTTP boundary. Validation only.
 *
 * Route handlers parse the body and call one service. No business rule lives
 * in this file, and no service reaches for a request object.
 */
type Vars = { Variables: { session: Session } }

export const entries = new Hono<Vars>()

entries.post('/entries', async (c) => {
  const parsed = contracts.submitEntry.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid entry' }, 400)

  const result = await submit(c.get('session'), parsed.data)
  return c.json(result)
})

entries.post('/entries/:id/mirror', async (c) => {
  const reflection = await lookCloser(c.req.param('id'), c.get('session'))
  return c.json(reflection)
})

entries.post('/decisions', async (c) => {
  const parsed = contracts.createDecision.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid decision' }, 400)

  const id = await createDecision(c.get('session'), parsed.data)
  return c.json({ decisionId: id })
})

entries.post('/outcomes', async (c) => {
  const parsed = contracts.recordOutcome.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid outcome' }, 400)

  await recordOutcome(c.get('session'), parsed.data)
  return c.json({ ok: true })
})

entries.post('/patterns/answer', async (c) => {
  const parsed = contracts.answerCandidate.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid answer' }, 400)

  await answerCandidate(c.get('session'), parsed.data)
  return c.json({ ok: true })
})
