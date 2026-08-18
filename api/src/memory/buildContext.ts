import { and, desc, eq, isNull, sql as raw } from 'drizzle-orm'
import { db, entries, keptLines, confirmedPatterns, decisions, outcomes } from '../db.js'
import type { Session } from '../session.js'

/**
 * The single most important function in the system.
 *
 * A pure function: student and entry in, prompt string out. Everything about
 * memory quality lives here. It is the first place to look when a response
 * feels wrong, and it must stay testable and loggable.
 *
 * History comes first as a stable prefix, ordered identically every time, so
 * providers can cache it. The current entry goes last.
 */

export type Context = {
  patterns: string[]
  keptLines: string[]
  openDecisions: { chose: string; horizon: Date }[]
  pastOutcomes: { chose: string; happened: string | null; felt: string | null }[]
  recentEntries: { text: string; at: Date }[]
}

const RECENT_ENTRIES = 8
const KEPT_LINES = 6
const PAST_OUTCOMES = 6

export async function loadContext(
  session: Session,
  excludeEntryId?: string,
): Promise<Context> {
  const [patterns, kept, open, past, recent] = await Promise.all([
    db
      .select({ theme: confirmedPatterns.theme })
      .from(confirmedPatterns)
      .where(
        and(
          eq(confirmedPatterns.studentId, session.studentId),
          isNull(confirmedPatterns.removedAt),
        ),
      )
      .orderBy(desc(confirmedPatterns.confirmedAt)),

    db
      .select({ text: keptLines.text })
      .from(keptLines)
      .where(eq(keptLines.studentId, session.studentId))
      .orderBy(desc(keptLines.createdAt))
      .limit(KEPT_LINES),

    db
      .select({ chose: decisions.chosenText, horizon: decisions.horizon })
      .from(decisions)
      .where(
        and(eq(decisions.studentId, session.studentId), eq(decisions.status, 'open')),
      )
      .orderBy(desc(decisions.createdAt)),

    db
      .select({
        chose: decisions.chosenText,
        happened: outcomes.whatHappened,
        felt: outcomes.felt,
      })
      .from(outcomes)
      .innerJoin(decisions, eq(outcomes.decisionId, decisions.id))
      .where(eq(outcomes.studentId, session.studentId))
      .orderBy(desc(outcomes.respondedAt))
      .limit(PAST_OUTCOMES),

    db
      .select({ text: entries.text, at: entries.createdAt })
      .from(entries)
      .where(
        excludeEntryId
          ? and(
              eq(entries.studentId, session.studentId),
              raw`${entries.id} <> ${excludeEntryId}`,
            )
          : eq(entries.studentId, session.studentId),
      )
      .orderBy(desc(entries.createdAt))
      .limit(RECENT_ENTRIES),
  ])

  return {
    patterns: patterns.map((p) => p.theme),
    keptLines: kept.map((k) => k.text),
    openDecisions: open.map((d) => ({ chose: d.chose, horizon: d.horizon })),
    pastOutcomes: past,
    recentEntries: recent,
  }
}

/**
 * The stable prefix. Same order every time, so a provider can cache it and so a
 * change in the output can be traced to a change in the entry rather than to a
 * reshuffle of the history.
 *
 * Confirmed patterns are quoted verbatim. They are the student's own words
 * about themselves and paraphrasing them would be us asserting something they
 * did not confirm.
 */
export function renderContext(context: Context): string {
  const parts: string[] = []

  if (context.patterns.length) {
    parts.push(
      'Patterns this student has confirmed about themselves, in their words:\n' +
        context.patterns.map((p) => `  ${p}`).join('\n'),
    )
  }

  if (context.keptLines.length) {
    parts.push(
      'Lines they chose to keep:\n' +
        context.keptLines.map((l) => `  ${l}`).join('\n'),
    )
  }

  if (context.openDecisions.length) {
    parts.push(
      'Things they are currently holding:\n' +
        context.openDecisions
          .map((d) => `  ${d.chose} (by ${d.horizon.toDateString()})`)
          .join('\n'),
    )
  }

  if (context.pastOutcomes.length) {
    parts.push(
      'What happened when they acted before:\n' +
        context.pastOutcomes
          .map(
            (o) =>
              `  they chose to ${o.chose}. ` +
              `${o.happened ?? 'no answer'}. felt ${o.felt ?? 'unrecorded'}`,
          )
          .join('\n'),
    )
  }

  if (context.recentEntries.length) {
    parts.push(
      'Recent entries, newest last:\n' +
        [...context.recentEntries]
          .reverse()
          .map((e) => `  [${e.at.toDateString()}] ${e.text}`)
          .join('\n'),
    )
  }

  return parts.join('\n\n')
}
