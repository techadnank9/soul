import { eq } from 'drizzle-orm'
import { db, students } from '../db.js'
import { createAccount } from '../auth/accounts.js'
import { seedDemoWeek } from '../services/demo/seed.js'
import { env } from '../env.js'

/**
 * The account Apple's reviewer signs in to.
 *
 * App review has to be able to reach past first run, and first run ends in
 * sign in with no way around it. This makes one ordinary account, puts the
 * review address on it, and fills it with the same demo week the test student
 * gets, so a reviewer opening the app sees a home with a week in it rather
 * than the empty day one a fresh account would show them.
 *
 * Nothing about the account is special. It is a row in the self signup
 * district like any other, it is subject to the same row level security, and
 * everything the reviewer sees is what the product actually does. The only
 * special thing is how they get in, which is in auth/email.ts and is off
 * unless the host was given both variables. Decision 261.
 *
 * Run it again whenever the week should be fresh. It reseeds in place rather
 * than making a second account, so the address always points at one row.
 */
async function main() {
  const email = env.reviewEmail()
  if (!email) {
    console.error('SOUL_REVIEW_EMAIL is not set. Nothing to seed.')
    process.exit(1)
  }

  const held = await db
    .select({ id: students.id, schoolId: students.schoolId, districtId: students.districtId })
    .from(students)
    .where(eq(students.email, email))
    .limit(1)

  const account = held[0] ?? (await createAccount())
  if (!held[0]) {
    await db.update(students).set({ email }).where(eq(students.id, account.id))
  }

  // A name, so home greets them, and a region so the week is cut in a real
  // timezone rather than in UTC.
  await db
    .update(students)
    .set({
      displayName: 'Alex',
      ageBand: '18_24',
      region: 'us_west',
      timezone: 'America/Los_Angeles',
      intentArea: 'people_close',
      intentReason: 'keeps_happening',
    })
    .where(eq(students.id, account.id))

  const written = await seedDemoWeek({
    studentId: account.id,
    schoolId: account.schoolId,
    districtId: account.districtId,
  })

  console.log(`${email} is ready, ${written} entries, account ${account.id}`)
  console.log(`the code for it is whatever SOUL_REVIEW_CODE is on the host`)
  process.exit(0)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
