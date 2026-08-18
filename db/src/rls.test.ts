import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import postgres from 'postgres'

/**
 * The done condition for task 1: a query as student A returns nothing
 * belonging to student B. Skipped when DATABASE_URL is absent.
 */

const url = process.env.DATABASE_URL
const run = url ? describe : describe.skip

run('row level security', () => {
  let sql: postgres.Sql
  const ids: Record<string, string> = {}

  beforeAll(async () => {
    sql = postgres(url!, { max: 1 })

    const [district] = await sql`
      insert into districts (name, retention_days)
      values ('Test district', 365) returning id`
    const [school] = await sql`
      insert into schools (district_id, name)
      values (${district.id}, 'Test school') returning id`
    const [a] = await sql`
      insert into students (school_id, district_id, external_ref)
      values (${school.id}, ${district.id}, ${'a_' + Date.now()}) returning id`
    const [b] = await sql`
      insert into students (school_id, district_id, external_ref)
      values (${school.id}, ${district.id}, ${'b_' + Date.now()}) returning id`

    for (const [key, student] of [['a', a], ['b', b]] as const) {
      const [entry] = await sql`
        insert into entries (student_id, school_id, district_id, text, input_mode)
        values (${student.id}, ${school.id}, ${district.id}, ${'entry for ' + key}, 'typed')
        returning id`
      ids['entry_' + key] = entry.id
    }
    ids.district = district.id
    ids.school = school.id
    ids.a = a.id
    ids.b = b.id
  })

  afterAll(async () => {
    await sql`delete from entries where student_id in (${ids.a}, ${ids.b})`
    await sql`delete from students where id in (${ids.a}, ${ids.b})`
    await sql`delete from schools where id = ${ids.school}`
    await sql`delete from districts where id = ${ids.district}`
    await sql.end()
  })

  it('returns only the session student rows', async () => {
    const rows = await sql.begin(async (tx) => {
      await tx`set local role soul_student`
      await tx`select set_config('app.student_id', ${ids.a}, true)`
      return tx`select id, student_id from entries`
    })
    expect(rows.map((r) => r.student_id)).toEqual([ids.a])
    expect(rows.map((r) => r.id)).not.toContain(ids.entry_b)
  })

  it('refuses to write a row belonging to another student', async () => {
    await expect(
      sql.begin(async (tx) => {
        await tx`set local role soul_student`
        await tx`select set_config('app.student_id', ${ids.a}, true)`
        return tx`
          insert into entries (student_id, school_id, district_id, text, input_mode)
          values (${ids.b}, ${ids.school}, ${ids.district}, 'not mine', 'typed')`
      }),
    ).rejects.toThrow()
  })

  it('reads no prompt text from the request path', async () => {
    await expect(
      sql.begin(async (tx) => {
        await tx`set local role soul_student`
        await tx`select set_config('app.student_id', ${ids.a}, true)`
        return tx`select id from prompts`
      }),
    ).rejects.toThrow()
  })
})
