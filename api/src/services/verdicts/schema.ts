import { z } from 'zod'

/** Every dash, including the two that are not on a keyboard. */
const DASH = /[-–—]/

/**
 * What the verdict model must return. Anything else is refused by the gateway
 * and the theme keeps whatever it had, which is usually nothing.
 *
 * unsettled is a real answer and it is the reason this schema does not simply
 * demand good or bad. A theme the entries do not carry a verdict for is shown
 * in neither section, and forcing a choice here would put a sentence about
 * stopping something under a theme nobody had grounds to judge.
 *
 * The line is capped short because it is one sentence read under a heading on
 * a phone. It is empty exactly when the verdict is unsettled, and the refine
 * is what stops a good verdict arriving with nothing to print.
 */
export const verdictResult = z
  .object({
    verdict: z.enum(['good', 'bad', 'unsettled']),
    line: z
      .string()
      .trim()
      .max(240)
      // The house rule, checked at the last moment it can still be refused.
      // A theme with no line is shown in neither section, which is a smaller
      // failure than a dash on a screen a student reads.
      .refine((text) => !DASH.test(text), 'a dash reached copy a student reads'),
  })
  .refine((v) => v.verdict === 'unsettled' || v.line.length > 0, {
    message: 'a verdict has to come with the line the student reads',
    path: ['line'],
  })

export type VerdictResult = z.infer<typeof verdictResult>
