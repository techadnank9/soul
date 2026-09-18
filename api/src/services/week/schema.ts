import { z } from 'zod'

/** Every dash, including the two that are not on a keyboard. */
const DASH = /[-–—]/

/**
 * What the week notes model must return. Three sentences, each short, each
 * free of the marks the house does not print. A reply that fails is refused
 * and the person keeps last week's card, which is a smaller failure than a
 * dash on the screen they open every day.
 */
export const weekNotesResult = z.object({
  lines: z
    .array(
      z
        .string()
        .trim()
        .min(1)
        .max(220)
        .refine((text) => !DASH.test(text), 'a dash reached copy a person reads')
        .refine((text) => !/!/.test(text), 'an exclamation mark reached copy a person reads'),
    )
    .min(1)
    .max(3),
})

export type WeekNotesResult = z.infer<typeof weekNotesResult>
