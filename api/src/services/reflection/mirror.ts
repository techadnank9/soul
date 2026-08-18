import { mirror as generateMirror } from '../../generate/mirror.js'
import { surfaceCandidate } from '../patterns/surfaceCandidate.js'
import type { Session } from '../../session.js'
import type { MirrorResult } from '../../contracts.js'

/**
 * Flow 2. The student asked to look closer.
 *
 * A pattern candidate, if one is waiting, is attached here as a question. It
 * is never asserted and it is never the whole screen. It arrives inside a
 * reflection the student asked for.
 */
export async function lookCloser(
  entryId: string,
  session: Session,
): Promise<MirrorResult> {
  const reflection = await generateMirror(entryId, session)
  const candidate = await surfaceCandidate(session)

  return candidate ? { ...reflection, patternCandidate: candidate } : reflection
}
