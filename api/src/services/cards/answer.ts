import { sql } from '../../db.js'
import { inDays } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'

/**
 * Answering a cue card. Yes or no, and whatever they wrote in the box.
 *
 * A yes is a thing the student said they would do, so it becomes a decision,
 * written the way the Mirror writes one, and the check back that follows is
 * the existing one rather than a second copy of it. A decision made from a
 * card and a decision made from the Mirror are the same thing everywhere
 * downstream.
 *
 * A no ends here. Nothing is written but the answer and the box, and nothing
 * is booked, because a student who says no has answered the question. Coming
 * back in three days to ask how it went would be the app not listening.
 */
type CardRow = {
  entry_id: string
  question: string
  answered_at: string | null
}

/**
 * Three ways this ends, and the route turns each one into a status.
 *
 * A card that is not this student's is not found rather than forbidden.
 * Forbidden would tell a stranger that the id they guessed is real.
 *
 * decisionId is null on a no, which is not a failure. It is the answer.
 */
export type AnswerCardResult =
  | { ok: true; decisionId: string | null }
  | { ok: false; reason: 'not_found' | 'already_answered' }

export async function answerCard(
  session: Session,
  input: {
    cardId: string
    answer: 'yes' | 'no'
    detail?: string
    horizonDays: number
  },
): Promise<AnswerCardResult> {
  return sql.begin(async (tx) => {
    /**
     * Locked for the length of this, because the row is claimed by writing
     * the decision onto it and the decision has to exist first. Without the
     * lock a student tapping twice writes two decisions and is asked about
     * the same thing twice, days later.
     */
    const rows = await tx<CardRow[]>`
      select entry_id, question, answered_at
      from cue_cards
      where id = ${input.cardId}
        and student_id = ${session.studentId}
      limit 1
      for update`

    const card = rows[0]
    if (!card) return { ok: false, reason: 'not_found' }
    if (card.answered_at) return { ok: false, reason: 'already_answered' }

    // An empty box is nothing said, not an empty thing said. The contract has
    // already trimmed it, so what is left here is either words or nothing.
    const detail = input.detail && input.detail.length > 0 ? input.detail : null

    if (input.answer === 'no') {
      // The answer is written down rather than left to be worked out later.
      // A no is a card with an answer, a time, sometimes a sentence, and no
      // decision, and reading the no off the missing decision would turn every
      // one of these rows into a lie the first time a yes fails to write one.
      await tx`
        update cue_cards
        set answered_yes = false,
            detail = ${detail},
            answered_at = now()
        where id = ${input.cardId}
          and student_id = ${session.studentId}`

      return { ok: true, decisionId: null }
    }

    /**
     * The question, word for word, is what they said yes to.
     *
     * Turning it into a statement would read better on the home screen and it
     * would be a sentence the student never saw. They answered these words,
     * so these are the words the check back asks them about days later.
     *
     * offered_text stays empty. It exists for the gap between what was put in
     * front of a student and what they did instead, and on a yes there is no
     * gap: the offer and the answer are one sentence, and writing it into
     * both columns would claim a difference that is not there.
     */
    const chosen = asSomethingTheyWillDo(card.question)

    /**
     * Written on this transaction's own connection, not through the pooled
     * handle.
     *
     * Calling createDecision from in here asked the pool for a second
     * connection while this one was held open. Ten students answering at once
     * held all ten connections and every one of them waited for an eleventh,
     * which never came: the whole API stopped, permanently, and only a restart
     * cleared it.
     *
     * The cost of doing it here is that the decision insert and the check back
     * are written twice in this codebase. The gain is that the card, the
     * decision and the job commit together or not at all, which is what the
     * comment below always claimed and could not deliver across two
     * connections.
     */
    const horizon = inDays(input.horizonDays)

    const decisions = await tx<{ id: string }[]>`
      insert into decisions
        (entry_id, student_id, school_id, district_id, chosen_text, horizon)
      values (
        ${card.entry_id}, ${session.studentId}, ${session.schoolId},
        ${session.districtId}, ${chosen}, ${horizon.toISOString()}
      )
      returning id`

    const decisionId = decisions[0]?.id
    if (!decisionId) throw new Error('decision insert returned no row')

    // Days later, on the day the student named. The same durable job the
    // Mirror path books, so a decision made from a card is checked back on in
    // exactly the same way.
    await tx`
      insert into jobs (type, payload, student_id, school_id, district_id, run_at)
      values (
        'check_back',
        ${JSON.stringify({ decisionId })},
        ${session.studentId}, ${session.schoolId}, ${session.districtId},
        ${horizon.toISOString()}
      )`

    // The answer time and the decision are written in the same transaction, so
    // a card that reads as answered always carries the decision it produced.
    await tx`
      update cue_cards
      set answered_yes = true,
          detail = ${detail},
          decision_id = ${decisionId},
          answered_at = now()
      where id = ${input.cardId}
        and student_id = ${session.studentId}`

    return { ok: true, decisionId }
  }) as Promise<AnswerCardResult>
}

/**
 * The question, turned into the thing they just said yes to.
 *
 * The question went into the decision word for word, so home asked "you were
 * holding this" over "Will you tell Priya before Friday?", and days later the
 * check back asked how the question went. A student says yes to doing a thing,
 * not to being asked, and the row should hold the thing.
 *
 * Anything this does not recognise is kept as it is. A decision that reads a
 * little stiffly is better than one this mangled.
 */
export function asSomethingTheyWillDo(question: string): string {
  const openers = [
    /^will you /i,
    /^are you going to /i,
    /^can you /i,
    /^could you /i,
    /^do you want to /i,
    /^would you /i,
  ]

  let text = question.trim()
  for (const opener of openers) {
    if (opener.test(text)) {
      text = text.replace(opener, '')
      break
    }
  }
  if (text === question.trim()) return question.trim()

  text = text.replace(/\?+$/, '').trim()
  if (!text) return question.trim()

  return text.charAt(0).toUpperCase() + text.slice(1)
}
