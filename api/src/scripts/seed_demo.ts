import { and, eq } from 'drizzle-orm'
import { db, districts, schools, students } from '../db.js'
import { seedDemoWeek, ZONE, REGION } from '../services/demo/seed.js'

/**
 * The seeded demo student, a week of entries ending today. The week itself
 * lives in services/demo/seed.ts so the app's demo skip can write the same
 * week into a fresh account.
 */
const REF = 'student_demo'

async function main() {
  const district =
    (await db.select({ id: districts.id }).from(districts).where(eq(districts.name, 'Test district')).limit(1))[0] ??
    (await db
      .insert(districts)
      .values({ name: 'Test district', consentModel: 'school', retentionDays: 365 })
      .returning({ id: districts.id }))[0]
  if (!district) throw new Error('no district')

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
  if (!school) throw new Error('no school')

  const student =
    (await db.select({ id: students.id }).from(students).where(eq(students.externalRef, REF)).limit(1))[0] ??
    (await db
      .insert(students)
      .values({
        schoolId: school.id,
        districtId: district.id,
        externalRef: REF,
        consentRecordedAt: new Date(),
        consentVersion: 'v1',
        displayName: 'Sam',
        ageBand: '13_17',
        gender: 'not_said',
        region: REGION,
        timezone: ZONE,
        profileRecordedAt: new Date(),
      })
      .returning({ id: students.id }))[0]
  if (!student) throw new Error('no student')

  // Written every run rather than only at creation. A student seeded before
  // this script was pinned to California kept whatever zone it was given then,
  // and the week query reads the student's zone, not this file's.
  await db
    .update(students)
    .set({
      displayName: 'Sam',
      ageBand: '13_17',
      gender: 'not_said',
      region: REGION,
      timezone: ZONE,
      profileRecordedAt: new Date(),
      consentRecordedAt: new Date(),
      consentVersion: 'v1',
    })
    .where(eq(students.id, student.id))

  const scope = { studentId: student.id, schoolId: school.id, districtId: district.id }
  const count = await seedDemoWeek(scope)
  console.log(`demo student ready: ${REF}, ${count} entries, ending today, ${ZONE}`)
  process.exit(0)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
