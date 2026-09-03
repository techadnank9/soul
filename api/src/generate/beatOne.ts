import { call } from '../gateway/call.js'
import { renderTone } from '../services/tone/render.js'
import type { Tone } from '../services/tone/store.js'
import type { Session } from '../session.js'

/**
 * Beat one. One line back, under three seconds.
 *
 * The current entry only, with almost no history. This will feel wrong. The
 * decision is that the model should know the whole person, and it does, on the
 * Mirror call. Beat one stays minimal on purpose because latency and
 * specificity beat context here.
 *
 * The one thing beat one is told beyond the entry is how it sounded, when it
 * was spoken. That is about this entry, not about history, so it does not
 * break the rule above. The prompt is told to use it for register and never
 * to say it back.
 *
 * The prompt itself lives in the database. This function decides what goes
 * into the call, not what the model is told to be.
 */
export function buildBeatOnePrompt(entryText: string, tone: Tone | null = null): string {
  const said = `The student just said this:\n\n${entryText}`
  if (!tone) return said
  return `${said}\n\nHow they sounded, from their voice:\n${renderTone(tone)}`
}

export async function beatOne(
  entryText: string,
  session: Session,
  entryId: string,
  tone: Tone | null = null,
): Promise<{ line: string; latencyMs: number }> {
  const result = await call<string>('beat_one', {
    user: buildBeatOnePrompt(entryText, tone),
    session,
    entryId,
  })
  return { line: result.value, latencyMs: result.latencyMs }
}
