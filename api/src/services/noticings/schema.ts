import { z } from 'zod'
import { forgivingList } from '../../contracts.js'

/** Every dash, including the two that are not on a keyboard. */
const DASH = /[-–—]/

/**
 * What the noticings model must return. Anything else is refused by the
 * gateway and the person keeps what they had, which on day one is nothing.
 *
 * Two at most across kept and new, checked here rather than trusted. The
 * numbers point at the entries and the open noticings the prompt was given,
 * and the job turns them back into ids; a number that points at nothing is
 * dropped there rather than refused here, because one bad reference should
 * not cost the other noticing.
 */
export const noticingsResult = z
  .object({
    kept: z.array(z.number().int().min(1)).max(2),
    noticings: forgivingList(
      z.object({
          line: z
            .string()
            .trim()
            .min(1)
            .max(320)
            .refine((text) => !DASH.test(text), 'a dash reached copy a person reads')
            .refine((text) => !/[!]/.test(text), 'an exclamation mark reached copy a person reads'),
          lean: z.enum(['good', 'bad', 'open']),
        entries: z.array(z.number().int().min(1)).min(1).max(12),
      }),
      2,
    ),
  })
  .refine((v) => v.kept.length + v.noticings.length <= 2, {
    message: 'two noticings at most, kept and new together',
    path: ['noticings'],
  })

export type NoticingsResult = z.infer<typeof noticingsResult>
