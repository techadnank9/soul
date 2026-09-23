import { sql } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * What the app holds about somebody, in one list, for them to read.
 *
 * Every row is a fact in their own register with the moments behind it, and
 * every one can be reworded or dropped from here. That is the point: a
 * memory nobody can open is a memory nobody can correct, and this product
 * only works if what it holds is what the person would say themselves.
 *
 * Open facts only. A fact that was contradicted is closed with `valid_to`
 * and a fact the person dropped is retired, and neither is something the app
 * still believes, so neither is shown here.
 */
export type HeldFact = {
  id: string
  sentence: string
  subject: string
  predicate: string
  object: string
  since: string
  moments: { entryId: string; at: string; said: string }[]
}

const SAID = 140

export async function heldFacts(session: Session): Promise<HeldFact[]> {
  const rows = await sql<
    {
      id: string
      sentence: string
      subject: string
      predicate: string
      object: string
      since: Date
      moments: { entryId: string; at: string; said: string }[] | null
    }[]
  >`
    select
      f.id,
      f.sentence,
      f.subject,
      f.predicate,
      f.object,
      f.valid_from as since,
      (
        select coalesce(
          json_agg(
            json_build_object(
              'entryId', e.id,
              'at', e.created_at,
              'said', left(e.text, ${SAID})
            )
            order by e.created_at
          ),
          '[]'::json
        )
        from entries e
        where e.id = any(f.entry_ids) and e.student_id = f.student_id
      ) as moments
    from facts f
    where f.student_id = ${session.studentId}::uuid
      and f.valid_to is null
      and f.retired_at is null
    order by f.valid_from desc`

  return rows.map((row) => ({
    id: row.id,
    sentence: row.sentence,
    subject: row.subject,
    predicate: row.predicate,
    object: row.object,
    since: new Date(row.since).toISOString(),
    moments: row.moments ?? [],
  }))
}

/**
 * Their words over ours.
 *
 * The sentence is the only part a person edits. Subject, predicate and
 * object are what the counting and the contradiction check run on, and
 * letting those be typed over would put free text back where the closed
 * shape has to be. What a person reads, and what the Mirror is told, is the
 * sentence, so rewording it changes what the app says about them, which is
 * the whole of what they were asking for.
 */
export async function rewordFact(
  session: Session,
  factId: string,
  sentence: string,
): Promise<void> {
  const said = sentence.trim()
  if (!said) throw new Error('a fact cannot be emptied, only dropped')

  const done = await sql`
    update facts
    set sentence = ${said}
    where id = ${factId}::uuid
      and student_id = ${session.studentId}::uuid
      and retired_at is null`

  if (done.count === 0) throw new Error('fact not found')
}

/**
 * Dropped by the person it is about.
 *
 * Retired rather than deleted, which is what the memory layer already means
 * by a fact the system stopped trusting. Nothing loads it again. The moments
 * behind it are untouched: they said this, they simply do not want it held
 * as a thing that is true about them.
 */
export async function dropFact(session: Session, factId: string): Promise<void> {
  const done = await sql`
    update facts
    set retired_at = now()
    where id = ${factId}::uuid
      and student_id = ${session.studentId}::uuid
      and retired_at is null`

  if (done.count === 0) throw new Error('fact not found')
}
