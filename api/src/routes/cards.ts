import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { answerCard } from '../services/cards/answer.js'
import { deferCard } from '../services/cards/defer.js'
import type { Session } from '../session.js'

/**
 * Cue cards. One route, because a card is only ever read as part of a day.
 *
 * Validation only, like the rest of the boundary. The service decides what
 * happened and this file decides which status says so.
 */
type Vars = { Variables: { session: Session } }

export const cards = new Hono<Vars>()

cards.post('/cards/:id/answer', async (c) => {
  // An id that is not a uuid names no card of theirs either, so it gets the
  // same answer as one that belongs to somebody else.
  const id = contracts.cardId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'no such card' }, 404)

  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    // Not json at all. A 500 here blamed the server for what the caller sent.
    return c.json({ error: 'invalid body' }, 400)
  }

  const parsed = contracts.answerCard.safeParse(body)
  if (!parsed.success) return c.json({ error: 'invalid answer' }, 400)

  const result = await answerCard(c.get('session'), { cardId: id.data, ...parsed.data })

  if (!result.ok) {
    if (result.reason === 'already_answered') {
      return c.json({ error: 'already answered' }, 409)
    }
    return c.json({ error: 'no such card' }, 404)
  }

  // Null on a no, which is a two hundred like any other. The student answered
  // the question and there was nothing to book.
  return c.json({ decisionId: result.decisionId })
})

/** Later. The card goes until tomorrow and nothing is recorded about it. */
cards.post('/cards/:id/later', async (c) => {
  const id = contracts.cardId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'no such card' }, 404)

  const put = await deferCard(c.get('session'), id.data)
  if (!put) return c.json({ error: 'no such card' }, 404)

  console.log(`card: put off until tomorrow`)
  return c.json({ ok: true })
})
