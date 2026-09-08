import { sql } from '../../db.js'

/**
 * Pattern detection is a SQL query, not a model call.
 *
 * That is deliberate and it is not an optimisation. When the app tells a
 * student this is the third time, we can show exactly which three entries and
 * why. An LLM step would take that away, so do not improve this into one.
 *
 * The threshold: the same theme across at least three entries. Low confidence
 * tags do not count toward it, and anything the student has already rejected
 * is excluded for good.
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
 * The theme is the coping, from the tagger's closed list, and not the
 * trigger. The trigger is free text and no two are ever the same string, so
 * grouping on it put every entry in a group of one and no pattern has ever
 * formed from real writing. Decision 259.
 */
const MIN_ENTRIES = 3
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
    select
      t.student_id      as "studentId",
      t.school_id       as "schoolId",
      t.district_id     as "districtId",
      t.coping          as "theme",
      array_agg(distinct t.entry_id) as "supportingEntryIds"
    from tags t
    where t.coping is not null
      and t.confidence >= ${MIN_CONFIDENCE}
      and (${studentId ?? null}::uuid is null or t.student_id = ${studentId ?? null}::uuid)
      and not exists (
        select 1 from pattern_rejections r
        where r.student_id = t.student_id and r.theme = t.coping
      )
      and not exists (
        select 1 from confirmed_patterns c
        where c.student_id = t.student_id
          and c.theme = t.coping
          and c.removed_at is null
      )
      and not exists (
        select 1 from pattern_candidates p
        where p.student_id = t.student_id
          and p.theme = t.coping
          and p.status in ('pending', 'surfaced')
      )
    group by t.student_id, t.school_id, t.district_id, t.coping
    having count(distinct t.entry_id) >= ${MIN_ENTRIES}`
}
