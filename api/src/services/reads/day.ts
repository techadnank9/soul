import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT, MIN_TAG_CONFIDENCE, studentZone } from './rules.js'
import type { DayView } from '../../contracts.js'

/**
 * One day, in the order it was lived.
 *
 * Earliest first, because this is a day being read back rather than a feed.
 * The date is the student's own, so an entry written late on Sunday in Los
 * Angeles is on Sunday and not on Monday.
 */
type EntryRow = {
  id: string
  at: string
  text: string
  feeling: string | null
  trigger: string | null
}

type CardRow = {
  id: string
  about: string
  question: string
  answered: boolean
}

export async function day(session: Session, date: string): Promise<DayView> {
  return asStudent(session, async (tx) => {
    const zone = await studentZone(tx, session)

    /**
     * The newest tag wins. There is one row per entry today, but a re tagged
     * entry would have two and the later run is the one that saw the current
     * tagger version.
     */
    const rows = await tx<EntryRow[]>`
      select
        e.id,
        to_char(e.created_at at time zone 'UTC', ${ISO_INSTANT}) as "at",
        e.text,
        t.feeling,
        t.trigger
      from entries e
      left join lateral (
        select feeling, trigger
        from tags
        where entry_id = e.id
          and student_id = ${session.studentId}
          and confidence >= ${MIN_TAG_CONFIDENCE}
        order by created_at desc
        limit 1
      ) t on true
      where e.student_id = ${session.studentId}
        and (e.created_at at time zone ${zone})::date = ${date}::date
      order by e.created_at`

    /**
     * A card belongs to the day of the entry it was made from, never the day
     * it was written. The generation job runs after the tagger, so a card for
     * an entry written late at night can be made after midnight, and bounding
     * on the card would put it on a day with nothing behind it. Same rule as
     * the themes on the week.
     *
     * Unanswered first, and the ones already answered stay on the day so a
     * student can see what they were asked and what they said. A no stays for
     * the same reason a yes does. Oldest first inside each group, which is the
     * order the rest of the day reads in.
     *
     * No limit. A day used to return two at most, which was the same number
     * the generation job capped itself at, and the two disagreed: the job
     * counted the cards written on a day and the read counted the cards
     * belonging to the entries of a day, so a card made after midnight for
     * yesterday's entry could sit behind two later ones and never be seen by
     * anybody. Both bounds are gone. A card exists because something was open
     * and worth a sentence back, and a day shows the ones it has.
     */
    const cards = await tx<CardRow[]>`
      select
        c.id,
        c.about,
        c.question,
        (c.answered_at is not null) as "answered"
      from cue_cards c
      join entries e on e.id = c.entry_id
      where c.student_id = ${session.studentId}
        and (e.created_at at time zone ${zone})::date = ${date}::date
      order by (c.answered_at is not null), c.created_at`

    return { date, entries: rows, cards }
  })
}
