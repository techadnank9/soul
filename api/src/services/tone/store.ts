import { and, eq, isNull } from 'drizzle-orm'
import { db, voiceTones } from '../../db.js'
import type { Session } from '../../session.js'

/** The stored shape, as the prompts and the read side see it. */
export type Tone = {
  emotion: string
  intensity: number
  intent: string
  sounded: string
  confidence: number
  wordsPerMinute: number | null
  pauses: number | null
  longestPauseMs: number | null
  hesitations: number | null
  audioEvents: string[]
  languageCode: string | null
}

const columns = {
  emotion: voiceTones.emotion,
  intensity: voiceTones.intensity,
  intent: voiceTones.intent,
  sounded: voiceTones.sounded,
  confidence: voiceTones.confidence,
  wordsPerMinute: voiceTones.wordsPerMinute,
  pauses: voiceTones.pauses,
  longestPauseMs: voiceTones.longestPauseMs,
  hesitations: voiceTones.hesitations,
  audioEvents: voiceTones.audioEvents,
  languageCode: voiceTones.languageCode,
}

/**
 * Hangs a tone row on the entry it was recorded for.
 *
 * Scoped to the student and to rows not yet linked, so an id lifted from
 * somebody else's device links nothing, and an id sent twice links once.
 * Returns whether anything was linked, and the caller carries on either way.
 */
export async function linkTone(
  toneId: string,
  entryId: string,
  session: Session,
): Promise<boolean> {
  const rows = await db
    .update(voiceTones)
    .set({ entryId })
    .where(
      and(
        eq(voiceTones.id, toneId),
        eq(voiceTones.studentId, session.studentId),
        isNull(voiceTones.entryId),
      ),
    )
    .returning({ id: voiceTones.id })
  return rows.length > 0
}

/** A transcript the student discarded takes its tone with it. */
export async function discardTone(toneId: string, session: Session): Promise<void> {
  await db
    .delete(voiceTones)
    .where(
      and(
        eq(voiceTones.id, toneId),
        eq(voiceTones.studentId, session.studentId),
        isNull(voiceTones.entryId),
      ),
    )
}

export async function loadTone(entryId: string, session: Session): Promise<Tone | null> {
  const rows = await db
    .select(columns)
    .from(voiceTones)
    .where(and(eq(voiceTones.entryId, entryId), eq(voiceTones.studentId, session.studentId)))
    .limit(1)
  return rows[0] ?? null
}
