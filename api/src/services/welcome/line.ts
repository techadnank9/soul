import { call } from '../../gateway/call.js'
import { welcomeResult, type WelcomeAnswers } from '../../contracts.js'
import type { Session } from '../../session.js'

/**
 * The line on the last screen of first run, written from what was just
 * answered.
 *
 * The questions live in the app, not here, so the app sends the pairs it
 * showed rather than this service keeping a second copy of a set that would
 * drift from the first. They are the person's own answers either way.
 *
 * The prompt is told situations never traits, no praise and no score, which
 * is the same voice every other line in the product is written in.
 */
export async function welcomeLine(
  session: Session,
  input: WelcomeAnswers,
): Promise<string> {
  const said = input.answers
    .map((a) => `${a.question}\n  they chose: ${a.answer}`)
    .join('\n\n')

  const result = await call('welcome', {
    user: input.name ? `Their name is ${input.name}.\n\n${said}` : said,
    schema: welcomeResult,
    session,
  })

  return result.value.line
}
