import { sql } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * A person deleting their own account, from their own phone. Decision 281.
 *
 * Everything that hangs off the account goes, children before parents, in
 * one transaction, and then the account itself. It is removed rather than
 * hidden, which is what the privacy policy has always said. Nothing here
 * takes an id from the request: the only account this can ever delete is
 * the one the session belongs to.
 *
 * What is kept is one audit row saying that an account was deleted and
 * when, with no link back to anybody, because a deletion nobody can show
 * happened is not one anybody can be held to. The earlier audit rows for the
 * account lose their link and keep their action names, which never held a
 * value anybody wrote.
 *
 * Every table that learns to reference a student or an entry has to be added
 * here, the same rule the demo seed lives under.
 */
export async function deleteAccount(session: Session): Promise<void> {
  const id = session.studentId

  await sql.begin(async (tx) => {
    const [who] = await tx<{ email: string | null }[]>`
      select email from students where id = ${id} for update`
    if (!who) return

    await tx`delete from jobs where student_id = ${id}`
    await tx`delete from outcomes where student_id = ${id}`
    await tx`delete from cue_cards where student_id = ${id}`
    await tx`delete from pattern_verdicts where student_id = ${id}`
    await tx`delete from pattern_candidates where student_id = ${id}`
    await tx`delete from pattern_rejections where student_id = ${id}`
    await tx`delete from confirmed_patterns where student_id = ${id}`
    await tx`delete from noticings where student_id = ${id}`
    await tx`delete from week_notes where student_id = ${id}`
    await tx`delete from section_sightings where student_id = ${id}`
    await tx`delete from reminders where student_id = ${id}`
    await tx`delete from generations where student_id = ${id}`
    await tx`delete from safety_flags where student_id = ${id}`
    await tx`delete from entry_people where student_id = ${id}`
    await tx`delete from people where student_id = ${id}`
    await tx`delete from tags where student_id = ${id}`
    await tx`delete from kept_lines where student_id = ${id}`
    await tx`delete from voice_tones where student_id = ${id}`
    await tx`delete from entry_embeddings where student_id = ${id}`
    await tx`delete from facts where student_id = ${id}`
    await tx`delete from baseline_answers where student_id = ${id}`
    await tx`delete from feedback where student_id = ${id}`
    await tx`delete from app_events where student_id = ${id}`
    await tx`delete from decisions where student_id = ${id}`

    // The account points at its own introduction, so the pointer goes before
    // the entries do.
    await tx`update students set introduction_entry_id = null where id = ${id}`
    await tx`delete from entries where student_id = ${id}`

    await tx`delete from sessions where student_id = ${id}`
    if (who.email) await tx`delete from email_codes where email = ${who.email}`

    await tx`update audit_log set subject_student_id = null where subject_student_id = ${id}`
    await tx`delete from students where id = ${id}`

    await tx`
      insert into audit_log (actor_role, action, subject_type)
      values ('student', 'account_deleted', 'student')`
  })
}
