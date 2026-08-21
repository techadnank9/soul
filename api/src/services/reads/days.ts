import { asStudent, type Session } from '../../session.js'
import { studentZone } from './rules.js'
import type { DayCount } from '../../contracts.js'

/**
 * The days a student has written on, newest first.
 *
 * Only days with something in them. An unbroken calendar with empty rows in it
 * reads as a record of what somebody failed to do, and nothing in this product
 * keeps score.
 *
 * The feelings are carried so a day can be recognised before it is opened. It
 * is the same colour language the week ring uses, on the same tags.
 */
const DAYS_SHOWN = 60

type Row = {
  date: string
  weekday: string
  count: number
  feelings: string[]
}

export async function days(session: Session): Promise<DayCount[]> {
  return asStudent(session, async (tx) => {
    const zone = await studentZone(tx, session)

    const rows = await tx<Row[]>`
      select
        to_char(local.day, 'YYYY-MM-DD') as "date",
        (array['M', 'T', 'W', 'T', 'F', 'S', 'S'])[extract(isodow from local.day)::int]
          as "weekday",
        count(*)::int as "count",
        coalesce(
          array_agg(distinct local.feeling) filter (where local.feeling is not null),
          '{}'
        ) as "feelings"
      from (
        select
          (e.created_at at time zone ${zone})::date as day,
          t.feeling as feeling
        from entries e
        left join tags t on t.entry_id = e.id
        where e.student_id = ${session.studentId}
      ) as local
      group by local.day
      order by local.day desc
      limit ${DAYS_SHOWN}`

    return rows
  })
}
