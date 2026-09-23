import { sql } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Forgetting, for real.
 *
 * The README says everything the app holds about a person traces back to
 * entries that person can see and delete. Until this existed the second half
 * was not true: there was no way to delete one entry, and everything derived
 * from an entry outlived it anyway. A fact read out of a moment somebody
 * took back would have gone on being quoted to the model for months.
 *
 * So a delete is not one row. It is the moment and everything that was only
 * ever true because of it:
 *
 *   a fact standing on this entry alone     retired, not deleted
 *   a fact standing on this and others      loses this entry, keeps holding
 *   a pattern candidate                     loses this entry, and goes when
 *                                           it drops under two
 *   a pattern they confirmed                loses this entry, and is taken
 *                                           down when it drops under two
 *   tags, embedding, cards, people, the
 *   safety row, the generations, the tone   gone with it
 *
 * Retired rather than deleted, for the facts: `retired_at` is what the
 * memory layer already means by a fact the system stopped trusting, nothing
 * loads a retired fact, and the row is what lets the next question about why
 * something vanished be answerable. A person who asks for the whole account
 * to go has `services/account/delete.ts`, which takes the rows themselves.
 *
 * One transaction. A half forgotten entry is worse than a kept one, because
 * the person was told it was gone.
 */
export async function forgetEntry(entryId: string, session: Session): Promise<void> {
  const mine = await sql<{ id: string }[]>`
    select id from entries
    where id = ${entryId}::uuid and student_id = ${session.studentId}::uuid
    limit 1`

  if (mine.length === 0) throw new Error('entry not found')

  await sql.begin(async (tx) => {
    // A fact that stood on this entry and nothing else stops holding. The row
    // stays: the graph can still say something was known and is not any more.
    await tx`
      update facts
      set retired_at = now()
      where student_id = ${session.studentId}::uuid
        and retired_at is null
        and entry_ids <@ array[${entryId}::uuid]`

    // A fact with other entries behind it loses this one and goes on.
    await tx`
      update facts
      set entry_ids = array_remove(entry_ids, ${entryId}::uuid)
      where student_id = ${session.studentId}::uuid
        and ${entryId}::uuid = any(entry_ids)`

    await tx`
      update pattern_candidates
      set supporting_entry_ids = array_remove(supporting_entry_ids, ${entryId}::uuid)
      where student_id = ${session.studentId}::uuid
        and ${entryId}::uuid = any(supporting_entry_ids)`

    // A candidate is a question we have not asked yet or have not been
    // answered on. One that no longer has two moments behind it is not a
    // question any more.
    await tx`
      delete from pattern_candidates
      where student_id = ${session.studentId}::uuid
        and cardinality(supporting_entry_ids) < 2
        and status in ('pending', 'surfaced')`

    await tx`
      update confirmed_patterns
      set supporting_entry_ids = array_remove(supporting_entry_ids, ${entryId}::uuid)
      where student_id = ${session.studentId}::uuid
        and ${entryId}::uuid = any(supporting_entry_ids)`

    // A pattern they confirmed is theirs, so it is taken down rather than
    // deleted, the same way this is not me takes one down. It stops being
    // shown and stops being loaded into context the moment the evidence
    // behind it is not there any more.
    await tx`
      update confirmed_patterns
      set removed_at = now()
      where student_id = ${session.studentId}::uuid
        and removed_at is null
        and cardinality(supporting_entry_ids) < 2`

    // Everything written about the entry itself. Outcomes before decisions,
    // decisions before the entry, because each points at the one before it.
    await tx`
      delete from outcomes
      where student_id = ${session.studentId}::uuid
        and decision_id in (select id from decisions where entry_id = ${entryId}::uuid)`
    await tx`delete from decisions where entry_id = ${entryId}::uuid`
    await tx`delete from cue_cards where entry_id = ${entryId}::uuid`
    await tx`delete from entry_people where entry_id = ${entryId}::uuid`
    await tx`delete from kept_lines where entry_id = ${entryId}::uuid`
    await tx`delete from safety_flags where entry_id = ${entryId}::uuid`
    await tx`delete from generations where entry_id = ${entryId}::uuid`
    await tx`delete from tags where entry_id = ${entryId}::uuid`
    await tx`delete from entry_embeddings where entry_id = ${entryId}::uuid`

    // The entry last. The tone row and the section sightings carry their own
    // cascade and go with it.
    await tx`
      delete from entries
      where id = ${entryId}::uuid and student_id = ${session.studentId}::uuid`
  })
}
