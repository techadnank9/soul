import { and, eq } from 'drizzle-orm'
import { db, districts, schools, students } from '../db.js'

/**
 * The two test students CLAUDE.md promises exist.
 *
 * Until now they were created by hand, which meant a reset lost them and the
 * documentation was true only on the machine that made them. Idempotent, so
 * running it twice changes nothing.
 *
 *   student_with_consent   consent recorded, the ordinary path
 *   student_no_consent     nothing recorded, how the gate is checked
 *
 * Neither has a profile. First run fills that in, and a student who has never
 * been through it is the state worth testing against.
 */
async function main() {
  // Districts and schools have no unique column to conflict on, so the row is
  // looked up by name first. Inserting blind minted a new district and school
  // every run, and because the students conflict target is (school_id,
  // external_ref), a new school id meant the test students were duplicated
  // rather than left alone. Two rows with the same external_ref make the dev
  // token resolve to whichever one the database happens to return.
  const district =
    (await db
      .select({ id: districts.id })
      .from(districts)
      .where(eq(districts.name, 'Test district'))
      .limit(1))[0] ??
    (await db
      .insert(districts)
      .values({ name: 'Test district', consentModel: 'school', retentionDays: 365 })
      .returning({ id: districts.id }))[0]
  if (!district) throw new Error('district insert returned no row')

  const school =
    (await db
      .select({ id: schools.id })
      .from(schools)
      .where(and(eq(schools.districtId, district.id), eq(schools.name, 'Test school')))
      .limit(1))[0] ??
    (await db
      .insert(schools)
      .values({ districtId: district.id, name: 'Test school' })
      .returning({ id: schools.id }))[0]
  if (!school) throw new Error('school insert returned no row')

  await db
    .insert(students)
    .values([
      {
        schoolId: school.id,
        districtId: district.id,
        externalRef: 'student_with_consent',
        consentRecordedAt: new Date(),
        consentVersion: 'v1',
      },
      {
        schoolId: school.id,
        districtId: district.id,
        externalRef: 'student_no_consent',
      },
    ])
    .onConflictDoNothing({
      target: [students.schoolId, students.externalRef],
    })

  console.log('fixtures ready: 1 district, 1 school, 2 students')
  process.exit(0)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
