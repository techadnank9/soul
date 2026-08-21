import { and, eq, sql as raw } from 'drizzle-orm'
import { db, entries, people, entryPeople, sql } from '../../db.js'
import { call } from '../../gateway/call.js'
import { peopleResult } from './schema.js'
import { enqueue } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'

/**
 * The people named in one entry.
 *
 * Runs after the tagger, off the request path, on the entry the student just
 * wrote. It reads names out of their own words. It does not go looking
 * anywhere else and it has nothing to look with.
 *
 * A name the student has used before matches the row they already have. A new
 * name makes a row. Nothing here decides that two people are the same person
 * or that one person is two, because the only evidence for either is the name
 * the student chose and that is theirs.
 */
export async function extractPeople(
  entryId: string,
  session: Session,
): Promise<number> {
  const rows = await db
    .select({ text: entries.text, at: entries.createdAt })
    .from(entries)
    .where(eq(entries.id, entryId))
    .limit(1)

  const entry = rows[0]
  if (!entry) return 0

  const result = await call('people', {
    user: entry.text,
    schema: peopleResult,
    session,
    entryId,
  })

  let written = 0

  for (const named of result.value.people) {
    // The name as they said it, matched case insensitively so Mum and mum are
    // one person rather than two rows a student has to reconcile.
    const existing = await db
      .select({ id: people.id })
      .from(people)
      .where(
        and(
          eq(people.studentId, session.studentId),
          raw`lower(${people.name}) = lower(${named.name})`,
        ),
      )
      .limit(1)

    let personId = existing[0]?.id

    if (!personId) {
      const [made] = await db
        .insert(people)
        .values({
          studentId: session.studentId,
          schoolId: session.schoolId,
          districtId: session.districtId,
          name: named.name,
          firstSeenAt: entry.at,
          lastSeenAt: entry.at,
        })
        .onConflictDoNothing({ target: [people.studentId, people.name] })
        .returning({ id: people.id })

      personId = made?.id
      if (!personId) continue
    }

    const [link] = await db
      .insert(entryPeople)
      .values({
        entryId,
        personId,
        studentId: session.studentId,
        schoolId: session.schoolId,
        districtId: session.districtId,
        said: named.said,
      })
      .onConflictDoNothing({ target: [entryPeople.entryId, entryPeople.personId] })
      .returning({ id: entryPeople.id })

    // The counter follows the links rather than the replies, so a job that
    // runs twice on one entry does not inflate how often somebody appears.
    if (!link) continue

    // Sent as an ISO string and cast in the query. The driver this shares with
    // drizzle has date serialising turned off, so a Date passed to a raw query
    // throws, and the counter silently stayed at zero while the links piled up.
    const at = entry.at.toISOString()

    await sql`
      update people
      set mentions = (select count(*) from entry_people where person_id = ${personId}),
          last_seen_at = greatest(coalesce(last_seen_at, ${at}::timestamptz), ${at}::timestamptz),
          first_seen_at = least(coalesce(first_seen_at, ${at}::timestamptz), ${at}::timestamptz)
      where id = ${personId}`

    written += 1

    // Two mentions is the bar for writing anything about somebody. One is a
    // name in a sentence and there is nothing to say about it yet.
    await enqueue('person_profile', { personId }, session)
  }

  return written
}
