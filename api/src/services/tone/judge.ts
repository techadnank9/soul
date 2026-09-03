import { and, eq, isNull } from 'drizzle-orm'
import { checkConsent } from '../../consent/gate.js'
import { db, voiceTones } from '../../db.js'
import { call } from '../../gateway/call.js'
import { voiceToneResult, type VoiceToneResult } from '../../contracts.js'
import type { Session } from '../../session.js'
import type { Prosody } from '../transcribe/run.js'
import { ConsentRequired } from '../transcribe/run.js'

/**
 * How a recording sounded. The one call in the system that hears audio.
 *
 * It runs on the transcribe path alongside the transcriber, on the same bytes,
 * in the only moment they exist. It is a classification, not a generation:
 * nothing it returns is shown to a student, and the safety classifier still
 * runs on the words before anything is written back to them.
 *
 * The consent check is repeated here rather than trusted from the caller,
 * because this is a second place audio leaves and each one guards itself.
 */
export type Judged = VoiceToneResult & { model: string }

export async function judgeTone(
  audio: Uint8Array,
  contentType: string,
  session: Session,
): Promise<Judged> {
  const consented = await checkConsent(session, 'third_party_processing')
  if (!consented) throw new ConsentRequired('consent does not cover this student')

  const result = await call('voice_tone', {
    user: 'Listen to this recording and describe how the speaker sounded.',
    schema: voiceToneResult,
    session,
    audio: { bytes: audio, mimeType: contentType },
  })

  return { ...result.value, model: result.model }
}

/**
 * Writes the row and returns its id, before there is an entry to hang it on.
 *
 * Any earlier row of this student's that never found an entry is removed
 * first. A transcript that was discarded, or a session that was closed on the
 * confirm screen, leaves one behind, and a new recording is the natural moment
 * to let it go.
 */
export async function storeTone(
  session: Session,
  judged: Judged,
  prosody: Prosody,
): Promise<string> {
  await db
    .delete(voiceTones)
    .where(and(eq(voiceTones.studentId, session.studentId), isNull(voiceTones.entryId)))

  const rows = await db
    .insert(voiceTones)
    .values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      emotion: judged.emotion,
      intensity: judged.intensity,
      intent: judged.intent,
      sounded: judged.sounded,
      confidence: judged.confidence,
      wordsPerMinute: prosody.wordsPerMinute,
      pauses: prosody.pauses,
      longestPauseMs: prosody.longestPauseMs,
      hesitations: prosody.hesitations,
      audioEvents: prosody.audioEvents,
      languageCode: prosody.languageCode,
      languageProbability: prosody.languageProbability,
      meanLogprob: prosody.meanLogprob,
      durationMs: prosody.durationMs,
      modelVersion: judged.model,
    })
    .returning({ id: voiceTones.id })

  const row = rows[0]
  if (!row) throw new Error('voice tone insert returned no row')
  return row.id
}
