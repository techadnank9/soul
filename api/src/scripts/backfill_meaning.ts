import { and, eq, isNull, ne, or } from 'drizzle-orm'
import { db, entries, students, tags } from '../db.js'
import { call } from '../gateway/call.js'
import { taggerResult } from '../contracts.js'
import { TAGGER_VERSION } from '../services/tagging/tag.js'

/**
 * Fills `meaning` on tags written before the list existed. Decision 291.
 *
 * One model call per entry, reading the entry again and writing only the new
 * column. It does not re run the rest of the tagger's job: no cue cards, no
 * people, no facts, no sweep. Those already ran when the entry landed and
 * running them again would write a second copy of work that is already
 * there.
 *
 * The seeded demo accounts are left alone. Their tags were written to be a
 * demo and re reading them would change what the demo shows.
 *
 * Safe to run twice. An entry whose tag already has a meaning is skipped,
 * and a tag that comes back null is marked done by its version so it is not
 * asked about again.
 */
async function main() {
  const rows = await db
    .select({
      tagId: tags.id,
      entryId: tags.entryId,
      studentId: tags.studentId,
      schoolId: tags.schoolId,
      districtId: tags.districtId,
      text: entries.text,
      name: students.displayName,
    })
    .from(tags)
    .innerJoin(entries, eq(entries.id, tags.entryId))
    .innerJoin(students, eq(students.id, tags.studentId))
    .where(and(isNull(tags.meaning), ne(tags.taggerVersion, TAGGER_VERSION)))

  const todo = rows.filter((row) => row.name !== 'Sam')
  console.log(`${rows.length} tags without a meaning, ${todo.length} of them not the demo`)

  let written = 0
  for (const row of todo) {
    const session = {
      studentId: row.studentId,
      schoolId: row.schoolId,
      districtId: row.districtId,
    } as never

    try {
      const result = await call('tagger', {
        user: row.text,
        schema: taggerResult,
        session,
        entryId: row.entryId,
      })

      await db
        .update(tags)
        .set({ meaning: result.value.meaning, taggerVersion: TAGGER_VERSION })
        .where(eq(tags.id, row.tagId))

      if (result.value.meaning) written += 1
      console.log(`  ${row.entryId.slice(0, 8)} ${result.value.meaning ?? 'null'}`)
    } catch (error) {
      console.error(`  ${row.entryId.slice(0, 8)} failed: ${(error as Error).message}`)
    }
  }

  console.log(`${written} of ${todo.length} entries said what they made of it`)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
