import { Hono } from 'hono'
import { heldFacts, rewordFact, dropFact } from '../services/memory/held.js'
import { forgetEntry } from '../services/memory/forget.js'
import type { Session } from '../session.js'

type Vars = { Variables: { session: Session } }

/**
 * What the app holds about somebody, and the two things they can do to it.
 *
 * Everything here is scoped to the person in the session, inside the query
 * and not only by row level security. A memory screen is the one place where
 * reading somebody else's row would be the whole of the harm.
 */
export const memory = new Hono<Vars>()

memory.get('/memory', async (c) => {
  return c.json({ facts: await heldFacts(c.get('session')) })
})

memory.patch('/memory/facts/:id', async (c) => {
  const body = await c.req.json().catch(() => null)
  const sentence = (body as { sentence?: unknown } | null)?.sentence

  if (typeof sentence !== 'string' || !sentence.trim()) {
    return c.json({ error: 'a fact needs words' }, 400)
  }
  if (sentence.length > 240) {
    return c.json({ error: 'too long' }, 400)
  }

  try {
    await rewordFact(c.get('session'), c.req.param('id'), sentence)
    return c.json({ ok: true })
  } catch {
    return c.json({ error: 'not found' }, 404)
  }
})

memory.delete('/memory/facts/:id', async (c) => {
  try {
    await dropFact(c.get('session'), c.req.param('id'))
    return c.json({ ok: true })
  } catch {
    return c.json({ error: 'not found' }, 404)
  }
})

/**
 * A moment, taken back, with everything that was only ever true because of
 * it. See `services/memory/forget.ts` for what goes with it.
 */
memory.delete('/entries/:id', async (c) => {
  try {
    await forgetEntry(c.req.param('id'), c.get('session'))
    return c.json({ ok: true })
  } catch (error) {
    if ((error as Error).message === 'entry not found') {
      return c.json({ error: 'not found' }, 404)
    }
    throw error
  }
})
