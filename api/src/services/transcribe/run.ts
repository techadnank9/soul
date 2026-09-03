import { checkConsent } from '../../consent/gate.js'
import { env } from '../../env.js'
import type { Session } from '../../session.js'

/**
 * Transcription, behind one function with the provider in config, the same
 * pattern as the model gateway. Switching provider is a config change.
 *
 * The audio is deleted the moment a transcript returns. It is never written to
 * disk, never persisted, never allowed to reach a backup. The buffer below is
 * the only copy and it goes out of scope with this function.
 */
export type Provider = 'elevenlabs'

export class ConsentRequired extends Error {}

/**
 * What the transcriber measured about the voice, as distinct from what a model
 * judged about it. Every number here comes from word timings and is repeatable.
 * Nothing here is an opinion.
 */
export type Prosody = {
  wordsPerMinute: number | null
  pauses: number
  longestPauseMs: number
  hesitations: number
  audioEvents: string[]
  languageCode: string | null
  languageProbability: number | null
  meanLogprob: number | null
  durationMs: number | null
}

type ScribeWord = {
  text: string
  type: 'word' | 'spacing' | 'audio_event'
  start?: number
  end?: number
  logprob?: number
}

/** A silence between two words long enough to be a pause rather than a breath. */
const PAUSE_SECONDS = 0.7

const HESITATION = /^(um+|uh+|er+|erm+|hm+|mm+)$/i

export async function transcribe(
  audio: Uint8Array,
  contentType: string,
  session: Session,
): Promise<{ text: string; provider: Provider; prosody: Prosody }> {
  // Checked here too, before audio leaves. The gate in the submit path is not
  // enough, because audio goes out earlier than any entry does.
  const consented = await checkConsent(session, 'third_party_processing')
  if (!consented) throw new ConsentRequired('consent does not cover this student')

  const key = env.providers.elevenlabsKey
  if (!key) throw new Error('ELEVENLABS_API_KEY is not set')

  // ElevenLabs Scribe takes the audio as one multipart part named file. The
  // blob carries the content type the client declared, so a wav arrives as a
  // wav. Speaker labels are off: a student's entry is one voice. Audio events
  // are on, so a laugh or a sigh is heard, and they are stripped out of the
  // text below so the transcript the student confirms holds only their words.
  const form = new FormData()
  form.set('model_id', 'scribe_v2')
  form.set('tag_audio_events', 'true')
  form.set('diarize', 'false')
  form.set('timestamps_granularity', 'word')
  // Told the language rather than left to guess it. A two second clip is
  // not enough to detect a language from, and a wrong guess turns English
  // into nothing. SOUL_SPEECH_LANGUAGE overrides it, empty means detect.
  const language = process.env.SOUL_SPEECH_LANGUAGE ?? 'eng'
  if (language) form.set('language_code', language)
  form.set('file', new Blob([audio as unknown as BlobPart], { type: contentType }), 'entry.wav')

  const response = await fetch('https://api.elevenlabs.io/v1/speech-to-text', {
    method: 'POST',
    headers: { 'xi-api-key': key },
    body: form,
  })

  if (!response.ok) {
    // The status alone does not say what was wrong with the audio, and that is
    // the thing worth knowing when a student's recording fails.
    const detail = await response.text().catch(() => '')
    throw new Error(`elevenlabs returned ${response.status}: ${detail.slice(0, 300)}`)
  }

  const data = (await response.json()) as any
  const words: ScribeWord[] = Array.isArray(data?.words) ? data.words : []
  const raw: string = typeof data?.text === 'string' ? data.text : ''

  // The words array without event tags, or the plain text with the tags
  // stripped when the array is empty or holds only events.
  let text = words.length ? wordsOnly(words).trim() : ''
  if (!text) text = raw.replace(/\([^)]*\)/g, ' ').replace(/\s{2,}/g, ' ').trim()

  const prosody = measure(words, data)

  // What the transcriber saw, without the words themselves. This is the line
  // to read when a recording comes back empty: how long it was, what
  // language it thought it heard, and whether it heard anything but noise.
  console.log(
    `scribe: ${prosody.durationMs ?? '?'}ms, ${words.filter((w) => w.type === 'word').length} words, ` +
      `raw ${raw.length} chars, events [${prosody.audioEvents.join(', ')}], ` +
      `lang ${prosody.languageCode ?? '?'} ${prosody.languageProbability?.toFixed(2) ?? ''}, ` +
      `logprob ${prosody.meanLogprob?.toFixed(3) ?? '?'}`,
  )

  return { text, provider: 'elevenlabs', prosody }
}

/** The transcript without the event tags, so "(laughter)" is not a word the student said. */
function wordsOnly(words: ScribeWord[]): string {
  return words
    .filter((w) => w.type !== 'audio_event')
    .map((w) => w.text)
    .join('')
    .replace(/\s{2,}/g, ' ')
}

function measure(words: ScribeWord[], data: any): Prosody {
  const spoken = words.filter((w) => w.type === 'word')
  const events = words
    .filter((w) => w.type === 'audio_event')
    .map((w) => w.text.replace(/^\(|\)$/g, '').trim().toLowerCase())
    .filter(Boolean)

  const lastEnd = spoken.reduce((max, w) => Math.max(max, w.end ?? 0), 0)
  const seconds: number | null =
    typeof data?.audio_duration_secs === 'number'
      ? data.audio_duration_secs
      : lastEnd > 0
        ? lastEnd
        : null

  let pauses = 0
  let longest = 0
  for (let i = 1; i < spoken.length; i++) {
    const previous = spoken[i - 1]!
    const current = spoken[i]!
    if (previous.end === undefined || current.start === undefined) continue
    const gap = current.start - previous.end
    if (gap >= PAUSE_SECONDS) pauses += 1
    if (gap > longest) longest = gap
  }

  const hesitations = spoken.filter((w) =>
    HESITATION.test(w.text.replace(/[^a-z]/gi, '')),
  ).length

  const logprobs = spoken
    .map((w) => w.logprob)
    .filter((l): l is number => typeof l === 'number' && Number.isFinite(l))
  const meanLogprob = logprobs.length
    ? logprobs.reduce((a, b) => a + b, 0) / logprobs.length
    : null

  return {
    wordsPerMinute:
      seconds && seconds > 0 ? Math.round((spoken.length / seconds) * 60) : null,
    pauses,
    longestPauseMs: Math.round(longest * 1000),
    hesitations,
    audioEvents: [...new Set(events)],
    languageCode: typeof data?.language_code === 'string' ? data.language_code : null,
    languageProbability:
      typeof data?.language_probability === 'number' ? data.language_probability : null,
    meanLogprob,
    durationMs: seconds ? Math.round(seconds * 1000) : null,
  }
}
