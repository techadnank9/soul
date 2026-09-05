import type { TransactionSql } from 'postgres'
import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT, MIN_TAG_CONFIDENCE, studentZone } from './rules.js'
import type { WeekView } from '../../contracts.js'

/**
 * The week screen.
 *
 * Seven days, Monday first, and the themes underneath them. A student who has
 * written nothing gets seven empty days rather than a shorter ring, because
 * the shape of the week is the same on day one as it is in month three.
 */
const THEMES_SHOWN = 4

type HoldingRow = {
  decisionId: string
  chose: string
  horizon: string
}

type DayRow = { date: string; weekday: string; count: number }
type ThemeRow = { name: string; count: number }

export async function week(session: Session): Promise<WeekView> {
  return asStudent(session, async (tx) => {
    const zone = await studentZone(tx, session)
    const monday = await weekStart(tx, zone)

    const days = await tx<DayRow[]>`
      select
        to_char(d, 'YYYY-MM-DD') as "date",
        (array['M', 'T', 'W', 'T', 'F', 'S', 'S'])[extract(isodow from d)::int] as "weekday",
        count(e.id)::int as "count"
      from generate_series(${monday}::date, ${monday}::date + 6, interval '1 day') as d
      left join entries e
        on e.student_id = ${session.studentId}
       and (e.created_at at time zone ${zone})::date = d::date
      group by d
      order by d`

    /**
     * A theme belongs to the week the student wrote in, not the week the
     * tagger ran in. The tagger is async and can finish after midnight, and a
     * feeling that moved itself into the next week would be a theme the
     * student cannot find an entry for.
     */
    const themes = await tx<ThemeRow[]>`
      select t.feeling as "name", count(*)::int as "count"
      from tags t
      join entries e on e.id = t.entry_id
      where t.student_id = ${session.studentId}
        and t.feeling is not null
        and t.confidence >= ${MIN_TAG_CONFIDENCE}
        and (e.created_at at time zone ${zone})::date
            between ${monday}::date and ${monday}::date + 6
      group by t.feeling
      order by "count" desc, t.feeling
      limit ${THEMES_SHOWN}`

    /**
     * The oldest thing they are still holding, once the day they named has
     * arrived.
     *
     * Without this the check back has nowhere to land: the job marks a
     * decision due and no screen in the product ever asks about it, so an
     * outcome is never recorded and the two sections built on outcomes stay
     * empty for good. Home is where a student already is, so home asks.
     *
     * Nothing is shown before the day they chose. Asking early turns a
     * question into a nudge.
     */
    const holding = await tx<HoldingRow[]>`
      select
        d.id as "decisionId",
        d.chosen_text as "chose",
        to_char(d.horizon at time zone 'UTC', ${ISO_INSTANT}) as "horizon"
      from decisions d
      where d.student_id = ${session.studentId}
        and d.status = 'open'
        and d.horizon <= now()
        and not exists (select 1 from outcomes o where o.decision_id = d.id)
      order by d.horizon
      limit 1`

    /**
     * Only while there is nothing of their own to divide. A week with one
     * real theme in it is their week, and the answers stop being shown the
     * moment that happens rather than being blended into it.
     */
    let opening: string | null = null
    let shown: ThemeRow[] = [...themes]
    let themesFromAnswers = false

    if (themes.length === 0) {
      const row = (
        await tx<{ opening: string | null; opening_themes: unknown }[]>`
          select opening, opening_themes from students where id = ${session.studentId}`
      )[0]
      opening = row?.opening ?? null
      const fromAnswers = row?.opening_themes as { name: string; weight: number }[] | null
      if (fromAnswers && fromAnswers.length > 0) {
        shown = fromAnswers.map((t) => ({ name: t.name, count: t.weight }))
        themesFromAnswers = true
      }
    }

    return {
      // The count of the seven days, not a query of its own, so the number
      // above the ring can never disagree with the ring.
      moments: days.reduce((total, day) => total + day.count, 0),
      opening,
      themesFromAnswers,
      themes: shown,
      days,
      holding: holding[0] ?? null,
    }
  })
}

/** Monday of the student's current week, as their own calendar reads it. */
async function weekStart(tx: TransactionSql, zone: string): Promise<string> {
  const rows = await tx<{ monday: string }[]>`
    select to_char(date_trunc('week', now() at time zone ${zone}), 'YYYY-MM-DD') as "monday"`

  const row = rows[0]
  if (!row) throw new Error('week start returned no row')
  return row.monday
}
