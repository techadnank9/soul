import { Hono } from 'hono'
import { transcribe, ConsentRequired } from '../services/transcribe/run.js'
import { judgeTone, storeTone, type Judged } from '../services/tone/judge.js'
import { discardTone } from '../services/tone/store.js'
import type { TranscribeResult } from '../contracts.js'
import type { Session } from '../session.js'

type Vars = { Variables: { session: Session } }

export const transcription = new Hono<Vars>()

/**
 * Audio in, text out, nothing kept.
 *
 * The body is read into memory, sent, and dropped. There is no temporary file
 * and no upload directory, because the surest way to keep audio out of a
 * backup is for it never to touch a disk.
 *
 * The same bytes go to two places at once: the transcriber for the words and
 * the tone model for how they sounded. The second is allowed to fail. A
 * student who spoke gets their transcript whether or not anything managed to
 * listen to it, so the tone call is started, waited on, and shrugged at.
 */
transcription.post('/transcribe', async (c) => {
  const contentType = c.req.header('content-type') ?? 'audio/m4a'
  const audio = new Uint8Array(await c.req.arrayBuffer())

  if (audio.byteLength === 0) return c.json({ error: 'no audio' }, 400)

  // Size and type only. Never the audio itself, and never the transcript.
  console.log(`transcribe: ${audio.byteLength} bytes, ${contentType}`)

  const session = c.get('session')

  const judging: Promise<Judged | null> = judgeTone(audio, contentType, session).catch(
    (error: Error) => {
      if (!(error instanceof ConsentRequired)) console.warn(`tone: ${error.message}`)
      return null
    },
  )

  try {
    const { text, prosody } = await transcribe(audio, contentType, session)
    const judged = await judging
    if (!text) return c.json({ error: 'nothing was heard' }, 422)

    const body: TranscribeResult = { text }
    if (judged) body.toneId = await storeTone(session, judged, prosody)
    return c.json(body)
  } catch (error) {
    await judging
    if (error instanceof ConsentRequired) return c.json({ error: 'held' }, 403)
    throw error
  }
})

/** Discarding a transcript discards how it sounded. */
transcription.delete('/transcribe/:toneId', async (c) => {
  await discardTone(c.req.param('toneId'), c.get('session'))
  return c.json({ ok: true })
})
