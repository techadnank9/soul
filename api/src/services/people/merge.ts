import type { TransactionSql } from 'postgres'
import { asStudent, type Session } from '../../session.js'
import { enqueue } from '../../jobs/enqueue.js'

/**
 * Two rows that turn out to be one person.
 *
 * The extractor matches on the name the student used and nothing else, so
 * Mum and my mother are two rows until the student says otherwise. This is
 * where they say otherwise. One row stays, the other goes, and every mention
 * of the one that goes now points at the one that stays.
 *
 * Everything runs as the student under row level security. Both rows have
 * to be theirs, or nothing happens and nothing is said about why.
 */
export async function mergePeople(
  session: Session,
  keepId: string,
  goneId: string,
): Promise<string | null> {
  const merged = await asStudent(session, (tx) => mergeWithin(tx, session, keepId, goneId))

  // Booked after the commit, so a runner that picks it up straight away
  // finds the recounted row rather than the one mid merge.
  if (merged) await enqueue('person_profile', { personId: keepId }, session)

  return merged ? keepId : null
}

/**
 * The merge itself, inside a transaction somebody else opened.
 *
 * Returns whether it happened. The caller books the profile job after the
 * commit, because a job row is written by the service role and a queue that
 * runs before this transaction lands would profile the old row.
 */
export async function mergeWithin(
  tx: TransactionSql,
  session: Session,
  keepId: string,
  goneId: string,
): Promise<boolean> {
  if (keepId === goneId) return false

  const rows = await tx<
    {
      id: string
      relation: string | null
      relationIsTheirs: boolean
      reach: string | null
      reachIsTheirs: boolean
      firstSeenAt: string | null
      lastSeenAt: string | null
    }[]
  >`
    select
      id,
      relation,
      relation_is_theirs as "relationIsTheirs",
      reach,
      reach_is_theirs as "reachIsTheirs",
      first_seen_at as "firstSeenAt",
      last_seen_at as "lastSeenAt"
    from people
    where id in (${keepId}, ${goneId})
      and student_id = ${session.studentId}
    for update`

  const keep = rows.find((r) => r.id === keepId)
  const gone = rows.find((r) => r.id === goneId)
  if (!keep || !gone) return false

  // An entry that already names the kept person keeps that link and loses
  // the other, so the unique index on entry and person is never crossed.
  await tx`
    delete from entry_people
    where person_id = ${goneId}
      and student_id = ${session.studentId}
      and entry_id in (
        select entry_id from entry_people
        where person_id = ${keepId} and student_id = ${session.studentId}
      )`

  await tx`
    update entry_people
    set person_id = ${keepId}
    where person_id = ${goneId}
      and student_id = ${session.studentId}`

  // Their words win. A field they set on the kept row stays. A field they
  // set on the row that goes is carried across only where the kept row has
  // nothing, and it stays marked as theirs when it moves.
  const carryRelation = keep.relation === null && gone.relation !== null
  const carryReach = keep.reach === null && gone.reach !== null

  // The seen window is widened by the other row's, the way one more mention
  // widens it in the extractor. least and greatest ignore a null side.
  await tx`
    update people
    set mentions = (select count(*) from entry_people where person_id = ${keepId}),
        first_seen_at = least(first_seen_at, ${gone.firstSeenAt}::timestamptz),
        last_seen_at = greatest(last_seen_at, ${gone.lastSeenAt}::timestamptz),
        relation = case when ${carryRelation} then ${gone.relation} else relation end,
        relation_is_theirs = case
          when ${carryRelation} then ${gone.relationIsTheirs}
          else relation_is_theirs
        end,
        reach = case when ${carryReach} then ${gone.reach} else reach end,
        reach_is_theirs = case
          when ${carryReach} then ${gone.reachIsTheirs}
          else reach_is_theirs
        end,
        profile = null,
        profiled_mentions = 0
    where id = ${keepId}
      and student_id = ${session.studentId}`

  await tx`
    delete from people
    where id = ${goneId}
      and student_id = ${session.studentId}`

  // The kept id is the subject. The id that went is in the action, the way
  // the profile row names its fields, so an inspection can follow it.
  await tx`
    insert into audit_log (actor_id, actor_role, action, subject_student_id, subject_type, subject_id)
    values (
      ${session.studentId},
      'student',
      ${`person_merged:${goneId}`},
      ${session.studentId},
      'person',
      ${keepId}
    )`

  return true
}
