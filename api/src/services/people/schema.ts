import { z } from 'zod'

/**
 * What the two people calls must return. Anything else is refused rather than
 * repaired, because a person invented by a model is the one failure this
 * feature cannot recover from: the student would have to argue with a record
 * of a conversation that never happened.
 */
const NO_DASH = /^[^-‐-―−]*$/

export const peopleResult = z.object({
  people: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(30).regex(NO_DASH),
        said: z.string().trim().min(1).max(600),
      }),
    )
    .max(8),
})

export type PeopleResult = z.infer<typeof peopleResult>

export const personProfileResult = z.object({
  relation: z.string().trim().max(60).regex(NO_DASH),
  profile: z.string().trim().max(600).regex(NO_DASH),
})

export type PersonProfileResult = z.infer<typeof personProfileResult>
