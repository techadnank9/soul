import { desc, eq } from 'drizzle-orm'
import { db, people, entryPeople, sql } from '../../db.js'
import { call } from '../../gateway/call.js'
import { personProfileResult } from './schema.js'
import type { Session } from '../../session.js'

/**
 * What happens between this student and one person they keep mentioning.
 *
 * Written from the sentences the student wrote, and from nothing else. The
 * prompt is where the line is held: what happened between them, never what the
 * other person is like. Read prompts/person_profile.v1.md before changing
 * anything here, because the code cannot tell those two apart and the prompt
 * is the only thing that can.
 *
 * A field the student has edited is never overwritten. Their words about a
 * person outrank ours permanently, which is the least this can do for somebody
 * who is being written about without being asked.
 */
const MENTIONS_BEFORE_WRITING = 2

export async function writeProfile(
  personId: string,
  session: Session,
): Promise<boolean> {
  const rows = await db
    .select({
      name: people.name,
      mentions: people.mentions,
      profiled: people.profiledMentions,
      relationIsTheirs: people.relationIsTheirs,
    })
    .from(people)
    .where(eq(people.id, personId))
    .limit(1)

  const person = rows[0]
  if (!person) return false

  // Nothing to say yet, and nothing new to say. A person whose mentions have
  // not moved since the last run gets the sentences they already have.
  if (person.mentions < MENTIONS_BEFORE_WRITING) return false
  if (person.mentions <= person.profiled) return false

  const said = await db
    .select({ said: entryPeople.said, at: entryPeople.createdAt })
    .from(entryPeople)
    .where(eq(entryPeople.personId, personId))
    .orderBy(desc(entryPeople.createdAt))
    .limit(20)

  if (said.length === 0) return false

  const oldestFirst = [...said].reverse()
  const user = [
    `They call this person ${person.name}.`,
    'Where they come up, oldest first:',
    oldestFirst.map((line, index) => `  ${index + 1}. ${line.said}`).join('\n'),
  ].join('\n\n')

  const result = await call('person_profile', {
    user,
    schema: personProfileResult,
    session,
  })

  await sql`
    update people
    set profile = ${result.value.profile},
        relation = case
          when relation_is_theirs then relation
          else ${result.value.relation || null}
        end,
        prompt_version = ${result.promptVersion},
        model_version = ${result.model},
        profiled_mentions = mentions
    where id = ${personId}
      and student_id = ${session.studentId}`

  return true
}
