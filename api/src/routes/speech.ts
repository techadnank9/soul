import { Hono } from 'hono'
import { checkConsent } from '../consent/gate.js'
import { env } from '../env.js'
import { judgeTone, storeTone } from '../services/tone/judge.js'
import type { Prosody } from '../services/transcribe/run.js'
import type { Session } from '../session.js'

/**
 * Live transcription.
 *
 * The phone streams audio straight to the transcriber over a live connection
 * and words come back while the person is still speaking. The API key never
 * reaches the phone: this route mints a single use token that opens one
 * connection and expires in fifteen minutes. Nothing about the audio passes
 * through this service on that path.
 *
 * When the person stops, the phone sends the audio it held in memory here,
 * once, to be judged for how it sounded, and then lets it go. That is the
 * same tone row the old path wrote, minus the word timings.
 */
type Vars = { Variables: { session: Session } }

export const speech = new Hono<Vars>()

speech.post('/speech/token', async (c) => {
  const session = c.get('session')
  if (!(await checkConsent(session, 'third_party_processing'))) {
    return c.json({ error: 'held' }, 403)
  }
  const key = env.providers.elevenlabsKey
  if (!key) return c.json({ error: 'speech is not available' }, 503)

  const response = await fetch('https://api.elevenlabs.io/v1/single-use-token/realtime_scribe', {
    method: 'POST',
    headers: { 'xi-api-key': key },
    signal: AbortSignal.timeout(10_000),
  })
  if (!response.ok) {
    const detail = await response.text().catch(() => '')
    console.error(`speech token: elevenlabs returned ${response.status}: ${detail.slice(0, 200)}`)
    return c.json({ error: 'speech is not available' }, 503)
  }
  const data = (await response.json()) as { token?: string }
  if (!data.token) return c.json({ error: 'speech is not available' }, 503)

  console.log(`speech: token issued for user ${session.studentId.slice(0, 8)}`)
  return c.json({ token: data.token })
})

/** Sixteen kilohertz, mono, sixteen bit: the bytes a second of audio takes. */
const BYTES_PER_SECOND = 16_000 * 2

speech.post('/tone', async (c) => {
  const session = c.get('session')
  const contentType = c.req.header('content-type') ?? 'audio/wav'
  const audio = new Uint8Array(await c.req.arrayBuffer())
  if (audio.byteLength < BYTES_PER_SECOND / 2) return c.json({ error: 'too short' }, 422)

  const startedAt = Date.now()
  try {
    const judged = await judgeTone(audio, contentType, session)
    const prosody: Prosody = {
      wordsPerMinute: null,
      pauses: 0,
      longestPauseMs: 0,
      hesitations: 0,
      audioEvents: [],
      languageCode: null,
      languageProbability: null,
      meanLogprob: null,
      durationMs: Math.round(((audio.byteLength - 44) / BYTES_PER_SECOND) * 1000),
    }
    const toneId = await storeTone(session, judged, prosody)
    console.log(`tone: ${judged.emotion}, ${judged.intent}, ${prosody.durationMs}ms of audio, ${Date.now() - startedAt}ms`)
    return c.json({ toneId })
  } catch (error) {
    console.warn(`tone: failed after ${Date.now() - startedAt}ms: ${(error as Error).message}`)
    return c.json({ error: 'tone failed' }, 502)
  }
})
