import { sql } from '../db.js'
import { tagEntry } from '../services/tagging/tag.js'
import { checkBack } from '../services/decisions/checkBack.js'
import { generateCards } from '../services/cards/generate.js'
import { extractPeople } from '../services/people/extract.js'
import { writeProfile } from '../services/people/profile.js'
import { sweep } from './pattern_sweep.js'
import { sweepVerdicts } from '../services/verdicts/sweep.js'
import { scheduleSweep, scheduleVerdicts } from './enqueue.js'
import type { Session } from '../session.js'

/**
 * The durable job runner.
 *
 * Claims one job at a time with a row lock, so two workers never run the same
 * job. Check backs are scheduled days out and must survive every deploy
 * between now and then, which is why this is a table and not a timer.
 */
const MAX_ATTEMPTS = 5
const POLL_MS = 2000

/**
 * The types this runner can run.
 *
 * A job of any other type is left where it is rather than claimed. That is
 * what makes embed_entry a backlog: those rows wait, pending, until task 8
 * gives them a worker. Claiming one and returning would mark it done and the
 * entry would never be embedded by anything.
 */
const HANDLED = [
  'tag_entry',
  'check_back',
  'pattern_sweep',
  'pattern_verdicts',
  'cue_cards',
  'people',
  'person_profile',
]

type Job = {
  id: string
  type: string
  payload: string
  student_id: string | null
  school_id: string | null
  district_id: string | null
  attempts: number
}

async function claim(): Promise<Job | null> {
  const rows = await sql<Job[]>`
    update jobs set status = 'running', attempts = attempts + 1
    where id = (
      select id from jobs
      where status = 'pending'
        and run_at <= now()
        and type = any(${HANDLED})
      order by run_at
      for update skip locked
      limit 1
    )
    returning id, type, payload, student_id, school_id, district_id, attempts`
  return rows[0] ?? null
}

/**
 * Every job here belongs to one student except the sweep, which belongs to all
 * of them. Reading the student out where it is used keeps that difference in
 * one place instead of refusing the sweep before it starts.
 */
function studentOf(job: Job): Session {
  if (!job.student_id || !job.school_id || !job.district_id) {
    throw new Error('job has no student')
  }
  return {
    studentId: job.student_id,
    schoolId: job.school_id,
    districtId: job.district_id,
  }
}

async function run(job: Job): Promise<void> {
  const payload = JSON.parse(job.payload) as Record<string, string>

  switch (job.type) {
    case 'tag_entry':
      await tagEntry(payload.entryId!, studentOf(job))
      return
    case 'check_back':
      await checkBack(payload.decisionId!, studentOf(job))
      return
    case 'people': {
      // Usually zero. Most entries name nobody, and an entry that names
      // nobody must produce nobody.
      const named = await extractPeople(payload.entryId!, studentOf(job))
      console.log(`${named} people named`)
      return
    }
    case 'person_profile': {
      const written = await writeProfile(payload.personId!, studentOf(job))
      console.log(written ? 'profile written' : 'profile not due')
      return
    }
    case 'cue_cards': {
      // Often zero, which is the answer when nothing the student wrote points
      // forward. Logged either way, because a run that writes nothing for a
      // week is the first sign the prompt has stopped working.
      const cards = await generateCards(payload.entryId!, studentOf(job))
      console.log(`${cards} cards written`)
      return
    }
    case 'pattern_sweep': {
      const count = await sweep()
      console.log(`${count} candidates proposed`)
      // Booked here rather than by a cron entry, so the only thing that has to
      // be running for the sweep to keep happening is this runner.
      await scheduleSweep()
      // And the verdicts on the back of it, now rather than tonight, because
      // the themes this sweep just read are the ones they are written about.
      await scheduleVerdicts()
      return
    }
    case 'pattern_verdicts': {
      // Skipped is the ordinary answer and it is not a failure. A theme the
      // entries do not carry a verdict for stays a thing that keeps
      // returning, in neither section, and is asked about again next time.
      const { judged, skipped } = await sweepVerdicts()
      console.log(`${judged} verdicts written, ${skipped} left without one`)
      return
    }
    default:
      throw new Error(`unknown job type ${job.type}`)
  }
}

export async function tick(): Promise<boolean> {
  const job = await claim()
  if (!job) return false

  try {
    await run(job)
    await sql`update jobs set status = 'done' where id = ${job.id}`
  } catch (error) {
    const message = (error as Error).message
    const dead = job.attempts >= MAX_ATTEMPTS
    await sql`
      update jobs
      set status = ${dead ? 'failed' : 'pending'},
          last_error = ${message},
          run_at = now() + (interval '1 minute' * ${job.attempts})
      where id = ${job.id}`
  }
  return true
}

async function loop(): Promise<void> {
  // The sweep keeps itself going once it has run once. This is the once.
  await scheduleSweep()

  for (;;) {
    const worked = await tick()
    if (!worked) await new Promise((resolve) => setTimeout(resolve, POLL_MS))
  }
}

if (process.argv[1]?.endsWith('runner.ts')) {
  loop().catch((error) => {
    console.error(error)
    process.exit(1)
  })
}
