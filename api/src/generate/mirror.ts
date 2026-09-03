import { and, eq } from 'drizzle-orm'
import { db, entries } from '../db.js'
import { call } from '../gateway/call.js'
import { loadContext, renderContext } from '../memory/buildContext.js'
import { renderTone } from '../services/tone/render.js'
import { loadTone, type Tone } from '../services/tone/store.js'
import { mirrorResult, type MirrorResult } from '../contracts.js'
import type { Session } from '../session.js'

/**
 * The Mirror. Second model call, only on request.
 *
 * Full context: confirmed patterns verbatim, kept lines, open decisions, past
 * outcomes, recent entries. History first as a stable prefix so providers can
 * cache it, current entry last.
 *
 * The reply is validated against a schema before display or storage. Prose is
 * rejected, never stored.
 */
export function buildMirrorPrompt(
  history: string,
  entryText: string,
  tone: Tone | null = null,
): string {
  const sounded = tone ? `\n\nHow they sounded, from their voice:\n${renderTone(tone)}` : ''
  return (
    `${history}\n\n` +
    `----\n` +
    `What they just said:\n\n${entryText}${sounded}`
  )
}

export async function mirror(
  entryId: string,
  session: Session,
): Promise<MirrorResult> {
  /**
   * Scoped to the student, not just to the id.
   *
   * This runs on the pooled handle rather than inside asStudent, so row level
   * security is not the thing keeping one student out of another's entry. The
   * where clause is. Without the student here, anybody signed in could post
   * somebody else's entry id to /entries/:id/mirror and have the whole of that
   * entry read back to them through the model.
   *
   * Not found rather than forbidden, so a guessed id cannot be confirmed as
   * real. Same reasoning as the cue card path.
   */
  const rows = await db
    .select({ text: entries.text })
    .from(entries)
    .where(and(eq(entries.id, entryId), eq(entries.studentId, session.studentId)))
    .limit(1)

  const entry = rows[0]
  if (!entry) throw new Error('entry not found')

  const [context, tone] = await Promise.all([
    loadContext(session, entryId),
    loadTone(entryId, session),
  ])
  const history = renderContext(context)

  const result = await call('mirror', {
    user: buildMirrorPrompt(history, entry.text, tone),
    schema: mirrorResult,
    session,
    entryId,
  })

  return result.value
}
