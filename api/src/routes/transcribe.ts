import { Hono } from 'hono'
import { transcribe, ConsentRequired } from '../services/transcribe/run.js'
import type { Session } from '../session.js'

type Vars = { Variables: { session: Session } }

export const transcription = new Hono<Vars>()

/**
 * Audio in, text out, nothing kept.
 *
 * The body is read into memory, sent, and dropped. There is no temporary file
 * and no upload directory, because the surest way to keep audio out of a
 * backup is for it never to touch a disk.
 */
transcription.post('/transcribe', async (c) => {
  const contentType = c.req.header('content-type') ?? 'audio/m4a'
  const audio = new Uint8Array(await c.req.arrayBuffer())

  if (audio.byteLength === 0) return c.json({ error: 'no audio' }, 400)

  try {
    const { text } = await transcribe(audio, contentType, c.get('session'))
    if (!text) return c.json({ error: 'nothing was heard' }, 422)
    return c.json({ text })
  } catch (error) {
    if (error instanceof ConsentRequired) return c.json({ error: 'held' }, 403)
    throw error
  }
})
