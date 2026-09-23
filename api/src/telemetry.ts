import tracer from 'dd-trace'

/**
 * Datadog, agentless.
 *
 * Render runs one container per service and no sidecar, so there is no
 * Datadog Agent to talk to. Agentless sends straight to the intake with the
 * api key, which is the only shape that works here.
 *
 * Imported first, before anything else in the process, because the tracer
 * patches http, postgres and fetch as they are loaded and cannot patch what
 * is already in memory.
 *
 * Off unless `DD_API_KEY` is set, the same way Sentry is off without a DSN,
 * so a laptop and a build made by hand send nothing.
 *
 * ## What it may see, which is the part that mattered
 *
 * Nothing a person wrote.
 *
 * LLM Observability is on and every model call is a span, but the prompts
 * and the replies are not on those spans. Datadog captures those by
 * instrumenting a vendor sdk, and this gateway has never used one: every
 * call is a `fetch` to an https endpoint, so there is nothing for it to hook
 * and nothing is captured by default. The spans are written by hand in
 * `gateway/call.ts` and carry the purpose, the model, the provider, the
 * token counts, the latency and whether it failed. Not the entry, not the
 * history, not the line that came back.
 *
 * That is deliberate and it is the condition of Datadog being here at all.
 * The rule this product runs on is that a person can see and delete
 * everything held about them, and a prompt sitting in a third party's trace
 * store is a thing they cannot reach. Anybody adding a payload to one of
 * these spans is undoing that, and should read decision 302 first.
 *
 * Request bodies are not captured either: apm tracing records the route, the
 * status and the timing of an http span, never the body.
 */
export function startTelemetry(service: string): void {
  if (!process.env.DD_API_KEY) return

  // Agentless is read from the environment rather than passed in: the option
  // exists in the tracer but not in its types, and setting the variable is
  // the supported way in. Set here rather than in render.yaml so a laptop
  // that exports a key behaves the same as the service.
  process.env.DD_AGENTLESS_ENABLED ??= 'true'
  process.env.DD_APM_TRACING_AGENTLESS_ENABLED ??= 'true'
  process.env.DD_LLMOBS_AGENTLESS_ENABLED ??= 'true'

  // Logs are not shipped from here. Agentless submits pino, bunyan and
  // winston lines by default, and this process writes with console, so
  // nothing goes either way today. It is set off so that adding a logger
  // later cannot quietly start sending every line to Datadog without
  // somebody deciding to.
  process.env.DD_AGENTLESS_LOG_SUBMISSION_ENABLED ??= 'false'

  tracer.init({
    service,
    env: process.env.RENDER ? 'render' : 'laptop',

    // The git sha, so a trace says which deploy it came from and Datadog can
    // show a change in latency against the commit that caused it. Render
    // puts the sha here and Sentry already uses it as its release.
    version: process.env.RENDER_GIT_COMMIT,

    // Event loop lag, heap, garbage collection. The numbers that say whether
    // the worker is keeping up, which nothing else here measures.
    runtimeMetrics: true,

    // The trace id goes into every log line, so a line in the Render log can
    // be opened as the request it belongs to.
    logInjection: true,

    llmobs: {
      mlApp: 'soul',
      agentlessEnabled: true,
    },
  })
}

export { tracer }

/**
 * One model call, as a span.
 *
 * Written by hand rather than captured, which is the whole point. Datadog
 * captures prompts and replies by instrumenting a vendor sdk, and this
 * gateway calls the endpoints with `fetch`, so there is nothing to hook and
 * nothing is taken unless it is put here.
 *
 * What is here: what the call was for, which model answered, how long it
 * took, how many tokens it cost. Enough to see that the tagger takes twenty
 * seconds, that a prompt version changed the token count, that one provider
 * fails more than another.
 *
 * What is not here, and must not be added: the prompt, the reply, the entry,
 * the history, the person. Decision 302.
 */
export function recordModelCall(call: {
  purpose: string
  provider: string
  model: string
  promptVersion: string
  latencyMs: number
  inputTokens?: number
  outputTokens?: number
}): void {
  if (!process.env.DD_API_KEY) return

  try {
    const llmobs = obs()
    if (!llmobs) return

    llmobs.trace(
      {
        kind: 'llm',
        name: call.purpose,
        modelName: call.model,
        modelProvider: call.provider,
      },
      (span: unknown) => {
        llmobs.annotate(span, {
          tags: {
            purpose: call.purpose,
            provider: call.provider,
            model: call.model,
            prompt_version: call.promptVersion,
          },
          metrics: {
            ...(call.inputTokens === undefined ? {} : { inputTokens: call.inputTokens }),
            ...(call.outputTokens === undefined ? {} : { outputTokens: call.outputTokens }),
          },
        })
      },
    )
  } catch {
    // Telemetry is never the reason a reflection fails.
  }
}

/** Every provider refused. The purpose and the reasons, no payload. */
export function recordModelFailure(purpose: string, why: string): void {
  if (!process.env.DD_API_KEY) return

  try {
    const span = tracer.startSpan('llm.failed')
    span.setTag('purpose', purpose)
    span.setTag('error', true)
    span.setTag('error.message', why.slice(0, 500))
    span.finish()
  } catch {
    // As above.
  }
}

/**
 * A whole piece of work, with the model calls inside it.
 *
 * Without this every call is its own trace with no parent, so Datadog shows
 * a list of spans and nothing about what they were for. Submitting one entry
 * runs the safety classifier and then beat one, and the useful question is
 * how long that took a person to wait for, not how long one of them took.
 * The jobs are the same: tagging an entry books six more, and a trace is
 * where you see which of them is the slow one.
 *
 * `workflow` is the LLM Observability kind for exactly this. Decision 302.
 */
export function withWorkflow<T>(
  name: string,
  tags: Record<string, string>,
  work: () => Promise<T>,
): Promise<T> {
  const llmobs = obs()
  if (!llmobs) return work()

  try {
    return llmobs.trace({ kind: 'workflow', name }, (span: unknown) => {
      try {
        llmobs.annotate(span, { tags })
      } catch {
        // A tag is never the reason the work does not run.
      }
      return work()
    }) as Promise<T>
  } catch {
    return work()
  }
}

function obs(): LlmObs | null {
  if (!process.env.DD_API_KEY) return null
  return (tracer as unknown as { llmobs?: LlmObs }).llmobs ?? null
}

type LlmObs = {
  trace: (options: Record<string, unknown>, fn: (span: unknown) => unknown) => unknown
  annotate: (span: unknown, data: Record<string, unknown>) => void
}
