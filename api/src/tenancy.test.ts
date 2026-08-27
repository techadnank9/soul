import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import postgres from 'postgres'
import { mirror } from './generate/mirror.js'
import { answerCandidate } from './services/patterns/answer.js'
import { recordOutcome } from './services/decisions/recordOutcome.js'
import { resolveSession } from './session.js'
import type { Session } from './session.js'

/**
 * One student cannot reach another student's rows by knowing an id.
 *
 * The read side runs inside asStudent, so row level security scopes it. Every
 * write and every generation runs on the pooled handle instead, where the
 * policies do not apply, and for a while three paths there took an id from the
 * request and looked it up without the student. This is the test that says
 * they no longer do.
 *
 * Skipped when DATABASE_URL is absent, the same as the row level security test.
 */

const url = process.env.DATABASE_URL
const run = url ? describe : describe.skip

/** postgres.js returns a list. A fixture that did not insert is a broken test. */
function one<T>(rows: T[], what: string): T {
  const row = rows[0]
  if (!row) throw new Error(`fixture did not insert a ${what}`)
  return row
}

run('one student cannot reach another', () => {
  let sql: postgres.Sql
  let alice: Session
  let bob: Session
  let aliceEntry: string
  let aliceDecision: string
  let aliceCandidate: string
  let districtId: string

  beforeAll(async () => {
    sql = postgres(url!, { max: 1 })
    const stamp = Date.now()

    const district = one(await sql`
      insert into districts (name, retention_days)
      values ('Tenancy district', 365) returning id`, 'district')
    districtId = district.id
    const school = one(await sql`
      insert into schools (district_id, name)
      values (${district.id}, 'Tenancy school') returning id`, 'school')

    const make = async (ref: string): Promise<Session> => {
      const row = one(await sql`
        insert into students (school_id, district_id, external_ref)
        values (${school.id}, ${district.id}, ${ref}) returning id`, 'student')
      return { studentId: row.id, schoolId: school.id, districtId: district.id }
    }

    alice = await make(`tenancy_alice_${stamp}`)
    bob = await make(`tenancy_bob_${stamp}`)

    const entry = one(await sql`
      insert into entries (student_id, school_id, district_id, text, input_mode)
      values (${alice.studentId}, ${school.id}, ${district.id},
              'Something only Alice said', 'typed')
      returning id`, 'entry')
    aliceEntry = entry.id

    const decision = one(await sql`
      insert into decisions
        (entry_id, student_id, school_id, district_id, chosen_text, horizon)
      values (${aliceEntry}, ${alice.studentId}, ${school.id}, ${district.id},
              'Something only Alice chose', now() + interval '3 days')
      returning id`, 'decision')
    aliceDecision = decision.id

    const candidate = one(await sql`
      insert into pattern_candidates
        (student_id, school_id, district_id, theme, supporting_entry_ids)
      values (${alice.studentId}, ${school.id}, ${district.id}, 'alice only',
              ${sql.array([aliceEntry, aliceEntry, aliceEntry])}::uuid[])
      returning id`, 'candidate')
    aliceCandidate = candidate.id
  })

  afterAll(async () => {
    // Children first. Nothing here cascades, and a student with an entry
    // still pointing at them cannot be deleted.
    for (const t of ['outcomes', 'decisions', 'pattern_candidates',
                     'confirmed_patterns', 'generations', 'safety_flags',
                     'entries', 'students', 'schools']) {
      await sql`delete from ${sql(t)} where district_id = ${districtId}`
    }
    await sql`delete from districts where id = ${districtId}`
    await sql.end()
  })

  it("refuses to reflect on somebody else's entry", async () => {
    // Bob holds Alice's entry id. The lookup has to miss before any model is
    // reached, which is also why this test costs nothing to run.
    await expect(mirror(aliceEntry, bob)).rejects.toThrow('entry not found')
  })

  it("refuses to answer somebody else's pattern candidate", async () => {
    await expect(
      answerCandidate(bob, { candidateId: aliceCandidate, answer: 'fits' }),
    ).rejects.toThrow('candidate not found')

    const still = one(await sql`
      select status from pattern_candidates where id = ${aliceCandidate}`, 'candidate')
    expect(still.status).toBe('pending')

    const stolen = await sql`
      select id from confirmed_patterns where student_id = ${bob.studentId}`
    expect(stolen.length).toBe(0)
  })

  it("refuses to record an outcome against somebody else's decision", async () => {
    await expect(
      recordOutcome(bob, { decisionId: aliceDecision, felt: 'lighter' }),
    ).rejects.toThrow('decision not found')

    const open = one(await sql`
      select status from decisions where id = ${aliceDecision}`, 'decision')
    expect(open.status).toBe('open')

    const written = await sql`
      select id from outcomes where decision_id = ${aliceDecision}`
    expect(written.length).toBe(0)
  })

  it('lets the owner through', async () => {
    // The guard has to refuse a stranger without also refusing the student. A
    // scoped query that matched nobody would pass every test above.
    await expect(
      recordOutcome(alice, { decisionId: aliceDecision, felt: 'lighter' }),
    ).resolves.toBeUndefined()

    const closed = one(await sql`
      select status from decisions where id = ${aliceDecision}`, 'decision')
    expect(closed.status).toBe('closed')
  })

  it('refuses a roster identifier as a bearer token unless it is allowed', async () => {
    const ref = `tenancy_alice_bearer_${Date.now()}`
    await sql`
      update students set external_ref = ${ref} where id = ${alice.studentId}`

    const before = process.env.SOUL_ROSTER_TOKENS
    try {
      delete process.env.SOUL_ROSTER_TOKENS
      expect(await resolveSession(ref)).toBeNull()

      process.env.SOUL_ROSTER_TOKENS = 'true'
      expect(await resolveSession(ref)).toBeNull()

      process.env.SOUL_ROSTER_TOKENS = 'allow'
      expect((await resolveSession(ref))?.studentId).toBe(alice.studentId)
    } finally {
      if (before === undefined) delete process.env.SOUL_ROSTER_TOKENS
      else process.env.SOUL_ROSTER_TOKENS = before
    }
  })
})
