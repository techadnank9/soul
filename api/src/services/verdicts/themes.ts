import { sql } from '../../db.js'

/**
 * Which themes need a verdict written, and what the student's own answers
 * already say about them.
 *
 * The product used to stop at what keeps returning. It now says which of the
 * things that keep returning are doing a student good and which are costing
 * them, and this query is the front of that. It reads across every student in
 * one pass, the way the nightly pattern sweep does, so it has no session and
 * no student to scope to.
 *
 * Two rules live here and nowhere else.
 *
 * The student decides first. A theme they have already answered about, by
 * saying a check back left them lighter or worse, has its verdict set by that
 * answer. The model is still asked, but it is told the verdict and writes only
 * the line, so what comes back can never contradict them.
 *
 * Two entries, not three. The nightly sweep needs three entries on three days
 * before it will propose a pattern to a student, because that is a claim it
 * asks them to confirm. This is a smaller thing: it decides whether a theme
 * already on their screen is worth a sentence. Below two there is nothing
 * repeating to have a verdict about.
 */
const MIN_SUPPORTING = 2
const MIN_CONFIDENCE = 0.6

/**
 * How many themes one run will pay for.
 *
 * A model call per theme per student, and the run happens unattended in the
 * night. The cap is what stops a tagger change that renames every theme at
 * once from turning into one call for every theme in the database. What does
 * not fit waits for tomorrow, and the ones with no verdict at all go first.
 */
const MAX_PER_RUN = 200

export type ThemeNeedingVerdict = {
  studentId: string
  schoolId: string
  districtId: string
  theme: string
  supporting: number
  /** Set when the student's own outcomes have already answered. */
  studentVerdict: 'good' | 'bad' | null
}

/**
 * Everything the model is shown about one theme, in the student's own words.
 *
 * Entries oldest first, because a theme is a thing that happened repeatedly
 * and the order it happened in is half of what there is to read.
 */
export type ThemeEvidence = {
  entries: { at: string; text: string }[]
  outcomes: { chose: string; whatHappened: string | null; felt: string }[]
}

/**
 * The newest tag per entry, above the floor the whole read side uses.
 *
 * An entry the tagger has run over twice has two rows, and counting both puts
 * a theme the tagger has already replaced beside the one that replaced it.
 */
const TAGGED = sql`
  select
    e.id as entry_id,
    e.student_id,
    e.school_id,
    e.district_id,
    e.text,
    e.created_at,
    t.trigger as theme
  from entries e
  join lateral (
    select trigger
    from tags
    where entry_id = e.id
      and trigger is not null
      and confidence >= ${MIN_CONFIDENCE}
    order by created_at desc
    limit 1
  ) t on true`

export async function themesNeedingVerdict(): Promise<ThemeNeedingVerdict[]> {
  return sql<ThemeNeedingVerdict[]>`
    with tagged as (${TAGGED}),

    themes as (
      select student_id, school_id, district_id, theme,
             count(*)::int as supporting
      from tagged
      group by 1, 2, 3, 4
      having count(*) >= ${MIN_SUPPORTING}
    ),

    /**
     * What the student said afterwards, per theme.
     *
     * The same join the patterns read does: outcomes to the decision to the
     * tag on the entry the decision came from. Counted on the decision, so a
     * student who answered the same check back twice has had one occasion.
     */
    felt as (
      select
        o.student_id,
        tg.theme,
        count(distinct d.id) filter (where o.felt = 'lighter')::int as lighter,
        count(distinct d.id) filter (where o.felt = 'worse')::int   as worse,
        max(coalesce(o.responded_at, o.created_at))
          filter (where o.felt = 'lighter') as lighter_at,
        max(coalesce(o.responded_at, o.created_at))
          filter (where o.felt = 'worse')   as worse_at
      from outcomes o
      join decisions d on d.id = o.decision_id
      join tagged tg on tg.entry_id = d.entry_id
      where o.felt in ('lighter', 'worse')
      group by 1, 2
    ),

    /** The live verdict for a theme is the newest row written for it. */
    latest as (
      select distinct on (student_id, theme)
        student_id, theme, verdict::text as verdict, source::text as source, supporting
      from pattern_verdicts
      order by student_id, theme, created_at desc
    ),

    /**
     * A theme they answered both ways gets the answer they gave more often,
     * and the more recent one when the count is level. The old screen let a
     * theme sit in both lists, which two sections that say keep going and
     * worth stopping cannot do.
     */
    decided as (
      select
        th.student_id  as "studentId",
        th.school_id   as "schoolId",
        th.district_id as "districtId",
        th.theme,
        th.supporting,
        case
          when f.theme is null then null
          when f.lighter > f.worse then 'good'
          when f.worse > f.lighter then 'bad'
          when coalesce(f.lighter_at, to_timestamp(0))
             >= coalesce(f.worse_at, to_timestamp(0)) then 'good'
          else 'bad'
        end as "studentVerdict",
        l.verdict as "storedVerdict",
        l.source  as "storedSource",
        l.supporting as "storedSupporting"
      from themes th
      left join felt f
        on f.student_id = th.student_id and f.theme = th.theme
      left join latest l
        on l.student_id = th.student_id and l.theme = th.theme
    )

    select "studentId", "schoolId", "districtId", theme, supporting, "studentVerdict"
    from decided
    where
      -- Never judged.
      "storedVerdict" is null
      -- The student has spoken since, or spoken differently. Their answer
      -- overrides ours, and the line has to be rewritten to match it rather
      -- than left sitting under the opposite heading.
      or ("studentVerdict" is not null
          and ("storedSource" is distinct from 'outcomes'
               or "storedVerdict" is distinct from "studentVerdict"))
      -- The stored line was written about fewer entries than there are now.
      or "storedSupporting" < supporting
    order by ("storedVerdict" is not null), supporting desc
    limit ${MAX_PER_RUN}`
}

/** The entries and the answers behind one theme, for the model to read. */
export async function evidenceFor(
  studentId: string,
  theme: string,
  limit = 10,
): Promise<ThemeEvidence> {
  const entries = await sql<{ at: string; text: string }[]>`
    with tagged as (${TAGGED})
    select at, text from (
      select to_char(created_at at time zone 'UTC', 'YYYY-MM-DD') as at, text, created_at
      from tagged
      where student_id = ${studentId} and theme = ${theme}
      order by created_at desc
      limit ${limit}
    ) recent
    order by created_at`

  const outcomes = await sql<
    { chose: string; whatHappened: string | null; felt: string }[]
  >`
    with tagged as (${TAGGED})
    select
      d.chosen_text   as "chose",
      o.what_happened as "whatHappened",
      o.felt::text    as "felt"
    from outcomes o
    join decisions d on d.id = o.decision_id
    join tagged tg on tg.entry_id = d.entry_id
    where o.student_id = ${studentId}
      and tg.theme = ${theme}
      and o.felt is not null
    order by coalesce(o.responded_at, o.created_at)`

  return { entries, outcomes }
}
