import { z } from 'zod'

/**
 * The shape the model must return for cue cards. Free prose is rejected
 * rather than stored, the same as every other structured call.
 *
 * Everything here is read by a student, so the checks are stricter than a
 * length. A card that fails one of them is not repaired, because the feature
 * is built on no card being an acceptable answer: nothing is lost by refusing
 * a bad one.
 */

/** Every dash, including the two that are not on a keyboard. */
const DASH = /[-–—]/

/**
 * One line a student reads.
 *
 * The dash check is here rather than in a review, because a dash in student
 * copy is a house rule and the only moment we can still refuse it is before
 * the row is written.
 */
function line(max: number) {
  return z
    .string()
    .trim()
    .min(1)
    .max(max)
    .refine((text) => !DASH.test(text), 'a dash reached copy a student reads')
}

/**
 * The openers that cannot be answered yes or no.
 *
 * A card now has one button for yes and one for no, so a question the student
 * cannot answer with either word is a card with nowhere to tap. These four
 * are the ones the old prompt kept producing when it was asked for a question
 * about what somebody wanted to do. Who, when and where are here for the same
 * reason: they ask for a fact back, not for a yes.
 */
const OPEN_QUESTION = /^(what|how|why|which|who|when|where)\b/i

/**
 * A question that ends by offering a choice between things.
 *
 * The three written options are gone and this is what stops them coming back
 * inside the question. Either word of a choice is a valid answer to the
 * choice and neither of them is yes or no, so a student reading "will you
 * tell Priya or start the poster" has two buttons and three answers.
 *
 * The word or catches the two item version and the second comma catches the
 * list. One comma is left alone, because a question can put the day in a
 * clause and still be one question.
 */
const OFFERS_A_CHOICE = /\bor\b/i
const IS_A_LIST = /,[^,]*,/

const card = z.object({
  /**
   * Which entry the card was drawn from, counting the numbered list the
   * model was given. A card that cannot name the entry it came from is a
   * card about nothing, and this is the number that gets checked against
   * the list before anything is stored.
   */
  from: z.number().int().min(1),
  about: line(120),
  /**
   * One question, and the student answers it with a yes or a no.
   *
   * What is checked here is the shape, because shape is all a regular
   * expression can see. Whether no is a real answer is the harder half of the
   * bar and it lives in the prompt, where it can be read as a sentence about
   * the student rather than as a pattern.
   */
  question: line(160)
    .refine((text) => text.endsWith('?'), 'the question did not end in a question mark')
    .refine((text) => (text.match(/\?/g) ?? []).length <= 1, 'a card asked more than one question')
    .refine((text) => !OPEN_QUESTION.test(text), 'the question cannot be answered yes or no')
    .refine((text) => !OFFERS_A_CHOICE.test(text), 'the question offered a choice rather than asking one thing')
    .refine((text) => !IS_A_LIST.test(text), 'the question ended in a list'),
})

export const cueCardsResult = z.object({
  /**
   * Empty is the common answer. Most days point at nothing.
   *
   * No length limit, because a count was never what a card had to clear. The
   * bar is in the prompt and it is about meaning: a thing the student named,
   * still open, still ahead of them, and worth a sentence back. A day with
   * three of those has three cards and a day with none has none. A number
   * here would put the old cap back in the one place nobody would look for
   * it, and would refuse the third card rather than the thin one.
   */
  cards: z.array(card),
})

export type CueCardsResult = z.infer<typeof cueCardsResult>
