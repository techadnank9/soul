import { Hono } from 'hono'
import { tick } from '../jobs/runner.js'
import { env } from '../env.js'

/**
 * A way to drain the job queue over HTTP, so a scheduler can do what the
 * always on worker does.
 *
 * `npm run worker` runs `loop()` forever, which is the right shape on a
 * machine that stays up. It is the wrong shape anywhere that bills by the hour
 * or sleeps, and it is no shape at all on a laptop that closes. This endpoint
 * exists so anything with a clock can drive the same `tick()`: Supabase
 * pg_cron, a platform cron, EventBridge, or curl.
 *
 * It is not on the student path and it has no session. The bearer here is a
 * shared secret between the service and whatever schedules it, which is why
 * this route is excluded from the session middleware in server.ts.
 *
 * Failing closed matters more than being convenient. With no secret set it
 * refuses every caller rather than running jobs for anybody who finds the URL.
 */
export const jobs = new Hono()

/** One call should be able to clear a backlog without running forever. */
const MAX_PER_CALL = 25

jobs.post('/jobs/drain', async (c) => {
  const secret = env.jobsSecret()

  if (!secret) {
    // Nothing is scheduled rather than everything is open.
    return c.json({ error: 'job draining is not configured' }, 503)
  }

  const header = c.req.header('authorization')
  const offered = header?.startsWith('Bearer ') ? header.slice(7) : undefined

  if (!offered || !safeEqual(offered, secret)) {
    return c.json({ error: 'no' }, 401)
  }

  let ran = 0
  // Stops early when the queue is empty, so a quiet minute costs one query.
  while (ran < MAX_PER_CALL) {
    const worked = await tick()
    if (!worked) break
    ran += 1
  }

  return c.json({ ran, drained: ran < MAX_PER_CALL })
})

/**
 * Constant time compare. A timing difference on a shared secret is a small
 * leak, and the fix is three lines.
 */
function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i += 1) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}
