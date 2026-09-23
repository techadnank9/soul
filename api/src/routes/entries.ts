import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { submit } from '../services/reflection/submit.js'
import { lookCloser } from '../services/reflection/mirror.js'
import { createDecision } from '../services/decisions/create.js'
import { recordOutcome } from '../services/decisions/recordOutcome.js'
import { answerCandidate } from '../services/patterns/answer.js'
import { armPatternReminder } from '../services/patterns/remind.js'
import { answerNoticing } from '../services/noticings/answer.js'
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

  const startedAt = Date.now()
  const result = await submit(c.get('session'), parsed.data)
  console.log(`entry: ${result.state}, ${parsed.data.inputMode}, ${Date.now() - startedAt}ms`)
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

entries.post('/noticings/answer', async (c) => {
  const parsed = contracts.answerNoticing.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid answer' }, 400)

  await answerNoticing(c.get('session'), parsed.data)
  return c.json({ ok: true })
})

/**
 * A confirmed pattern, and an hour they picked to be told about it. Decision
 * 295. `services/patterns/remind.ts` says why it is written as a reminder.
 */
entries.post('/patterns/:id/remind', async (c) => {
  const body = await c.req.json().catch(() => null)
  const at = (body as { at?: unknown } | null)?.at

  if (typeof at !== 'string' || Number.isNaN(Date.parse(at))) {
    return c.json({ error: 'a time is needed' }, 400)
  }

  try {
    const { said } = await armPatternReminder(
      c.get('session'),
      c.req.param('id'),
      new Date(at),
    )
    return c.json({ ok: true, said })
  } catch (error) {
    const why = (error as Error).message
    if (why === 'that time has gone') return c.json({ error: why }, 400)
    return c.json({ error: 'not found' }, 404)
  }
})

entries.post('/patterns/answer', async (c) => {
  const parsed = contracts.answerCandidate.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid answer' }, 400)

  const answered = await answerCandidate(c.get('session'), parsed.data)
  // The pattern id comes back on a yes, so the app can offer the reminder
  // without a second read. Absent on the other two answers.
  return c.json({ ok: true, ...answered })
})
