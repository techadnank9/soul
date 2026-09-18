import { db, weekNotes, sql } from '../../db.js'
import { call } from '../../gateway/call.js'
import { checkConsent } from '../../consent/gate.js'
import { weekNotesResult } from './schema.js'
import type { Session } from '../../session.js'

/**
 * The week as three sentences, on home all week. Decision 279.
 *
 * Runs nightly from the runner. Each run finds the people whose Sunday has
 * just ended in their own timezone (it is Sunday after six in the evening
 * or Monday before three in the morning where they are), who wrote at
 * least once in the week that ended, and who have no row for it yet. One
 * model call each, consent gate first, and a failure for one person is
 * logged and does not end the run for the rest.
 */
type Ending = {
  studentId: string
  schoolId: string
  districtId: string
  weekStart: string
}

export async function writeWeekNotes(): Promise<{ people: number; written: number }> {
  const ending = await sql<Ending[]>`
    with local as (
      select
        s.id as student_id, s.school_id, s.district_id,
        (now() at time zone coalesce(s.timezone, 'UTC')) as t
      from students s
    ),
    due as (
      select
        student_id, school_id, district_id,
        case
          when extract(isodow from t) = 7 and extract(hour from t) >= 18 then (t::date - 6)
          when extract(isodow from t) = 1 and extract(hour from t) < 3 then (t::date - 7)
        end as week_start
      from local
    )
    select
      d.student_id as "studentId", d.school_id as "schoolId", d.district_id as "districtId",
      to_char(d.week_start, 'YYYY-MM-DD') as "weekStart"
    from due d
    where d.week_start is not null
      and not exists (
        select 1 from week_notes w where w.student_id = d.student_id and w.week_start = d.week_start
      )
      and exists (
        select 1 from entries e
        join students s on s.id = e.student_id
        where e.student_id = d.student_id and e.processed
          and (e.created_at at time zone coalesce(s.timezone, 'UTC'))::date
              between d.week_start and d.week_start + 6
      )`

  let written = 0
  for (const person of ending) {
    try {
      if (await writeOne(person)) written += 1
    } catch (error) {
      console.error(`week notes failed for ${person.studentId}: ${(error as Error).message}`)
    }
  }
  return { people: ending.length, written }
}

async function writeOne(person: Ending): Promise<boolean> {
  const session: Session = {
    studentId: person.studentId,
    schoolId: person.schoolId,
    districtId: person.districtId,
  }
  if (!(await checkConsent(session, 'third_party_processing'))) return false

  const entries = await sql<{ at: string; text: string }[]>`
    select to_char(e.created_at at time zone coalesce(s.timezone, 'UTC'), 'Dy DD Mon') as at, e.text
    from entries e
    join students s on s.id = e.student_id
    where e.student_id = ${person.studentId} and e.processed
      and (e.created_at at time zone coalesce(s.timezone, 'UTC'))::date
          between ${person.weekStart}::date and ${person.weekStart}::date + 6
    order by e.created_at`
  if (entries.length === 0) return false

  const outcomes = await sql<{ chose: string; felt: string | null; happened: string | null }[]>`
    select d.chosen_text as chose, o.felt::text as felt, o.what_happened as happened
    from outcomes o
    join decisions d on d.id = o.decision_id
    where o.student_id = ${person.studentId}
      and coalesce(o.responded_at, o.created_at) >= ${person.weekStart}::date
      and coalesce(o.responded_at, o.created_at) < ${person.weekStart}::date + 7
    order by coalesce(o.responded_at, o.created_at)`

  const said = entries.map((e, i) => `${i + 1}. ${e.at}\n${e.text}`).join('\n\n')
  const went = outcomes.length
    ? outcomes
        .map((o) => `they did: ${o.chose}${o.happened ? `\nthey said: ${o.happened}` : ''}\nit left them: ${o.felt ?? 'not said'}`)
        .join('\n\n')
    : 'none.'

  const result = await call('week_notes', {
    user: ['entries this week, oldest first:', said, '', 'how things went, when they said:', went].join('\n'),
    schema: weekNotesResult,
    session,
  })

  await db
    .insert(weekNotes)
    .values({
      studentId: person.studentId,
      schoolId: person.schoolId,
      districtId: person.districtId,
      weekStart: person.weekStart,
      lines: result.value.lines,
      moments: entries.length,
      promptVersion: result.promptVersion,
      modelVersion: result.model,
    })
    .onConflictDoNothing()
  return true
}
