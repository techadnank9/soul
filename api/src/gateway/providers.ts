/**
 * Provider calls, over plain fetch.
 *
 * No vendor SDKs. Three SDKs would be three dependency trees, three release
 * cadences and three more names in a district data agreement, to save a
 * function that posts JSON and reads a string back.
 */

export type ProviderName = 'openai' | 'gemini' | 'openrouter'

export type ProviderCall = {
  system: string
  user: string
  model: string
  temperature: number
  maxTokens: number
  json: boolean
  /**
   * How much thinking a reasoning model should do before answering. Reasoning
   * tokens are billed and counted against the same budget as the reply, so a
   * model left to think freely can spend the whole allowance and return
   * nothing at all.
   */
  reasoning: 'minimal' | 'low' | 'medium' | 'high'
  signal: AbortSignal
  /**
   * A recording to listen to alongside the text, for the one purpose that
   * hears rather than reads. The bytes are encoded into the request body and
   * dropped with it. They never touch a disk here either.
   */
  audio?: { bytes: Uint8Array; mimeType: string }
}

/** The short format name the audio models want, from a mime type. */
function audioFormat(mimeType: string): string {
  const lower = mimeType.toLowerCase()
  if (lower.includes('mp3') || lower.includes('mpeg')) return 'mp3'
  return 'wav'
}

function base64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64')
}

export type ProviderReply = {
  text: string
  inputTokens?: number
  outputTokens?: number
}

async function postJson(url: string, key: string, body: unknown, signal: AbortSignal) {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify(body),
    signal,
  })
  if (!response.ok) {
    throw new Error(`${url} returned ${response.status}`)
  }
  return response.json() as Promise<any>
}

/**
 * The gpt-5 family accepts only the default temperature and rejects any other
 * value outright. Sending one fails the call, which on the safety path means
 * failing closed and showing every student the help screen. Omit it there and
 * let the model default.
 */
function acceptsTemperature(model: string): boolean {
  return !isReasoning(model)
}

function isReasoning(model: string): boolean {
  return model.includes('gpt-5')
}

async function openaiShaped(
  url: string,
  key: string,
  call: ProviderCall,
): Promise<ProviderReply> {
  const data = await postJson(
    url,
    key,
    {
      model: call.model,
      ...(acceptsTemperature(call.model) ? { temperature: call.temperature } : {}),
      ...(isReasoning(call.model) ? { reasoning_effort: call.reasoning } : {}),
      max_completion_tokens: call.maxTokens,
      // The audio models answer in text only when told so, and the json
      // response format is not documented for them, so the prompt asks for
      // JSON and the gateway strips any fence before parsing.
      ...(call.audio ? { modalities: ['text'] } : {}),
      ...(call.json && !call.audio ? { response_format: { type: 'json_object' } } : {}),
      messages: [
        { role: 'system', content: call.system },
        {
          role: 'user',
          content: call.audio
            ? [
                { type: 'text', text: call.user },
                {
                  type: 'input_audio',
                  input_audio: {
                    data: base64(call.audio.bytes),
                    format: audioFormat(call.audio.mimeType),
                  },
                },
              ]
            : call.user,
        },
      ],
    },
    call.signal,
  )

  return {
    text: data?.choices?.[0]?.message?.content ?? '',
    inputTokens: data?.usage?.prompt_tokens,
    outputTokens: data?.usage?.completion_tokens,
  }
}

export const providers: Record<
  ProviderName,
  (key: string, call: ProviderCall) => Promise<ProviderReply>
> = {
  openai: (key, call) =>
    openaiShaped('https://api.openai.com/v1/chat/completions', key, call),

  openrouter: (key, call) =>
    openaiShaped('https://openrouter.ai/api/v1/chat/completions', key, call),

  gemini: async (key, call) => {
    const url =
      `https://generativelanguage.googleapis.com/v1beta/models/` +
      `${call.model}:generateContent?key=${encodeURIComponent(key)}`

    const response = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: call.system }] },
        contents: [
          {
            role: 'user',
            parts: [
              { text: call.user },
              ...(call.audio
                ? [
                    {
                      inline_data: {
                        mime_type: call.audio.mimeType,
                        data: base64(call.audio.bytes),
                      },
                    },
                  ]
                : []),
            ],
          },
        ],
        generationConfig: {
          temperature: call.temperature,
          maxOutputTokens: call.maxTokens,
          ...(call.json ? { responseMimeType: 'application/json' } : {}),
        },
      }),
      signal: call.signal,
    })
    if (!response.ok) throw new Error(`gemini returned ${response.status}`)

    const data = (await response.json()) as any
    return {
      text: data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '',
      inputTokens: data?.usageMetadata?.promptTokenCount,
      outputTokens: data?.usageMetadata?.candidatesTokenCount,
    }
  },
}

/* ---------------------------------------------------------- embeddings -- */

/**
 * A vector for a piece of text, from OpenAI's embeddings endpoint.
 *
 * Only OpenAI. The column is sized to text-embedding-3-small, and a vector
 * from a second model would sit in the same column and mean something else,
 * so there is no fallback order here: a failure is a retry later, not a
 * different provider. The dimensions are sent explicitly so a model that
 * defaults wider is cut to the column rather than refused by it.
 */
export type EmbeddingCall = {
  text: string
  model: string
  dimensions: number
  signal: AbortSignal
}

export type EmbeddingReply = {
  vector: number[]
  inputTokens?: number
}

export async function openaiEmbedding(key: string, call: EmbeddingCall): Promise<EmbeddingReply> {
  const data = await postJson(
    'https://api.openai.com/v1/embeddings',
    key,
    {
      model: call.model,
      input: call.text,
      dimensions: call.dimensions,
      encoding_format: 'float',
    },
    call.signal,
  )

  const vector = data?.data?.[0]?.embedding
  if (!Array.isArray(vector) || vector.length !== call.dimensions) {
    throw new Error('embedding had the wrong shape')
  }

  return {
    vector: vector as number[],
    inputTokens: data?.usage?.prompt_tokens,
  }
}
