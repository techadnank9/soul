import { sql } from '../../db.js'

/**
 * Pattern detection is a SQL query, not a model call.
 *
 * That is deliberate and it is not an optimisation. When the app tells a
 * student this is the third time, we can show exactly which three entries and
 * why. An LLM step would take that away, so do not improve this into one.
 *
 * The threshold: the same theme across at least two entries. Low confidence
 * tags do not count toward it, and anything the student has already rejected
 * is excluded for good.

 * It was three until decision 289. The count was never the thing protecting
 * anybody: the student's own yes, no or not sure is, and a third entry is a
 * worse test of whether something is true about their life than asking them
 * is. What three bought was fewer questions, and it charged a month of
 * writing for them.
 *
 * It used to also require three distinct calendar days. That is gone, on the
 * founder's call, and he is right about it. Midnight is not a real boundary:
 * eleven at night and one in the morning are two days and one evening, while
 * two separate arguments on the same afternoon are two occasions the rule
 * threw one of away. It also made how fast anybody is told anything depend on
 * how often they happen to write rather than on how much is repeating in
 * their life, so somebody writing twice a day still waited three days.
 *
 * What is left is the count, which is the honest measure: the more somebody
 * writes, the more the same thing shows up, the sooner it is offered back.
 * Decision 258.
 *
 * The theme is a word from one of the tagger's two closed lists, and not the
 * trigger. The trigger is free text and no two are ever the same string, so
 * grouping on it put every entry in a group of one and no pattern has ever
 * formed from real writing. Decision 259.
 *
 * Since decision 291 there are two lists, not one, and the query counts both
 * the same way. `coping` is what they did and `meaning` is what they took it
 * to mean, and the second is where the patterns worth showing somebody
 * usually are: avoiding three different things is a habit, and reading three
 * different silences as your own fault is something a person could act on.
 * A theme is one word from one of the two, and the two vocabularies share no
 * words, so the theme alone says which list it came from and the row needs
 * no second column to say so.
 */
const MIN_ENTRIES = 2
const MIN_CONFIDENCE = 0.6

export type Candidate = {
  studentId: string
  schoolId: string
  districtId: string
  theme: string
  supportingEntryIds: string[]
}

/**
 * Every student, or one of them.
 *
 * The nightly run passes nothing and reads everybody. The run booked by the
 * tagger passes the person whose entry just landed, so a theme that has just
 * become a theme is offered back on the same evening rather than after the
 * next three in the morning. Same query either way, so the two can never
 * disagree about what a pattern is.
 */
export async function findCandidates(studentId?: string): Promise<Candidate[]> {
  return sql<Candidate[]>`
    with themed as (
      select
        t.student_id,
        t.school_id,
        t.district_id,
        t.entry_id,
        k.theme
      from tags t
      cross join lateral (values (t.coping), (t.meaning)) as k(theme)
      where k.theme is not null
        and t.confidence >= ${MIN_CONFIDENCE}
        and (${studentId ?? null}::uuid is null or t.student_id = ${studentId ?? null}::uuid)
    )
    select
      th.student_id     as "studentId",
      th.school_id      as "schoolId",
      th.district_id    as "districtId",
      th.theme          as "theme",
      array_agg(distinct th.entry_id) as "supportingEntryIds"
    from themed th
    where not exists (
        select 1 from pattern_rejections r
        where r.student_id = th.student_id and r.theme = th.theme
      )
      and not exists (
        select 1 from confirmed_patterns c
        where c.student_id = th.student_id
          and c.theme = th.theme
          and c.removed_at is null
      )
      and not exists (
        select 1 from pattern_candidates p
        where p.student_id = th.student_id
          and p.theme = th.theme
          and p.status in ('pending', 'surfaced')
      )
    group by th.student_id, th.school_id, th.district_id, th.theme
    having count(distinct th.entry_id) >= ${MIN_ENTRIES}`
}
