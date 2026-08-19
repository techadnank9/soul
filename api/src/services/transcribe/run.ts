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
export type Provider = 'deepgram'

export class ConsentRequired extends Error {}

export async function transcribe(
  audio: Uint8Array,
  contentType: string,
  session: Session,
): Promise<{ text: string; provider: Provider }> {
  // Checked here too, before audio leaves. The gate in the submit path is not
  // enough, because audio goes out earlier than any entry does.
  const consented = await checkConsent(session, 'third_party_processing')
  if (!consented) throw new ConsentRequired('consent does not cover this student')

  const key = env.providers.deepgramKey
  if (!key) throw new Error('DEEPGRAM_API_KEY is not set')

  const url = new URL('https://api.deepgram.com/v1/listen')
  url.searchParams.set('model', 'nova-3')
  url.searchParams.set('smart_format', 'true')
  url.searchParams.set('punctuate', 'true')
  // Never used for provider training. This is a district contract term, not a
  // preference.
  url.searchParams.set('mip_opt_out', 'true')

  const response = await fetch(url, {
    method: 'POST',
    headers: { authorization: `Token ${key}`, 'content-type': contentType },
    body: audio as unknown as BodyInit,
  })

  if (!response.ok) {
    // The status alone does not say what was wrong with the audio, and that is
    // the thing worth knowing when a student's recording fails.
    const detail = await response.text().catch(() => '')
    throw new Error(`deepgram returned ${response.status}: ${detail.slice(0, 300)}`)
  }

  const data = (await response.json()) as any
  const text: string =
    data?.results?.channels?.[0]?.alternatives?.[0]?.transcript ?? ''

  return { text: text.trim(), provider: 'deepgram' }
}
