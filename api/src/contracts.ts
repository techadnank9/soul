import { z } from 'zod'

/**
 * The wire contract, shared with the client.
 *
 * Validation at the HTTP boundary only. Route handlers parse and then hand
 * plain values to a service. No service reaches for a request object.
 */

export const submitEntry = z.object({
  text: z.string().min(1).max(8000),
  inputMode: z.enum(['voice', 'typed']),
  transcriptConfirmed: z.boolean(),
  durationMs: z.number().int().positive().max(600_000).optional(),
  localHour: z.number().int().min(0).max(23).optional(),
})
export type SubmitEntry = z.infer<typeof submitEntry>

/**
 * Three shapes come back from a submission and the client must handle all
 * three. Held means consent did not cover this student and nothing left the
 * building. Help means the safety classifier flagged the entry and no
 * reflection was generated.
 */
export const submitResult = z.discriminatedUnion('state', [
  z.object({
    state: z.literal('reflected'),
    entryId: z.string().uuid(),
    line: z.string(),
  }),
  z.object({
    state: z.literal('help'),
    entryId: z.string().uuid(),
    heading: z.string(),
    body: z.string(),
    contacts: z.array(z.object({ label: z.string(), detail: z.string() })),
  }),
  z.object({
    state: z.literal('held'),
    entryId: z.string().uuid(),
  }),
])
export type SubmitResult = z.infer<typeof submitResult>

/**
 * The Mirror. Structured output, validated before display or storage. Free
 * prose is rejected rather than stored.
 */
export const mirrorResult = z.object({
  tension: z.string().min(1).max(400),
  underneath: z.string().min(1).max(400),
  question: z.string().min(1).max(200),
  offered: z.string().max(200).optional(),
  patternCandidate: z
    .object({
      candidateId: z.string().uuid(),
      proposal: z.string().min(1).max(400),
    })
    .optional(),
})
export type MirrorResult = z.infer<typeof mirrorResult>

export const createDecision = z.object({
  entryId: z.string().uuid(),
  offeredText: z.string().max(200).optional(),
  chosenText: z.string().min(1).max(200),
  horizonDays: z.number().int().min(1).max(30).default(3),
})

export const recordOutcome = z.object({
  decisionId: z.string().uuid(),
  whatHappened: z.string().max(2000).optional(),
  felt: z.enum(['lighter', 'same', 'worse']).optional(),
})

export const answerCandidate = z.object({
  candidateId: z.string().uuid(),
  answer: z.enum(['fits', 'not_the_same', 'later']),
  reason: z.string().max(500).optional(),
})

/** What the tagger must return. Anything else is discarded. */
export const taggerResult = z.object({
  trigger: z.string().max(120).nullable(),
  feeling: z.string().max(120).nullable(),
  coping: z.string().max(120).nullable(),
  domain: z.string().max(120).nullable(),
  confidence: z.number().min(0).max(1),
})

/** What the safety classifier must return. */
export const safetyResult = z.object({
  riskLevel: z.enum(['none', 'low', 'medium', 'high']),
  categories: z.array(z.string().max(60)).max(8),
})
