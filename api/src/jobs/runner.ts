import { sql } from '../db.js'
import { tagEntry } from '../services/tagging/tag.js'
import { checkBack } from '../services/decisions/checkBack.js'
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
      where status = 'pending' and run_at <= now()
      order by run_at
      for update skip locked
      limit 1
    )
    returning id, type, payload, student_id, school_id, district_id, attempts`
  return rows[0] ?? null
}

async function run(job: Job): Promise<void> {
  const payload = JSON.parse(job.payload) as Record<string, string>

  if (!job.student_id || !job.school_id || !job.district_id) {
    throw new Error('job has no student')
  }

  const session: Session = {
    studentId: job.student_id,
    schoolId: job.school_id,
    districtId: job.district_id,
  }

  switch (job.type) {
    case 'tag_entry':
      await tagEntry(payload.entryId!, session)
      return
    case 'check_back':
      await checkBack(payload.decisionId!, session)
      return
    case 'embed_entry':
      // Embeddings land with task 8. The job is enqueued from day one so the
      // backlog exists when the worker does.
      return
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
