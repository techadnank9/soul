import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT, MIN_TAG_CONFIDENCE } from './rules.js'

/**
 * One reflection, opened.
 *
 * The whole reason this endpoint exists: a screen that tells a student to keep
 * something or stop something has to be able to show them where that came
 * from. The entries behind the theme, in their own words, with the dates, and
 * what they decided about it afterwards.
 *
 * It reads the theme, the verdict and the count exactly the way the list does.
 * A row that says good on the list and opens as bad would be worse than not
 * having the screen at all, so both go through the same rules: the newest tag
 * wins per entry, the confidence floor is the same, and the verdict is read
 * off pattern_verdicts.
 */
export type ReflectionEntry = {
  id: string
  at: string
  date: string
  text: string
  feeling: string | null
}

export type ReflectionDecision = {
  chose: string
  felt: 'lighter' | 'same' | 'worse' | null
  at: string
}

export type ReflectionView = {
  theme: string
  verdict: 'good' | 'bad' | 'unsettled'
  line: string
  source: 'outcomes' | 'model'
  times: number
  entries: ReflectionEntry[]
  decisions: ReflectionDecision[]
}

type VerdictRow = {
  verdict: 'good' | 'bad' | 'unsettled'
  line: string
  source: 'outcomes' | 'model'
}

export async function reflection(
  session: Session,
  theme: string,
): Promise<ReflectionView | null> {
  return asStudent(session, async (tx) => {
    /**
     * The entries behind the theme, newest first.
     *
     * Newest first here and earliest first on a day, which is not an
     * inconsistency: a day is being read back in the order it was lived, and
     * this is being asked when did this last happen.
     */
    const entries = await tx<ReflectionEntry[]>`
      select
        e.id,
        to_char(e.created_at at time zone 'UTC', ${ISO_INSTANT}) as "at",
        to_char(e.created_at at time zone coalesce(s.timezone, 'UTC'), 'YYYY-MM-DD') as "date",
        e.text,
        t.feeling
      from entries e
      join students s on s.id = e.student_id
      join lateral (
        select trigger, feeling
        from tags
        where entry_id = e.id
          and trigger is not null
          and confidence >= ${MIN_TAG_CONFIDENCE}
        order by created_at desc
        limit 1
      ) t on true
      where e.student_id = ${session.studentId}
        and t.trigger = ${theme}
      order by e.created_at desc`

    // No entries means this student has no such theme. Not an empty page: a
    // theme they do not have is not theirs to open.
    if (entries.length === 0) return null

    const verdicts = await tx<VerdictRow[]>`
      select verdict::text, line, source::text
      from pattern_verdicts
      where student_id = ${session.studentId}
        and theme = ${theme}
      order by created_at desc
      limit 1`

    /**
     * What they decided about it, and how it went.
     *
     * A decision belongs to this theme when the entry it came from does. It is
     * the other half of the page: the entries say what kept happening and
     * these say what they did about it.
     */
    const decisions = await tx<ReflectionDecision[]>`
      select
        d.chosen_text as "chose",
        o.felt::text as "felt",
        to_char(d.created_at at time zone 'UTC', ${ISO_INSTANT}) as "at"
      from decisions d
      join lateral (
        select trigger
        from tags
        where entry_id = d.entry_id
          and trigger is not null
          and confidence >= ${MIN_TAG_CONFIDENCE}
        order by created_at desc
        limit 1
      ) t on true
      left join outcomes o on o.decision_id = d.id
      where d.student_id = ${session.studentId}
        and t.trigger = ${theme}
      order by d.created_at desc`

    const verdict = verdicts[0]

    return {
      theme,
      // A theme with no verdict row is one that keeps returning and has not
      // been judged either way, which is most of them.
      verdict: verdict?.verdict ?? 'unsettled',
      line: verdict?.line ?? '',
      source: verdict?.source ?? 'model',
      times: entries.length,
      entries,
      decisions,
    }
  })
}
