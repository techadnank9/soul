import { call } from '../gateway/call.js'
import type { Session } from '../session.js'

/**
 * Beat one. One line back, under three seconds.
 *
 * The current entry only, with almost no history. This will feel wrong. The
 * decision is that the model should know the whole person, and it does, on the
 * Mirror call. Beat one stays minimal on purpose because latency and
 * specificity beat context here.
 *
 * The prompt itself lives in the database. This function decides what goes
 * into the call, not what the model is told to be.
 */
export function buildBeatOnePrompt(entryText: string): string {
  return `The student just said this:\n\n${entryText}`
}

export async function beatOne(
  entryText: string,
  session: Session,
  entryId: string,
): Promise<{ line: string; latencyMs: number }> {
  const result = await call<string>('beat_one', {
    user: buildBeatOnePrompt(entryText),
    session,
    entryId,
  })
  return { line: result.value, latencyMs: result.latencyMs }
}
