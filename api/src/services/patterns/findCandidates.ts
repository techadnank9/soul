import { sql } from '../../db.js'

/**
 * Pattern detection is a SQL query, not a model call.
 *
 * That is deliberate and it is not an optimisation. When the app tells a
 * student this is the third time, we can show exactly which three entries and
 * why. An LLM step would take that away, so do not improve this into one.
 *
 * The threshold: the same theme across at least three entries on at least
 * three distinct days. Low confidence tags do not count toward it, and
 * anything the student has already rejected is excluded for good.
 */
const MIN_ENTRIES = 3
const MIN_DAYS = 3
const MIN_CONFIDENCE = 0.6

export type Candidate = {
  studentId: string
  schoolId: string
  districtId: string
  theme: string
  supportingEntryIds: string[]
}

export async function findCandidates(): Promise<Candidate[]> {
  return sql<Candidate[]>`
    select
      t.student_id      as "studentId",
      t.school_id       as "schoolId",
      t.district_id     as "districtId",
      t.trigger         as "theme",
      array_agg(distinct t.entry_id) as "supportingEntryIds"
    from tags t
    where t.trigger is not null
      and t.confidence >= ${MIN_CONFIDENCE}
      and not exists (
        select 1 from pattern_rejections r
        where r.student_id = t.student_id and r.theme = t.trigger
      )
      and not exists (
        select 1 from confirmed_patterns c
        where c.student_id = t.student_id
          and c.theme = t.trigger
          and c.removed_at is null
      )
      and not exists (
        select 1 from pattern_candidates p
        where p.student_id = t.student_id
          and p.theme = t.trigger
          and p.status in ('pending', 'surfaced')
      )
    group by t.student_id, t.school_id, t.district_id, t.trigger
    having count(distinct t.entry_id) >= ${MIN_ENTRIES}
       and count(distinct date_trunc('day', t.created_at)) >= ${MIN_DAYS}`
}
