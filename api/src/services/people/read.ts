import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT } from '../reads/rules.js'
import { mergeWithin } from './merge.js'
import { enqueue } from '../../jobs/enqueue.js'

/**
 * The people a student writes about, read back to them.
 *
 * Everything here is scoped to the session student inside the row level
 * security role. A person belonging to somebody else is not found rather than
 * forbidden, because a 403 tells a stranger the id exists.
 */
export type PersonRow = {
  id: string
  name: string
  relation: string | null
  mentions: number
  lastAt: string | null
}

export type PersonMention = {
  entryId: string
  at: string
  text: string
}

export type PersonView = PersonRow & {
  profile: string | null
  reach: string | null
  mentions: number
  said: PersonMention[]
}

export async function listPeople(session: Session): Promise<PersonRow[]> {
  return asStudent(session, async (tx) => {
    return tx<PersonRow[]>`
      select
        id,
        name,
        relation,
        mentions,
        to_char(last_seen_at at time zone 'UTC', ${ISO_INSTANT}) as "lastAt"
      from people
      where student_id = ${session.studentId}
      order by last_seen_at desc nulls last, name`
  })
}

export async function readPerson(
  session: Session,
  personId: string,
): Promise<PersonView | null> {
  return asStudent(session, async (tx) => {
    const rows = await tx<(PersonRow & { profile: string | null; reach: string | null })[]>`
      select
        id,
        name,
        relation,
        profile,
        reach,
        mentions,
        to_char(last_seen_at at time zone 'UTC', ${ISO_INSTANT}) as "lastAt"
      from people
      where id = ${personId}
        and student_id = ${session.studentId}
      limit 1`

    const person = rows[0]
    if (!person) return null

    /**
     * The whole entry, not the sentence.
     *
     * The extraction keeps the sentence somebody was named in, which is what
     * the profile is written from. What the student reads back is the entry
     * they wrote, because a sentence of their own words lifted out of the
     * thing they were saying reads like evidence.
     */
    const said = await tx<PersonMention[]>`
      select
        e.id as "entryId",
        to_char(e.created_at at time zone 'UTC', ${ISO_INSTANT}) as "at",
        e.text
      from entry_people ep
      join entries e on e.id = ep.entry_id
      where ep.person_id = ${personId}
        and ep.student_id = ${session.studentId}
      order by e.created_at desc`

    return { ...person, said }
  })
}

/**
 * Their words win. A field they set is marked as theirs and never rewritten.
 *
 * A rename onto a name they already have, matched the way the extractor
 * matches, is the student saying two rows are one person. The renamed row is
 * merged into the one that already carries the name, and the id that comes
 * back is the survivor's, so the caller knows which row to show next.
 *
 * Returns the id of the row that holds the edit, or null when the person is
 * not theirs.
 */
export async function editPerson(
  session: Session,
  personId: string,
  input: { name?: string; relation?: string; reach?: string },
): Promise<string | null> {
  const result = await asStudent(session, async (tx) => {
    let target = personId
    let merged = false

    if (input.name !== undefined) {
      const same = await tx<{ id: string }[]>`
        select id from people
        where student_id = ${session.studentId}
          and lower(name) = lower(${input.name})
          and id <> ${personId}
        limit 1`

      const survivor = same[0]?.id
      if (survivor) {
        merged = await mergeWithin(tx, session, survivor, personId)
        if (!merged) return null
        target = survivor
      }
    }

    const rows = await tx<{ id: string }[]>`
      update people
      set name = coalesce(${input.name ?? null}, name),
          name_is_theirs = name_is_theirs or ${input.name !== undefined},
          relation = case
            when ${input.relation !== undefined} then ${input.relation ?? null}
            else relation
          end,
          relation_is_theirs = relation_is_theirs or ${input.relation !== undefined},
          reach = case
            when ${input.reach !== undefined} then ${input.reach ?? null}
            else reach
          end,
          reach_is_theirs = reach_is_theirs or ${input.reach !== undefined}
      where id = ${target}
        and student_id = ${session.studentId}
      returning id`

    const id = rows[0]?.id ?? null
    return id ? { id, merged } : null
  })

  if (result?.merged) await enqueue('person_profile', { personId: result.id }, session)

  return result?.id ?? null
}

/**
 * Removes the person and the links, and never the entries.
 *
 * A student who no longer wants somebody listed is not asking to lose what
 * they wrote. The words stay theirs; only the record we assembled about
 * somebody else goes.
 */
export async function forgetPerson(
  session: Session,
  personId: string,
): Promise<boolean> {
  return asStudent(session, async (tx) => {
    const rows = await tx<{ id: string }[]>`
      select id from people
      where id = ${personId} and student_id = ${session.studentId}
      limit 1`

    if (rows.length === 0) return false

    await tx`
      delete from entry_people
      where person_id = ${personId} and student_id = ${session.studentId}`
    await tx`
      delete from people
      where id = ${personId} and student_id = ${session.studentId}`

    // Districts have inspection rights. The row says a record about somebody
    // was removed, and nothing about who they were.
    await tx`
      insert into audit_log (actor_id, actor_role, action, subject_student_id, subject_type, subject_id)
      values (${session.studentId}, 'student', 'person_forgotten', ${session.studentId}, 'person', ${personId})`

    return true
  })
}
