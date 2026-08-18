import type { ZodType } from 'zod'
import { db, generations } from '../db.js'
import { env } from '../env.js'
import type { Session } from '../session.js'
import { activePrompt, type Purpose } from './prompts.js'
import { providers, type ProviderName, type ProviderCall } from './providers.js'

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
    maxTokens: 200,
    timeoutMs: 4000,
    json: true,
  },
  beat_one: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5-mini',
      gemini: 'gemini-2.5-flash',
      openrouter: 'openai/gpt-5-mini',
    },
    temperature: 0.6,
    maxTokens: 120,
    timeoutMs: 6000,
    json: false,
  },
  mirror: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5',
      gemini: 'gemini-2.5-pro',
      openrouter: 'openai/gpt-5',
    },
    temperature: 0.7,
    maxTokens: 700,
    timeoutMs: 20_000,
    json: true,
  },
  tagger: {
    order: ['openai', 'gemini', 'openrouter'],
    model: {
      openai: 'gpt-5-mini',
      gemini: 'gemini-2.5-flash',
      openrouter: 'openai/gpt-5-mini',
    },
    temperature: 0,
    maxTokens: 300,
    timeoutMs: 15_000,
    json: true,
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
    value = JSON.parse(raw)
  } catch {
    throw new GatewayError('reply was not json')
  }
  const result = schema.safeParse(value)
  if (!result.success) throw new GatewayError('reply did not match the schema')
  return result.data
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
        signal: controller.signal,
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
