import { sql } from '../../db.js'
import { mirror as generateMirror } from '../../generate/mirror.js'
import { surfaceCandidate } from '../patterns/surfaceCandidate.js'
import type { Session } from '../../session.js'
import type { MirrorResult } from '../../contracts.js'

/**
 * What the Mirror says when it cannot say anything of its own.
 *
 * The wording lives in the prompts table as an inactive row, purpose mirror,
 * version fallback.v1, so it can be changed without a deploy. It is read by
 * version and never by active: the active row for mirror is the model prompt,
 * and there can only be one active row per purpose. This constant is the same
 * text and it is what the student gets when the row itself cannot be read.
 */
export const FALLBACK_QUESTION = 'Is there anything you might do about this, or nothing for now?'
const FALLBACK_VERSION = 'fallback.v1'

/**
 * Flow 2. The student asked to look closer.
 *
 * A pattern candidate, if one is waiting, is attached here as a question. It
 * is never asserted and it is never the whole screen. It arrives inside a
 * reflection the student asked for.
 *
 * The Mirror never fails the reflection. When the model call throws, whatever
 * the reason, the student gets one plain question back and the entry stands
 * as it was. A candidate is only offered inside a reflection that was
 * actually written, so surfacing happens after generation and not on the
 * fallback path.
 */
export async function lookCloser(
  entryId: string,
  session: Session,
): Promise<MirrorResult> {
  let reflection
  try {
    reflection = await generateMirror(entryId, session)
  } catch (error) {
    console.log(`mirror_fallback: ${(error as Error).message}`)
    return { state: 'fallback', question: await fallbackQuestion() }
  }

  const candidate = await surfaceCandidate(session)

  return candidate
    ? { state: 'reflected', ...reflection, patternCandidate: candidate }
    : { state: 'reflected', ...reflection }
}

async function fallbackQuestion(): Promise<string> {
  try {
    const rows = await sql<{ text: string }[]>`
      select text from prompts
      where purpose = 'mirror' and version = ${FALLBACK_VERSION}
      limit 1`
    const text = rows[0]?.text?.trim()
    return text || FALLBACK_QUESTION
  } catch {
    return FALLBACK_QUESTION
  }
}
