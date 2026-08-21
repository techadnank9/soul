import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT, MIN_TAG_CONFIDENCE } from './rules.js'

/**
 * Patterns. What is doing this student good, what is costing them, and what is
 * still only a thing that keeps returning.
 *
 * This screen used to refuse to judge. It listed what came back and what the
 * student's own outcomes had said about it, under headings written so that
 * neither list could be read as a result. It says which is which now, in a
 * sentence, and it tells them to keep one and stop the other. That is a
 * founder decision taken on purpose against the earlier clinical guidance and
 * it is written up in CONTEXT.md and in DECISIONS.md. Do not hedge it back.
 *
 * What did not change: nothing here is scored, nothing is a diagnosis, nothing
 * names what kind of person they are, and nothing praises them for a sticker.
 *
 * Two things decide a section, in this order.
 *
 * The student's own outcomes. A theme whose check backs they answered lighter
 * is good, one they answered worse is bad, and their answer beats ours every
 * time. The row says source outcomes.
 *
 * Where they have not answered, the model judged it in the night and the row
 * says source model. A theme with neither is in neither section and is still
 * just a thing that keeps returning.
 *
 * The wire shape is the type below rather than `patternsView` in contracts.ts.
 * That schema still describes the old lighter and heavier screen and is stale.
 */
export type PatternSection = {
  theme: string
  times: number
  lastAt: string
  line: string
  source: 'outcomes' | 'model'
}

export type PatternsView = {
  reflections: number
  good: PatternSection[]
  bad: PatternSection[]
  forming: { id: string; theme: string; supporting: number }[]
}

type SectionRow = PatternSection & { verdict: 'good' | 'bad' }
type FormingRow = { id: string; theme: string; supporting: number }

export async function patterns(session: Session): Promise<PatternsView> {
  return asStudent(session, async (tx) => {
    const counted = await tx<{ reflections: number }[]>`
      select count(*)::int as "reflections"
      from entries
      where student_id = ${session.studentId}`

    /**
     * One row per theme that has a verdict, with the sentence under it.
     *
     * `times` is how many entries are behind the theme and `lastAt` is the
     * most recent of them, and they mean the same thing in both sections
     * whichever decided it. They used to be a count of outcomes, which was
     * right while the two lists were a record of what the student had
     * answered and is wrong now that one of them can be filled by us: two rows
     * side by side counting different things is a screen that lies quietly.
     *
     * The line is only ever read off a row written for the verdict now
     * showing. A theme whose outcomes have turned over since we wrote about it
     * is held out of both sections until the next verdict run writes the new
     * sentence, because the one failure worth avoiding here is a line that
     * says keep going sitting under a heading that says this is costing you.
     */
    const sections = await tx<SectionRow[]>`
      with tagged as (
        /**
         * The newest tag wins, as it does on the day view. An entry the
         * tagger has run over twice has two rows, and counting both puts a
         * theme the tagger has already replaced beside the one that replaced
         * it.
         */
        select e.id as entry_id, e.created_at, t.trigger as theme
        from entries e
        join lateral (
          select trigger
          from tags
          where entry_id = e.id
            and trigger is not null
            and confidence >= ${MIN_TAG_CONFIDENCE}
          order by created_at desc
          limit 1
        ) t on true
        where e.student_id = ${session.studentId}
      ),

      behind as (
        select theme, count(*)::int as times, max(created_at) as last_at
        from tagged
        group by theme
      ),

      /**
       * What the student said afterwards, turned into one verdict per theme.
       *
       * Counted on the decision, so a student who answered the same check
       * back twice has had one occasion. A theme they answered both ways gets
       * the answer they gave more often, and the more recent one when the
       * count is level, because two sections that say keep this and stop this
       * cannot both hold the same theme.
       */
      felt as (
        select
          tg.theme,
          case
            when count(distinct d.id) filter (where o.felt = 'lighter')
               > count(distinct d.id) filter (where o.felt = 'worse') then 'good'
            when count(distinct d.id) filter (where o.felt = 'worse')
               > count(distinct d.id) filter (where o.felt = 'lighter') then 'bad'
            when coalesce(
                   max(coalesce(o.responded_at, o.created_at))
                     filter (where o.felt = 'lighter'), to_timestamp(0))
               >= coalesce(
                   max(coalesce(o.responded_at, o.created_at))
                     filter (where o.felt = 'worse'), to_timestamp(0)) then 'good'
            else 'bad'
          end as verdict
        from outcomes o
        join decisions d on d.id = o.decision_id
        join tagged tg on tg.entry_id = d.entry_id
        where o.student_id = ${session.studentId}
          and o.felt in ('lighter', 'worse')
        group by tg.theme
      ),

      /** The live verdict for a theme is the newest row written for it. */
      live as (
        select distinct on (theme)
          theme, verdict::text as verdict, line
        from pattern_verdicts
        where student_id = ${session.studentId}
        order by theme, created_at desc
      )

      select
        b.theme,
        b.times,
        to_char(b.last_at at time zone 'UTC', ${ISO_INSTANT}) as "lastAt",
        v.line,
        case when f.theme is null then 'model' else 'outcomes' end as "source",
        coalesce(f.verdict, v.verdict) as "verdict"
      from behind b
      join live v on v.theme = b.theme
      left join felt f on f.theme = b.theme
      -- The stored sentence was written for the verdict now showing, or the
      -- theme waits. This is the whole of how a later outcome overrides us.
      -- Unsettled is stored and never shown, so it is refused on both sides:
      -- as the verdict on the row, and as the reason a theme with an outcome
      -- verdict is still waiting for a sentence.
      where v.verdict in ('good', 'bad')
        and v.verdict = coalesce(f.verdict, v.verdict)
      order by b.last_at desc`

    /**
     * Everything that keeps returning and has not been judged.
     *
     * A candidate whose theme is already in a section is left out of here. It
     * would otherwise sit under not enough to say yet on the same screen as
     * the sentence telling the student to stop it, which is the app
     * contradicting itself in two places a thumb apart. The row is untouched
     * and the student can still be asked to confirm or reject it wherever
     * candidates are surfaced.
     */
    const forming = await tx<FormingRow[]>`
      select
        id,
        theme,
        cardinality(supporting_entry_ids)::int as "supporting"
      from pattern_candidates
      where student_id = ${session.studentId}
        and status in ('pending', 'surfaced')
      order by proposed_at desc`

    const judged = new Set(sections.map((row) => row.theme))

    return {
      // Every entry the student has ever written, not this week's. This number
      // is the one thing on the screen that only goes up.
      reflections: counted[0]?.reflections ?? 0,
      good: withoutVerdict(sections, 'good'),
      bad: withoutVerdict(sections, 'bad'),
      forming: forming.filter((row) => !judged.has(row.theme)),
    }
  })
}

/**
 * The verdict column comes off before the rows go on the wire.
 *
 * Which section a row is in already says it, and sending the word twice
 * invites a screen to print good or bad next to the theme as a label. The
 * sentence is what the student reads, and a label beside it is the closest
 * this screen could get to a score.
 */
function withoutVerdict(rows: SectionRow[], verdict: SectionRow['verdict']): PatternSection[] {
  return rows
    .filter((row) => row.verdict === verdict)
    .map(({ theme, times, lastAt, line, source }) => ({ theme, times, lastAt, line, source }))
}
