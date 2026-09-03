import { and, desc, eq, isNull } from 'drizzle-orm'
import { db, entries, facts } from '../../db.js'
import { call, embed } from '../../gateway/call.js'
import { factsResult } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The facts in one entry.
 *
 * Runs after the tagger, in its own job, on the entry the student just wrote.
 * It reads what they said is so out of their own words and writes each thing
 * as a row with the time it started to hold. The facts already held about
 * them are shown to the model so the same thing is named the same way twice,
 * which is what lets a change be seen as a change.
 *
 * Nothing is deleted here. A new fact with the same subject and predicate as
 * an open one and a different object closes the old one by setting valid_to
 * to the moment the new one starts. The old row stays, so the record can say
 * what was so in March as well as what is so now. A fact said again, same
 * subject, predicate and object, is not a second row: the new entry is added
 * to the ones behind it.
 *
 * The embedding is written when it can be. A fact whose vector fails is still
 * a fact and is still found by name, so the vector is not the reason a job
 * fails.
 */

/** How many held facts the model is shown, newest first. */
const HELD_FACTS = 40

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase()
}

export function renderHeldFacts(held: { subject: string; predicate: string; object: string }[]): string {
  if (!held.length) return ''
  return (
    '\n\nFacts already held about them, in their words:\n' +
    held.map((f) => `  ${f.subject} | ${f.predicate} | ${f.object}`).join('\n')
  )
}

export async function extractFacts(entryId: string, session: Session): Promise<number> {
  const rows = await db
    .select({ text: entries.text, at: entries.createdAt })
    .from(entries)
    .where(and(eq(entries.id, entryId), eq(entries.studentId, session.studentId)))
    .limit(1)

  const entry = rows[0]
  if (!entry) return 0

  const held = await db
    .select({
      id: facts.id,
      subject: facts.subject,
      predicate: facts.predicate,
      object: facts.object,
      entryIds: facts.entryIds,
    })
    .from(facts)
    .where(
      and(
        eq(facts.studentId, session.studentId),
        isNull(facts.validTo),
        isNull(facts.retiredAt),
      ),
    )
    .orderBy(desc(facts.validFrom))
    .limit(HELD_FACTS)

  const result = await call('facts', {
    user: entry.text + renderHeldFacts(held),
    schema: factsResult,
    session,
    entryId,
  })

  let written = 0

  for (const found of result.value.facts) {
    const open = held.filter(
      (h) => same(h.subject, found.subject) && same(h.predicate, found.predicate),
    )

    // Said again. The entry joins the ones behind the fact and nothing else
    // changes, so a student who says the same thing every week has one fact
    // with many entries rather than many facts with one each.
    const repeat = open.find((h) => same(h.object, found.object))
    if (repeat) {
      if (!repeat.entryIds.includes(entryId)) {
        await db
          .update(facts)
          .set({ entryIds: [...repeat.entryIds, entryId] })
          .where(eq(facts.id, repeat.id))
      }
      continue
    }

    // Contradicted. The open fact with the same subject and predicate stops
    // holding when this one starts. Closed, not deleted, and not retired
    // either: retired_at is for a fact the system stopped trusting, which is
    // a different thing from a fact that stopped being so.
    for (const old of open) {
      await db
        .update(facts)
        .set({ validTo: entry.at })
        .where(and(eq(facts.id, old.id), isNull(facts.validTo)))
    }

    const vector = await embedding(found.sentence, entryId, session)

    await db.insert(facts).values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      subject: found.subject,
      predicate: found.predicate,
      object: found.object,
      sentence: found.sentence,
      entryIds: [entryId],
      validFrom: entry.at,
      confidence: found.confidence,
      tier: 0,
      embedding: vector,
    })

    written += 1
  }

  return written
}

/**
 * The vector for a fact's sentence, or null when it could not be had.
 *
 * Logged rather than thrown. The fact is the record and the vector is one of
 * two ways to find it, and a job that failed for want of a vector would retry
 * the model call and write the facts twice.
 */
async function embedding(
  sentence: string,
  entryId: string,
  session: Session,
): Promise<number[] | null> {
  try {
    const result = await embed({ text: sentence, session, entryId })
    return result.vector
  } catch (error) {
    console.warn(`fact not embedded: ${(error as Error).message}`)
    return null
  }
}
