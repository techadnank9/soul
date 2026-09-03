import { and, asc, desc, eq, inArray, isNull, notInArray, sql as raw } from 'drizzle-orm'
import { db, facts, sql } from '../../db.js'
import { call, embed } from '../../gateway/call.js'
import { checkConsent } from '../../consent/gate.js'
import { consolidateResult } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The nightly consolidation. Step five of docs/memory.md.
 *
 * Once a night, for each person with new facts since their last
 * consolidation, a model reads the facts that arrived, the open facts already
 * held, and the observations already written, and writes at most three
 * things that hold across them. Each one is a tier 1 row in the same facts
 * table, carrying the entry ids of every fact it was drawn from, so it can be
 * opened to the words behind it like any other fact and is read by the
 * context builder like any other open fact.
 *
 * Never on the request path. It is a model call over a person's facts, it
 * runs in the night from the job runner, and nothing a person does waits on
 * it.
 *
 * What counts as the last consolidation is the newest generations row with
 * the purpose consolidate for that person. The gateway writes one for every
 * call whether or not anything came of it, so a night that read the facts
 * and settled nothing is still a night that ran, and the same facts are not
 * read again tomorrow for the same empty answer.
 */

/** How many new facts one run is shown. More than this waits for tomorrow. */
const NEW_FACTS = 40
/** How many older open facts are shown beside them, newest first. */
const HELD_FACTS = 40
/** How many earlier observations are shown so they are not written again. */
const WRITTEN = 20
/** The most a run writes for one person, whatever the model returns. */
const MAX_OBSERVATIONS = 3

type FactRow = {
  id: string
  subject: string
  predicate: string
  object: string
  sentence: string
  entryIds: string[]
  validFrom: Date
}

type Numbered = FactRow & { number: number }

const factColumns = {
  id: facts.id,
  subject: facts.subject,
  predicate: facts.predicate,
  object: facts.object,
  sentence: facts.sentence,
  entryIds: facts.entryIds,
  validFrom: facts.validFrom,
}

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase()
}

/**
 * Everybody with a tier 0 fact learned since their last consolidation, or
 * ever, when they have never had one. One query across all students, the
 * way the sweep finds themes, and then one person at a time.
 */
async function peopleWithNewFacts(): Promise<Session[]> {
  const rows = await sql<{ student_id: string; school_id: string; district_id: string }[]>`
    select f.student_id, f.school_id, f.district_id
    from facts f
    where f.tier = 0
      and f.valid_to is null
      and f.retired_at is null
      and f.learned_at > coalesce(
        (select max(g.created_at) from generations g
         where g.student_id = f.student_id and g.purpose = 'consolidate'),
        to_timestamp(0))
    group by f.student_id, f.school_id, f.district_id
    order by f.student_id`

  return rows.map((r) => ({
    studentId: r.student_id,
    schoolId: r.school_id,
    districtId: r.district_id,
  }))
}

/**
 * Every person who has something new, one at a time.
 *
 * A person whose run fails is left alone and picked up tomorrow, because
 * their last consolidation is still the one before and the facts are still
 * new. One person's failure is not allowed to end the night for everybody
 * else, which is why the loop catches rather than throws.
 */
export async function consolidateAll(): Promise<{ people: number; written: number }> {
  const people = await peopleWithNewFacts()
  let written = 0

  for (const session of people) {
    try {
      written += await consolidate(session)
    } catch (error) {
      console.error(`consolidation failed for ${session.studentId}: ${(error as Error).message}`)
    }
  }

  return { people: people.length, written }
}

/**
 * One person, one call, at most three rows.
 *
 * The model is shown three numbered lists and answers with numbers. The
 * numbers are turned back into fact ids here, and an observation whose
 * numbers point at facts that were not sent, or at fewer than two, is
 * dropped rather than written with nothing behind it.
 */
export async function consolidate(session: Session): Promise<number> {
  /**
   * The gate, in front of the call, as it is in front of every outbound call.
   * A person with no consent has no facts, because their entries were held
   * before the tagger, so they cannot reach here. Checked anyway.
   */
  if (!(await checkConsent(session, 'third_party_processing'))) return 0

  const open = and(
    eq(facts.studentId, session.studentId),
    isNull(facts.validTo),
    isNull(facts.retiredAt),
  )

  // As text, because dates are not parsed on this connection and a raw
  // aggregate is not mapped by the schema. It goes back in as text too.
  const since = await sql<{ at: string | null }[]>`
    select max(created_at)::text as at
    from generations
    where student_id = ${session.studentId} and purpose = 'consolidate'`.then(
    (rows) => rows[0]?.at ?? null,
  )

  const fresh = await db
    .select(factColumns)
    .from(facts)
    .where(
      since
        ? and(open, eq(facts.tier, 0), raw`${facts.learnedAt} > ${since}::timestamptz`)
        : and(open, eq(facts.tier, 0)),
    )
    .orderBy(asc(facts.validFrom))
    .limit(NEW_FACTS)

  // Booked for somebody whose new facts closed between the query and now.
  if (!fresh.length) return 0

  const freshIds = fresh.map((f) => f.id)

  const [held, writtenBefore] = await Promise.all([
    db
      .select(factColumns)
      .from(facts)
      .where(
        and(open, eq(facts.tier, 0), notInArray(facts.id, freshIds)),
      )
      .orderBy(desc(facts.validFrom))
      .limit(HELD_FACTS)
      .then((rows) => rows.reverse()),
    db
      .select(factColumns)
      .from(facts)
      .where(and(open, eq(facts.tier, 1)))
      .orderBy(desc(facts.validFrom))
      .limit(WRITTEN),
  ])

  // One numbering across the two lists the model may draw from, new first,
  // so a number means one fact whichever list it was read in.
  let n = 0
  const numbered: Numbered[] = [...fresh, ...held].map((f) => ({ ...f, number: ++n }))
  const byNumber = new Map(numbered.map((f) => [f.number, f]))
  const freshNumbers = new Set(numbered.slice(0, fresh.length).map((f) => f.number))

  const result = await call('consolidate', {
    user: renderFacts(numbered.slice(0, fresh.length), numbered.slice(fresh.length), writtenBefore),
    schema: consolidateResult,
    session,
  })

  let written = 0

  for (const found of result.value.observations.slice(0, MAX_OBSERVATIONS)) {
    const sources = [...new Set(found.drawnFrom)]
      .map((number) => byNumber.get(number))
      .filter((f): f is Numbered => f !== undefined)

    // At least two facts, and at least one of them new tonight. An
    // observation that stands on nothing new is one that could have been
    // written last night and was not, or was and is in the written list.
    if (sources.length < 2 || !sources.some((f) => freshNumbers.has(f.number))) continue

    const entryIds = [...new Set(sources.flatMap((f) => f.entryIds))]
    const validFrom = sources
      .map((f) => f.validFrom)
      .reduce((a, b) => (a < b ? a : b))

    const openSame = writtenBefore.filter(
      (w) => same(w.subject, found.subject) && same(w.predicate, found.predicate),
    )

    // Said again, at this tier. The entries join the observation that already
    // holds and nothing else is written, the same rule a tier 0 fact follows.
    const repeat = openSame.find((w) => same(w.object, found.object))
    if (repeat) {
      const merged = [...new Set([...repeat.entryIds, ...entryIds])]
      if (merged.length !== repeat.entryIds.length) {
        await db.update(facts).set({ entryIds: merged }).where(eq(facts.id, repeat.id))
      }
      continue
    }

    // Turned over. An earlier observation with the same subject and
    // predicate stops holding when this one starts. Only tier 1 closes tier
    // 1: a tier 0 fact is what somebody said and an observation across
    // several does not get to close it.
    if (openSame.length) {
      await db
        .update(facts)
        .set({ validTo: validFrom })
        .where(and(inArray(facts.id, openSame.map((w) => w.id)), isNull(facts.validTo)))
    }

    const vector = await embedding(found.sentence, session)

    await db.insert(facts).values({
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      subject: found.subject,
      predicate: found.predicate,
      object: found.object,
      sentence: found.sentence,
      entryIds,
      validFrom,
      confidence: found.confidence,
      tier: 1,
      embedding: vector,
    })

    written += 1
  }

  return written
}

function renderList(rows: Numbered[]): string {
  if (!rows.length) return '  none'
  return rows
    .map((f) => `  ${f.number}. [since ${f.validFrom.toDateString()}] ${f.sentence}`)
    .join('\n')
}

/**
 * What the model is shown. Three lists, their words, their dates. The
 * written list is not numbered because nothing is drawn from it; it is there
 * so the same observation is not written twice.
 */
export function renderFacts(fresh: Numbered[], held: Numbered[], written: FactRow[]): string {
  const earlier = written.length
    ? written.map((w) => `  [since ${w.validFrom.toDateString()}] ${w.sentence}`).join('\n')
    : '  none'

  return ['new:', renderList(fresh), '', 'held:', renderList(held), '', 'written:', earlier].join(
    '\n',
  )
}

/**
 * The vector for an observation, or null when it could not be had. Logged
 * rather than thrown, for the same reason as a tier 0 fact: the row is the
 * record and the vector is one of two ways to find it.
 */
async function embedding(sentence: string, session: Session): Promise<number[] | null> {
  try {
    const result = await embed({ text: sentence, session })
    return result.vector
  } catch (error) {
    console.warn(`observation not embedded: ${(error as Error).message}`)
    return null
  }
}

if (process.argv[1]?.endsWith('consolidate.ts')) {
  consolidateAll()
    .then(({ people, written }) => {
      console.log(`${people} people read, ${written} observations written`)
      process.exit(0)
    })
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
}
