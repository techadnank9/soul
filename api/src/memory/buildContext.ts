import {
  and,
  cosineDistance,
  desc,
  eq,
  inArray,
  isNotNull,
  isNull,
  notInArray,
  sql as raw,
} from 'drizzle-orm'
import {
  db,
  entries,
  entryEmbeddings,
  facts,
  keptLines,
  confirmedPatterns,
  decisions,
  outcomes,
  voiceTones,
} from '../db.js'
import { renderToneBrief } from '../services/tone/render.js'
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
 *
 * Three sources are fused. Time is the recent entries. Meaning is the nearest
 * entries by embedding to the one just written, from any month. The graph is
 * the open facts the entry touches, each with what happened when they acted
 * on the entries behind it. Only the Mirror reads this. Beat one gets almost
 * no history, on purpose, and nothing here changes that.
 */

export type Outcome = { chose: string; happened: string | null; felt: string | null }

export type Context = {
  patterns: string[]
  keptLines: string[]
  openDecisions: { chose: string; horizon: Date }[]
  pastOutcomes: Outcome[]
  /**
   * What they have said is so and still holds, in their words, with the
   * outcomes of any decisions on the entries it came from. since is when it
   * started to hold in their life, not when the system learned it.
   */
  facts: { sentence: string; since: Date; outcomes: Outcome[] }[]
  /**
   * Earlier entries that read like this one, by embedding, from any time.
   * Never one of the recent entries and never the current one. Empty until
   * the current entry has been embedded, which happens in the background.
   */
  similarEntries: { text: string; at: Date; sounded: string | null }[]
  /**
   * sounded is one clause on how a spoken entry came across, and null for a
   * typed one. It rides along with the entry so the Mirror knows not just
   * what was said lately but how, which is the whole reason tone is stored.
   */
  recentEntries: { text: string; at: Date; sounded: string | null }[]
}

const RECENT_ENTRIES = 8
const SIMILAR_ENTRIES = 12
const KEPT_LINES = 6
const PAST_OUTCOMES = 6
/** How many open facts are read before the entry picks from them. */
const OPEN_FACTS = 60
/** How many facts the Mirror is shown, name matches first, nearest after. */
const SHOWN_FACTS = 12
const NEAR_FACTS = 8

type EntryRow = {
  text: string
  at: Date
  emotion: string | null
  intent: string | null
}

function brief(e: EntryRow): { text: string; at: Date; sounded: string | null } {
  return {
    text: e.text,
    at: e.at,
    sounded:
      e.emotion && e.intent
        ? renderToneBrief({
            emotion: e.emotion,
            intent: e.intent,
            intensity: 0,
            sounded: '',
            confidence: 0,
            wordsPerMinute: null,
            pauses: null,
            longestPauseMs: null,
            hesitations: null,
            audioEvents: [],
            languageCode: null,
          })
        : null,
  }
}

/**
 * Whether a name the student used appears in what they just wrote, as a
 * whole word. Mum in mumbled is not Mum. The pronoun I is skipped, because a
 * fact about the student themselves is in nearly every entry by that test
 * and is found by meaning instead.
 */
export function mentions(text: string, name: string): boolean {
  const trimmed = name.trim()
  if (trimmed.length < 2) return false
  const escaped = trimmed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return new RegExp(`(^|[^\\p{L}\\p{N}])${escaped}(?=$|[^\\p{L}\\p{N}])`, 'iu').test(text)
}

export async function loadContext(
  session: Session,
  excludeEntryId?: string,
): Promise<Context> {
  const [patterns, kept, open, past, recent, current] = await Promise.all([
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

    /**
     * Every open decision, whatever asked for it.
     *
     * A cue card answer writes a decisions row itself rather than a row of its
     * own kind, so a thing chosen on a card is already in this result and
     * there is nothing here that could tell it from a thing chosen after the
     * Mirror. That is deliberate and it is what keeps the model from having
     * two half memories of the same student. Anything that later gives cards
     * their own table has to add them back here by hand.
     */
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
      .select({
        id: entries.id,
        text: entries.text,
        at: entries.createdAt,
        emotion: voiceTones.emotion,
        intent: voiceTones.intent,
      })
      .from(entries)
      .leftJoin(voiceTones, eq(voiceTones.entryId, entries.id))
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

    /**
     * The entry being looked at, with its vector if the embedding job has
     * run. Scoped to the student like everything else here, so an id from
     * another student's life loads nothing and the Mirror gets no history
     * that is not this student's own.
     */
    excludeEntryId
      ? db
          .select({ text: entries.text, embedding: entryEmbeddings.embedding })
          .from(entries)
          .leftJoin(entryEmbeddings, eq(entryEmbeddings.entryId, entries.id))
          .where(and(eq(entries.id, excludeEntryId), eq(entries.studentId, session.studentId)))
          .limit(1)
          .then((rows) => rows[0] ?? null)
      : Promise.resolve(null),
  ])

  const recentIds = recent.map((e) => e.id)
  const excluded = excludeEntryId ? [excludeEntryId, ...recentIds] : recentIds

  const [similar, matched] = await Promise.all([
    current?.embedding
      ? db
          .select({
            id: entries.id,
            text: entries.text,
            at: entries.createdAt,
            emotion: voiceTones.emotion,
            intent: voiceTones.intent,
          })
          .from(entryEmbeddings)
          .innerJoin(entries, eq(entries.id, entryEmbeddings.entryId))
          .leftJoin(voiceTones, eq(voiceTones.entryId, entries.id))
          .where(
            and(
              eq(entryEmbeddings.studentId, session.studentId),
              notInArray(entries.id, excluded),
            ),
          )
          .orderBy(cosineDistance(entryEmbeddings.embedding, current.embedding))
          .limit(SIMILAR_ENTRIES)
      : Promise.resolve([] as (EntryRow & { id: string })[]),

    current ? loadFacts(session, current.text, current.embedding) : Promise.resolve([]),
  ])

  return {
    patterns: patterns.map((p) => p.theme),
    keptLines: kept.map((k) => k.text),
    openDecisions: open.map((d) => ({ chose: d.chose, horizon: d.horizon })),
    pastOutcomes: past,
    facts: matched,
    similarEntries: similar.map(brief),
    recentEntries: recent.map(brief),
  }
}

/**
 * The open facts this entry touches, and what came of acting on them.
 *
 * Two ways in. By name: the fact's subject or object appears in the entry as
 * a word. By meaning: the fact's sentence is near the entry's vector. Name
 * matches go first because they are certain, nearest fill what is left, and
 * the whole thing is capped so a person with a long record is not read a
 * long list. Ordered oldest first within each group, which is the order
 * they happened in.
 *
 * Open means valid_to and retired_at are both null. A fact that has been
 * closed is never loaded as current, however near it is.
 */
async function loadFacts(
  session: Session,
  entryText: string,
  embedding: number[] | null,
): Promise<Context['facts']> {
  const open = and(
    eq(facts.studentId, session.studentId),
    isNull(facts.validTo),
    isNull(facts.retiredAt),
  )

  const [held, near] = await Promise.all([
    db
      .select({
        id: facts.id,
        subject: facts.subject,
        object: facts.object,
        sentence: facts.sentence,
        since: facts.validFrom,
        entryIds: facts.entryIds,
      })
      .from(facts)
      .where(open)
      .orderBy(desc(facts.validFrom))
      .limit(OPEN_FACTS),

    embedding
      ? db
          .select({
            id: facts.id,
            subject: facts.subject,
            object: facts.object,
            sentence: facts.sentence,
            since: facts.validFrom,
            entryIds: facts.entryIds,
          })
          .from(facts)
          .where(and(open, isNotNull(facts.embedding)))
          .orderBy(cosineDistance(facts.embedding, embedding))
          .limit(NEAR_FACTS)
      : Promise.resolve([]),
  ])

  const byName = held.filter(
    (f) => mentions(entryText, f.subject) || mentions(entryText, f.object),
  )
  const seen = new Set(byName.map((f) => f.id))
  const chosen = [...byName, ...near.filter((f) => !seen.has(f.id))].slice(0, SHOWN_FACTS)
  if (!chosen.length) return []

  // What happened when they acted on the entries behind these facts. One
  // query for all of them, then dealt out by entry id.
  const entryIds = [...new Set(chosen.flatMap((f) => f.entryIds))]
  const acted = !entryIds.length
    ? []
    : await db
        .select({
          entryId: decisions.entryId,
          chose: decisions.chosenText,
          happened: outcomes.whatHappened,
          felt: outcomes.felt,
          at: outcomes.respondedAt,
        })
        .from(outcomes)
        .innerJoin(decisions, eq(outcomes.decisionId, decisions.id))
        .where(and(eq(outcomes.studentId, session.studentId), inArray(decisions.entryId, entryIds)))
        .orderBy(outcomes.respondedAt)

  return chosen
    .sort((a, b) => a.since.getTime() - b.since.getTime())
    .map((f) => ({
      sentence: f.sentence,
      since: f.since,
      outcomes: acted
        .filter((o) => f.entryIds.includes(o.entryId))
        .map((o) => ({ chose: o.chose, happened: o.happened, felt: o.felt })),
    }))
}

function renderOutcome(o: Outcome): string {
  return `they chose to ${o.chose}. ${o.happened ?? 'no answer'}. felt ${o.felt ?? 'unrecorded'}`
}

/**
 * The stable prefix. Same order every time, so a provider can cache it and so a
 * change in the output can be traced to a change in the entry rather than to a
 * reshuffle of the history.
 *
 * Confirmed patterns are quoted verbatim. They are the student's own words
 * about themselves and paraphrasing them would be us asserting something they
 * did not confirm. Facts are quoted the same way, for the same reason.
 *
 * The parts that depend only on the student come first. The two that depend
 * on the entry, the facts it touches and the entries that read like it, come
 * after, and the recent entries last so that newest last runs straight into
 * what they just said.
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
        context.pastOutcomes.map((o) => `  ${renderOutcome(o)}`).join('\n'),
    )
  }

  if (context.facts.length) {
    parts.push(
      'Things they have said that still hold, in their words, oldest first, ' +
        'with what happened when they acted on them:\n' +
        context.facts
          .map(
            (f) =>
              `  [since ${f.since.toDateString()}] ${f.sentence}` +
              f.outcomes.map((o) => `\n      ${renderOutcome(o)}`).join(''),
          )
          .join('\n'),
    )
  }

  if (context.similarEntries.length) {
    parts.push(
      'Earlier entries that read like this one, oldest first:\n' +
        [...context.similarEntries]
          .sort((a, b) => a.at.getTime() - b.at.getTime())
          .map(
            (e) =>
              `  [${e.at.toDateString()}] ${e.text}` +
              (e.sounded ? ` (${e.sounded})` : ''),
          )
          .join('\n'),
    )
  }

  if (context.recentEntries.length) {
    parts.push(
      'Recent entries, newest last:\n' +
        [...context.recentEntries]
          .reverse()
          .map(
            (e) =>
              `  [${e.at.toDateString()}] ${e.text}` +
              (e.sounded ? ` (${e.sounded})` : ''),
          )
          .join('\n'),
    )
  }

  return parts.join('\n\n')
}
