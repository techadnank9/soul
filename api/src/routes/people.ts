import { Hono } from 'hono'
import { z } from 'zod'
import { listPeople, readPerson, editPerson, forgetPerson } from '../services/people/read.js'
import { mergePeople } from '../services/people/merge.js'
import type { Session } from '../session.js'

/**
 * The people a student writes about.
 *
 * This is the only way into a set of records about somebody who is not a user
 * of this product. Every route is scoped to the session student, an id that is
 * not theirs is not found rather than forbidden, and delete is here because
 * anything the app holds has to be something the student can remove.
 */
type Vars = { Variables: { session: Session } }

export const peopleRoutes = new Hono<Vars>()

const personId = z.string().uuid()

const edit = z.object({
  name: z.string().trim().min(1).max(30).optional(),
  relation: z.string().trim().max(60).optional(),
  reach: z.string().trim().max(200).optional(),
})

peopleRoutes.get('/people', async (c) => {
  return c.json(await listPeople(c.get('session')))
})

peopleRoutes.get('/people/:id', async (c) => {
  const id = personId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'invalid person' }, 400)

  const person = await readPerson(c.get('session'), id.data)
  if (!person) return c.json({ error: 'no such person' }, 404)

  return c.json(person)
})

peopleRoutes.patch('/people/:id', async (c) => {
  const id = personId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'invalid person' }, 400)

  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'invalid body' }, 400)
  }

  const parsed = edit.safeParse(body)
  if (!parsed.success) return c.json({ error: 'invalid person' }, 400)

  // A rename onto a name they already have merges the two, so the id that
  // comes back can differ from the one in the path.
  const survivor = await editPerson(c.get('session'), id.data, parsed.data)
  if (!survivor) return c.json({ error: 'no such person' }, 404)

  return c.json({ ok: true, id: survivor })
})

const merge = z.object({ into: z.string().uuid() })

/** The person in the path goes. The one in the body stays. */
peopleRoutes.post('/people/:id/merge', async (c) => {
  const id = personId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'invalid person' }, 400)

  let body: unknown
  try {
    body = await c.req.json()
  } catch {
    return c.json({ error: 'invalid body' }, 400)
  }

  const parsed = merge.safeParse(body)
  if (!parsed.success) return c.json({ error: 'invalid person' }, 400)
  if (parsed.data.into === id.data) return c.json({ error: 'same person' }, 400)

  const kept = await mergePeople(c.get('session'), parsed.data.into, id.data)
  if (!kept) return c.json({ error: 'no such person' }, 404)

  return c.json({ ok: true, id: kept })
})

peopleRoutes.delete('/people/:id', async (c) => {
  const id = personId.safeParse(c.req.param('id'))
  if (!id.success) return c.json({ error: 'invalid person' }, 400)

  const gone = await forgetPerson(c.get('session'), id.data)
  if (!gone) return c.json({ error: 'no such person' }, 404)

  // The entries stay. Only the record about somebody else goes.
  return c.json({ ok: true })
})
