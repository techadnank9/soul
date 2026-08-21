import { and, eq } from 'drizzle-orm'
import {
  db,
  sql,
  districts,
  schools,
  students,
  entries,
  tags,
  decisions,
  patternCandidates,
  confirmedPatterns,
  keptLines,
} from '../db.js'

/**
 * A student who has been using the app for a while.
 *
 * Every screen after home reads from real rows, so judging how home behaves
 * needs a stretch of days that actually happened. This writes ten entries over
 * the last ten days, ending today, with tags carrying feelings so the ring has
 * something to divide, a decision still open, a pattern the student confirmed
 * and another still forming.
 *
 * Nothing is dated in the future. A day that has not happened yet has no
 * entries in it, and a list of days that shows tomorrow is a list nobody
 * believes.
 *
 * It is a development fixture and it says so in the roster identifier. Nothing
 * here is a real child and none of it belongs in a district database.
 *
 * Idempotent. It clears this one student's rows and writes them again, so
 * running it twice leaves one week rather than two.
 */
const REF = 'student_demo'

/** The four feelings the ring divides by, and how often each shows up. */
const WEEK: { ago: number; hour: number; text: string; trigger: string; feeling: string; coping: string }[] = [
  {
    ago: 9,
    hour: 8,
    text: 'Got to registration and realised I had left the whole folder at home. Said nothing and hoped nobody would ask.',
    trigger: 'forgot something and hid it',
    feeling: 'self doubt',
    coping: 'went quiet',
  },
  {
    ago: 8,
    hour: 13,
    text: 'Told Priya I would help with the poster and I already have the essay and the match. I said yes before I thought about it.',
    trigger: 'said yes when already full',
    feeling: 'overwhelm',
    coping: 'agreed anyway',
  },
  {
    ago: 8,
    hour: 19,
    text: 'My brother got asked about his exams the whole of dinner. Nobody asked me anything and I did not say anything either.',
    trigger: 'not asked about at home',
    feeling: 'comparison',
    coping: 'went quiet',
  },
  {
    ago: 7,
    hour: 11,
    text: 'The teacher read out my paragraph as an example. I said it was nothing when Sam asked about it after.',
    trigger: 'credited and deflected it',
    feeling: 'self doubt',
    coping: 'made it smaller',
  },
  {
    ago: 6,
    hour: 16,
    text: 'Everyone in the group chat had already started the coursework. I have not opened it once.',
    trigger: 'behind the others',
    feeling: 'comparison',
    coping: 'avoided it',
  },
  {
    ago: 6,
    hour: 21,
    text: 'Three things due Friday and I sat and watched videos for two hours instead of picking one.',
    trigger: 'too much at once',
    feeling: 'overwhelm',
    coping: 'avoided it',
  },
  {
    ago: 4,
    hour: 9,
    text: 'Asked Mr Hale for one more day on the essay. He just said yes. I had been dreading asking for a week.',
    trigger: 'asked for what I needed',
    feeling: 'compassion',
    coping: 'said it directly',
  },
  {
    ago: 4,
    hour: 18,
    text: 'Told my sister about the dinner thing. She said she had noticed it too. Felt lighter after.',
    trigger: 'told someone',
    feeling: 'compassion',
    coping: 'said it directly',
  },
  {
    ago: 3,
    hour: 14,
    text: 'Left the group chat on read again. It is easier than saying I have not started.',
    trigger: 'behind the others',
    feeling: 'self doubt',
    coping: 'avoided it',
  },
  {
    ago: 3,
    hour: 16,
    text: 'The maths test is on Thursday and I still have not done the practice paper Mr Hale gave out. I keep opening it and closing it.',
    trigger: 'putting off the practice paper',
    feeling: 'overwhelm',
    coping: 'avoided it',
  },
  {
    ago: 2,
    hour: 8,
    text: 'Netball trials are Tuesday after school and I have not told mum yet. She thinks I am coming straight home.',
    trigger: 'not told mum about the trials',
    feeling: 'self doubt',
    coping: 'went quiet',
  },
  {
    ago: 1,
    hour: 13,
    text: 'The geography trip form has to be in by Friday and it is still in my bag. Mum has not signed it.',
    trigger: 'the trip form is not in',
    feeling: 'overwhelm',
    coping: 'avoided it',
  },
  {
    ago: 1,
    hour: 20,
    text: 'Keisha asked again if I am going to hers on Saturday and I still have not answered her.',
    trigger: 'left Keisha waiting',
    feeling: 'self doubt',
    coping: 'went quiet',
  },
  {
    ago: 0,
    hour: 9,
    text: 'I want to ask Miss Kaur about doing the presentation with Priya instead of on my own, but I have to ask before Monday.',
    trigger: 'asking to work with Priya',
    feeling: 'self doubt',
    coping: 'has not asked yet',
  },
  {
    ago: 5,
    hour: 12,
    text: 'Asked Miss Kaur if I could do the presentation on Monday instead. She said that was fine. I had been putting off asking all week.',
    trigger: 'asked for what I needed',
    feeling: 'compassion',
    coping: 'said it directly',
  },
  {
    ago: 2,
    hour: 17,
    text: 'Told Priya I already said yes to two things this week. She said she would take the poster. That was easier than I thought.',
    trigger: 'told someone',
    feeling: 'compassion',
    coping: 'said it directly',
  },
  {
    ago: 0,
    hour: 20,
    text: 'Sunday and the coursework is still there. Sat with it for twenty minutes which is more than the whole week.',
    trigger: 'too much at once',
    feeling: 'overwhelm',
    coping: 'started small',
  },
]

/**
 * California, always.
 *
 * Pinned rather than taken from whatever machine runs this, so the demo week
 * is the same week for everybody who seeds it. The times below are wall clock
 * times in this zone and the student is given this zone, because the API
 * buckets days and weeks by the student's own calendar: seeding Los Angeles
 * evenings into a London student slid every entry after five o'clock into the
 * next day and pushed Sunday out of the week entirely.
 */
const ZONE = 'America/Los_Angeles'
const REGION = 'us_west'

/**
 * How far ahead of UTC the zone is at that instant, in milliseconds.
 *
 * Formatting one instant twice, once as the zone and once as UTC, and taking
 * the difference. It reads as a trick because it is one, and it is here so
 * this script needs no timezone library for the one thing it has to get right.
 */
function offsetAt(instant: Date): number {
  const asZone = new Date(instant.toLocaleString('en-US', { timeZone: ZONE }))
  const asUtc = new Date(instant.toLocaleString('en-US', { timeZone: 'UTC' }))
  return asZone.getTime() - asUtc.getTime()
}

/** A wall clock time in California, as the instant it actually happened. */
function inZone(year: number, month: number, day: number, hour: number): Date {
  const guess = Date.UTC(year, month, day, hour)
  return new Date(guess - offsetAt(new Date(guess)))
}

/** That many days before today, at the given hour, in California. */
function daysAgo(ago: number, hour: number): Date {
  // en-CA formats as YYYY-MM-DD, which is the only reason it is used here.
  const today = new Intl.DateTimeFormat('en-CA', { timeZone: ZONE }).format(new Date())
  const [year, month, date] = today.split('-').map(Number) as [number, number, number]

  return inZone(year, month - 1, date - ago, hour)
}

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

  // Written again from nothing, so a second run does not stack two weeks on
  // top of each other. Order matters: the children go before the entries they
  // point at.
  // Children before parents, all the way down. Outcomes and cue cards both
  // point at decisions, and both arrived after this script was written, so
  // reseeding a student who had answered anything failed on the foreign key.
  await sql`delete from jobs where student_id = ${student.id}`
  await sql`delete from outcomes where student_id = ${student.id}`
  await sql`delete from cue_cards where student_id = ${student.id}`
  await sql`delete from pattern_verdicts where student_id = ${student.id}`
  await sql`delete from generations where student_id = ${student.id}`
  await sql`delete from safety_flags where student_id = ${student.id}`
  // People arrived after this script and point at entries, so they go before
  // the entries do. Every table that learns to reference an entry has to be
  // added here or the next reseed fails on the foreign key.
  await sql`delete from entry_people where student_id = ${student.id}`
  await sql`delete from people where student_id = ${student.id}`
  await db.delete(tags).where(eq(tags.studentId, student.id))
  await db.delete(keptLines).where(eq(keptLines.studentId, student.id))
  await db.delete(confirmedPatterns).where(eq(confirmedPatterns.studentId, student.id))
  await db.delete(patternCandidates).where(eq(patternCandidates.studentId, student.id))
  await db.delete(decisions).where(eq(decisions.studentId, student.id))
  await db.delete(entries).where(eq(entries.studentId, student.id))

  const written: string[] = []

  for (const moment of WEEK) {
    const at = daysAgo(moment.ago, moment.hour)

    const [entry] = await db
      .insert(entries)
      .values({
        ...scope,
        text: moment.text,
        inputMode: moment.ago % 2 === 0 ? 'voice' : 'typed',
        transcriptConfirmed: moment.ago % 2 === 0,
        localHour: moment.hour,
        processed: true,
        createdAt: at,
      })
      .returning({ id: entries.id })
    if (!entry) throw new Error('entry insert returned no row')
    written.push(entry.id)

    /**
     * The row the classifier writes on every entry, hit or miss.
     *
     * Seeded here because it is not decoration: cue card generation only reads
     * entries that carry one at risk none or low, so a demo student without
     * these rows can never produce a card and the feature looks broken when it
     * is the fixture that is wrong.
     */
    await sql`
      insert into safety_flags
        (entry_id, student_id, school_id, district_id, risk_level, categories,
         classifier_version, action_taken, resources_shown, status, created_at)
      values (
        ${entry.id}, ${student.id}, ${school.id}, ${district.id}, 'none',
        '{}'::text[], 'seed-demo', 'reflected', false, 'closed',
        ${at.toISOString()}::timestamptz
      )`

    await db.insert(tags).values({
      ...scope,
      entryId: entry.id,
      trigger: moment.trigger,
      feeling: moment.feeling,
      coping: moment.coping,
      domain: 'school',
      // Above the floor the pattern query uses, because these are the tags a
      // good tagger would have been confident about.
      confidence: 0.82,
      taggerVersion: 'seed-demo',
      createdAt: at,
    })
  }

  // Open, and past its day, which is the state home shows a check back for.
  const horizon = daysAgo(1, 17)
  await db.insert(decisions).values({
    ...scope,
    entryId: written[2]!,
    offeredText: 'Say one thing at dinner before the week is out',
    chosenText: 'Ask my brother about his exams and then say one thing about mine',
    horizon,
    status: 'open',
    createdAt: daysAgo(8, 19),
  })

  /**
   * Two check backs already answered, one each way.
   *
   * The returning tab splits on what the student said when the app asked how
   * something went, and their answer outranks anything the model decides. A
   * demo student with no outcomes can only ever show the model's opinion, so
   * these two exist to show the other source working.
   */
  const closed: [number, string, string, 'lighter' | 'worse'][] = [
    [7, 'Tell Priya I already said yes to two things this week', 'She took the poster', 'lighter'],
    [6, 'Open the coursework and read the first page tonight', 'Watched videos instead', 'worse'],
  ]

  for (const [ago, chose, happened, felt] of closed) {
    const [decision] = await db
      .insert(decisions)
      .values({
        ...scope,
        entryId: written[felt === 'lighter' ? 1 : 5]!,
        chosenText: chose,
        horizon: daysAgo(ago - 2, 17),
        status: 'closed',
        createdAt: daysAgo(ago, 17),
      })
      .returning({ id: decisions.id })
    if (!decision) throw new Error('decision insert returned no row')

    await sql`
      insert into outcomes
        (decision_id, student_id, school_id, district_id, what_happened, felt, responded_at, created_at)
      values (
        ${decision.id}, ${student.id}, ${school.id}, ${district.id},
        ${happened}, ${felt}, ${daysAgo(ago - 2, 19).toISOString()},
        ${daysAgo(ago - 2, 19).toISOString()}
      )`
  }

  // One the student confirmed, and one still short of being asked about.
  await db.insert(confirmedPatterns).values({
    ...scope,
    theme: 'going quiet when not credited',
    supportingEntryIds: [written[0]!, written[2]!, written[8]!],
    confirmedAt: daysAgo(3, 20),
  })

  await db.insert(patternCandidates).values({
    ...scope,
    theme: 'behind the others',
    supportingEntryIds: [written[4]!, written[8]!],
    status: 'pending',
    createdAt: daysAgo(2, 20),
  })

  await db.insert(keptLines).values({
    ...scope,
    entryId: written[7]!,
    text: 'You told her, and it landed lighter than holding it did.',
    createdAt: daysAgo(4, 18),
  })

  console.log(`demo student ready: ${REF}, ${WEEK.length} entries, ending today, ${ZONE}`)
  process.exit(0)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
