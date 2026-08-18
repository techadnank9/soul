import { eq } from 'drizzle-orm'
import { db, entries } from '../db.js'
import { call } from '../gateway/call.js'
import { loadContext, renderContext } from '../memory/buildContext.js'
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
export function buildMirrorPrompt(history: string, entryText: string): string {
  return (
    `${history}\n\n` +
    `----\n` +
    `What they just said:\n\n${entryText}`
  )
}

export async function mirror(
  entryId: string,
  session: Session,
): Promise<MirrorResult> {
  const rows = await db
    .select({ text: entries.text })
    .from(entries)
    .where(eq(entries.id, entryId))
    .limit(1)

  const entry = rows[0]
  if (!entry) throw new Error('entry not found')

  const context = await loadContext(session, entryId)
  const history = renderContext(context)

  const result = await call('mirror', {
    user: buildMirrorPrompt(history, entry.text),
    schema: mirrorResult,
    session,
    entryId,
  })

  return result.value
}
