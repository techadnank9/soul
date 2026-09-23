import { and, desc, eq, inArray } from 'drizzle-orm'
import { db, confirmedPatterns, entries } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * A pattern they confirmed, in their words and at their reading.
 *
 * Two things a person can change about a pattern, and both were missing.
 *
 * The wording. What is stored as the theme is a word from a closed list, and
 * what somebody reads should be a sentence they would say. Editing the theme
 * itself is not on offer: the theme is what the counting and the exclusion
 * run on, and free text there is decision 259 all over again. The wording
 * sits beside it and is what is shown.
 *
 * Where it stands. Still true, changing, or it does not fit any more. The
 * model already writes a verdict at night about whether a theme is doing
 * somebody good or costing them, and FLOW.md already says the person's own
 * outcomes outrank it. This is the same rule made direct: where they have
 * said where it stands, that is what stands.
 *
 * Decision 298.
 */
export const STANDINGS = ['still_true', 'changing', 'does_not_fit'] as const
export type Standing = (typeof STANDINGS)[number]

function mine(patternId: string, session: Session) {
  return and(
    eq(confirmedPatterns.id, patternId),
    eq(confirmedPatterns.studentId, session.studentId),
  )
}

export async function rewordPattern(
  session: Session,
  patternId: string,
  wording: string,
): Promise<void> {
  const said = wording.trim()
  if (!said) throw new Error('a pattern cannot be emptied, only taken down')

  const done = await db
    .update(confirmedPatterns)
    .set({ wording: said })
    .where(mine(patternId, session))

  if (done.count === 0) throw new Error('pattern not found')
}

export async function setStanding(
  session: Session,
  patternId: string,
  standing: Standing,
): Promise<void> {
  const done = await db
    .update(confirmedPatterns)
    .set({ standing })
    .where(mine(patternId, session))

  if (done.count === 0) throw new Error('pattern not found')
}

/**
 * Taken down by the person it is about. The moments behind it are untouched:
 * they wrote them, and only our claim about them is gone. This is what the
 * removed_at column was always for.
 */
export async function takeDownPattern(
  session: Session,
  patternId: string,
): Promise<void> {
  const done = await db
    .update(confirmedPatterns)
    .set({ removedAt: new Date() })
    .where(mine(patternId, session))

  if (done.count === 0) throw new Error('pattern not found')
}

/**
 * The moments behind a confirmed pattern, for see the moments. Their own
 * words with the dates, never a line written about them.
 */
export async function patternMoments(
  session: Session,
  patternId: string,
): Promise<{ entryId: string; at: string; said: string }[]> {
  const rows = await db
    .select({ supporting: confirmedPatterns.supportingEntryIds })
    .from(confirmedPatterns)
    .where(mine(patternId, session))
    .limit(1)

  const supporting = rows[0]?.supporting ?? []
  if (!supporting.length) return []

  const written = await db
    .select({ id: entries.id, text: entries.text, at: entries.createdAt })
    .from(entries)
    .where(
      and(inArray(entries.id, supporting), eq(entries.studentId, session.studentId)),
    )
    .orderBy(desc(entries.createdAt))

  return written.map((entry) => ({
    entryId: entry.id,
    at: entry.at.toISOString(),
    said: entry.text.trim().replace(/\s+/g, ' ').slice(0, 200),
  }))
}
