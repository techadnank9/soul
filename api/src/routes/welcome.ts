import { Hono } from 'hono'
import * as contracts from '../contracts.js'
import { eq } from 'drizzle-orm'
import { db, students } from '../db.js'
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
    const session = c.get('session')
    const opening = await welcomeLine(session, parsed.data)
    // Kept, because home shows both until there is a week of their own.
    await db
      .update(students)
      .set({ opening: opening.line, openingThemes: opening.themes })
      .where(eq(students.id, session.studentId))
    console.log(
      `welcome: ${opening.line.split(/\s+/).length} words, ` +
        `${opening.themes.length} themes, ${Date.now() - startedAt}ms`,
    )
    return c.json({ line: opening.line })
  } catch (error) {
    console.warn(`welcome: failed after ${Date.now() - startedAt}ms: ${(error as Error).message}`)
    return c.json({ error: 'no line' }, 502)
  }
})
