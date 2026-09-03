import type { ZodType } from 'zod'
import { db, generations, EMBEDDING_DIMENSIONS } from '../db.js'
import { env } from '../env.js'
import type { Session } from '../session.js'
import { activePrompt, type Purpose } from './prompts.js'
import {
  providers,
  openaiEmbedding,
  type ProviderName,
  type ProviderCall,
} from './providers.js'

/**
 * Every model call in the system goes through this file. Nothing calls a
 * provider directly. If you need a model call, add a purpose below. Do not add
 * an SDK import.
 *
 * The gateway does five things and they are all load bearing:
 *   loads the prompt from the database
 *   tries the providers in order
 *   validates the reply against the purpose's schema
 *   writes a generations row with prompt version and model version
 *   returns a typed value or throws
 */

type PurposeConfig = {
  order: ProviderName[]
  model: Record<ProviderName, string>
  temperature: number
  maxTokens: number
  timeoutMs: number
  json: boolean
  reasoning: 'minimal' | 'low' | 'medium' | 'high'
}

/**
 * Provider order is OpenAI, then Gemini, then OpenRouter.
 *
 * Safety runs on a small fast model and has the shortest timeout, because it
 * blocks the write path and a slow classifier is a slow product. Beat one is
 * next, because under three seconds is the target the whole screen is built
 * around.
 */
const config: Record<Purpose, PurposeConfig> = {
  safety: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5-mini',
      gemini: 'gemini-2.5-flash',
      openrouter: 'openai/gpt-5-mini',
    },
    temperature: 0,
    // Reasoning tokens come out of this budget, so it has to cover the
    // thinking as well as the answer. Two hundred was all thinking and no
    // reply, which failed closed and showed every student the help screen.
    maxTokens: 2000,
    timeoutMs: 15_000,
    json: true,
    // Low rather than minimal. This call decides whether a student in trouble
    // is seen, and it is worth a few hundred milliseconds to let it think.
    reasoning: 'low',
  },
  beat_one: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0.6,
    maxTokens: 2000,
    timeoutMs: 20_000,
    json: false,
    // The full model, still thinking as little as it is allowed to. Task 7
    // says a generic first line kills the product, so this is the one place
    // worth spending on quality even though it is on the latency path.
    reasoning: 'minimal',
  },
  mirror: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0.7,
    maxTokens: 8000,
    timeoutMs: 120_000,
    json: true,
    // Medium. This is the call the product is judged on, and the student asked
    // for it, so it is allowed to take its time. The client shows that it is
    // working rather than a blank screen.
    reasoning: 'medium',
  },
  tagger: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0,
    maxTokens: 3000,
    timeoutMs: 60_000,
    json: true,
    // Everything downstream is built on these tags, and nobody is waiting.
    reasoning: 'medium',
  },
  /**
   * The verdict on a theme, and the sentence a student reads under it.
   *
   * Zero temperature. This call says whether repeating something is doing a
   * student good or costing them, and a warmer setting buys a nicer sentence
   * at the price of the same theme being judged one way tonight and the other
   * way next week.
   */
  /**
   * Reading names out of one entry. Small, exact, and off the latency path.
   *
   * Temperature zero because there is a right answer: the names in the text.
   * Low reasoning because the failure here is not shallow thinking, it is
   * inventing somebody, and the prompt is what holds that.
   */
  people: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5-mini',
      gemini: 'gemini-2.5-flash',
      openrouter: 'openai/gpt-5-mini',
    },
    temperature: 0,
    maxTokens: 2000,
    timeoutMs: 60_000,
    json: true,
    reasoning: 'low',
  },

  /**
   * Writing about somebody who is not a user of this product and cannot read
   * what is written. The full model, thinking, because the difference between
   * what happened and what somebody is like is the whole job and it is not an
   * easy line to hold.
   */
  person_profile: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0.2,
    maxTokens: 4000,
    timeoutMs: 120_000,
    json: true,
    reasoning: 'medium',
  },

  pattern_verdict: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0,
    maxTokens: 4000,
    timeoutMs: 120_000,
    json: true,
    // Medium, and nobody is waiting. The hardest part of this call is
    // deciding that a theme is not yet worth a verdict, which is the answer
    // it gets wrong when it is hurried, the same way the cue card call does.
    reasoning: 'medium',
  },
  /**
   * How a spoken entry sounded. The only call that hears audio.
   *
   * It runs on the transcribe path, in parallel with the transcriber, so it
   * costs the student no extra wait, and it has to finish inside the time a
   * transcript takes. OpenRouter is not in the order because audio input
   * there depends on the model behind it, and a call that silently reads
   * nothing is worse than one that fails over to Gemini.
   */
  voice_tone: {
    order: ['openai', 'gemini'],
    model: {
      openai: 'gpt-audio-1.5',
      gemini: 'gemini-2.5-flash',
      openrouter: 'openai/gpt-audio-1.5',
    },
    temperature: 0.2,
    maxTokens: 1000,
    timeoutMs: 20_000,
    json: true,
    reasoning: 'low',
  },
  /**
   * The facts in one entry, closed against the facts already held.
   *
   * Zero temperature because the output is a record, not a line: the same
   * entry read twice should yield the same facts. Medium reasoning because
   * the hard part is noticing that what they said now closes something they
   * said in March, and that is a comparison rather than a summary. Nobody is
   * waiting for it.
   */
  facts: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0,
    maxTokens: 4000,
    timeoutMs: 120_000,
    json: true,
    reasoning: 'medium',
  },
  cue_cards: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    // Low, because a card has to quote the student rather than invent a
    // better sentence than the one they wrote.
    temperature: 0.3,
    maxTokens: 8000,
    timeoutMs: 120_000,
    json: true,
    // The longest timeout and the same thinking as the Mirror. This call
    // reads a week of entries and its main job is deciding that most of them
    // point at nothing, which is the answer it gets wrong when it is hurried.
    // Nobody is waiting for it.
    reasoning: 'medium',
  },
}

function keyFor(provider: ProviderName): string | undefined {
  return {
    openai: env.providers.openaiKey,
    gemini: env.providers.geminiKey,
    openrouter: env.providers.openrouterKey,
  }[provider]
}

export class GatewayError extends Error {}

/**
 * parseStructured rejects rather than storing free prose.
 *
 * A model that answers a JSON request with a sentence has failed, and storing
 * the sentence would put unvalidated text in front of a student. The call
 * falls through to the next provider instead.
 */
function parseStructured<T>(schema: ZodType<T>, raw: string): T {
  let value: unknown
  try {
    value = JSON.parse(unfence(raw))
  } catch {
    throw new GatewayError('reply was not json')
  }
  const result = schema.safeParse(value)
  if (!result.success) throw new GatewayError('reply did not match the schema')
  return result.data
}

/**
 * A model that was not given a json response format sometimes wraps its
 * answer in a code fence. The fence is not the answer.
 */
function unfence(raw: string): string {
  const trimmed = raw.trim()
  const match = /^```(?:json)?\s*([\s\S]*?)\s*```$/.exec(trimmed)
  return match ? match[1]! : trimmed
}

export type GatewayResult<T> = {
  value: T
  provider: ProviderName
  model: string
  promptVersion: string
  latencyMs: number
}

export async function call<T>(
  purpose: Purpose,
  input: {
    user: string
    schema?: ZodType<T>
    session: Session
    entryId?: string
    audio?: { bytes: Uint8Array; mimeType: string }
  },
): Promise<GatewayResult<T>> {
  const settings = config[purpose]
  const prompt = await activePrompt(purpose)
  const failures: string[] = []

  for (const provider of settings.order) {
    const key = keyFor(provider)
    if (!key) {
      failures.push(`${provider}: no key configured`)
      continue
    }

    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), settings.timeoutMs)
    const startedAt = Date.now()

    try {
      const request: ProviderCall = {
        system: prompt.text,
        user: input.user,
        model: settings.model[provider],
        temperature: settings.temperature,
        maxTokens: settings.maxTokens,
        json: settings.json,
        reasoning: settings.reasoning,
        signal: controller.signal,
        ...(input.audio ? { audio: input.audio } : {}),
      }

      const reply = await providers[provider](key, request)
      const latencyMs = Date.now() - startedAt

      const value = input.schema
        ? parseStructured(input.schema, reply.text)
        : (reply.text.trim() as unknown as T)

      if (!input.schema && !String(value).trim()) {
        throw new GatewayError('empty reply')
      }

      // Written for every call. This is how you tell whether a prompt change
      // helped, and it is the only record that a given student saw a given
      // version of a given model.
      await db.insert(generations).values({
        entryId: input.entryId ?? null,
        studentId: input.session.studentId,
        schoolId: input.session.schoolId,
        districtId: input.session.districtId,
        purpose,
        promptVersion: prompt.version,
        modelVersion: settings.model[provider],
        provider,
        latencyMs,
        inputTokens: reply.inputTokens ?? null,
        outputTokens: reply.outputTokens ?? null,
      })

      return {
        value,
        provider,
        model: settings.model[provider],
        promptVersion: prompt.version,
        latencyMs,
      }
    } catch (error) {
      failures.push(`${provider}: ${(error as Error).message}`)
    } finally {
      clearTimeout(timer)
    }
  }

  throw new GatewayError(`every provider failed for ${purpose}. ${failures.join('; ')}`)
}

/* ---------------------------------------------------------- embeddings -- */

/**
 * The one model the vectors in this database come from.
 *
 * Every entry embedding and every fact embedding has to come from the same
 * model, because a distance between vectors from two models means nothing.
 * Changing this is a fresh embedding of every row, not a config change, which is why
 * it is a constant here and recorded on every row as model_version.
 */
export const EMBEDDING_MODEL = 'text-embedding-3-small'
const EMBEDDING_TIMEOUT_MS = 30_000

export type EmbeddingResult = {
  vector: number[]
  model: string
  latencyMs: number
}

/**
 * A vector for a piece of text.
 *
 * The other half of the gateway. It goes through this file for the same
 * reason every chat call does: one place that names every provider a
 * student's words can reach, and a generations row for every time they do.
 *
 * There is no prompt, so the row carries the word none as its prompt
 * version rather than a version that does not exist. There is no schema
 * either, because the reply is numbers and the check is that there are the
 * right number of them.
 */
export async function embed(input: {
  text: string
  session: Session
  entryId?: string
}): Promise<EmbeddingResult> {
  const key = keyFor('openai')
  if (!key) throw new GatewayError('embedding failed. openai: no key configured')

  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), EMBEDDING_TIMEOUT_MS)
  const startedAt = Date.now()

  try {
    const reply = await openaiEmbedding(key, {
      text: input.text,
      model: EMBEDDING_MODEL,
      dimensions: EMBEDDING_DIMENSIONS,
      signal: controller.signal,
    })
    const latencyMs = Date.now() - startedAt

    await db.insert(generations).values({
      entryId: input.entryId ?? null,
      studentId: input.session.studentId,
      schoolId: input.session.schoolId,
      districtId: input.session.districtId,
      purpose: 'embedding',
      promptVersion: 'none',
      modelVersion: EMBEDDING_MODEL,
      provider: 'openai',
      latencyMs,
      inputTokens: reply.inputTokens ?? null,
      outputTokens: null,
    })

    return { vector: reply.vector, model: EMBEDDING_MODEL, latencyMs }
  } catch (error) {
    throw new GatewayError(`embedding failed. openai: ${(error as Error).message}`)
  } finally {
    clearTimeout(timer)
  }
}
