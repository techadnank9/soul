import { db, patternVerdicts } from '../../db.js'
import { call } from '../../gateway/call.js'
import { checkConsent } from '../../consent/gate.js'
import { verdictResult } from './schema.js'
import { evidenceFor, type ThemeNeedingVerdict } from './themes.js'
import type { Session } from '../../session.js'

/**
 * One theme, judged, and the sentence the student reads written for it.
 *
 * This is the call that decides whether the feature is kind or cruel, so what
 * it is allowed to say is set in the prompt and what it is allowed to return
 * is set in the schema beside this file. Nothing here rewrites what comes
 * back. A line that breaks a rule is refused and the theme keeps whatever it
 * had, which for most themes is nothing at all and no section.
 *
 * Never on the request path. It is a model call over a student's whole history
 * with a theme, it runs in the night from the job runner, and the screen reads
 * only the row it leaves behind.
 *
 * Whose verdict this is, is settled before the model is asked. A theme the
 * student has already answered about arrives here with that answer, the model
 * is told it, and the row is written as source outcomes. The model decides
 * only where they have not, and that row is written as source model. Their
 * answer changing later brings the theme back through here and a new row
 * replaces this one.
 */
export async function judgeTheme(theme: ThemeNeedingVerdict): Promise<boolean> {
  const session: Session = {
    studentId: theme.studentId,
    schoolId: theme.schoolId,
    districtId: theme.districtId,
  }

  /**
   * The gate, in front of the call, the way it is in front of every other
   * outbound call in the system.
   *
   * A student with no consent on file has no tags, because their entry was
   * held before it reached the tagger, so no theme of theirs can reach this
   * function at all. This is here anyway. It is one query, nobody is waiting
   * for it, and invariant 2 should hold because this file checks rather than
   * because a join three files away happens to be empty.
   */
  if (!(await checkConsent(session, 'third_party_processing'))) return false

  const evidence = await evidenceFor(theme.studentId, theme.theme)

  // Two entries is the floor, and the query already applied it. A theme that
  // lost an entry between the two queries is not worth a call.
  if (evidence.entries.length < 2) return false

  const result = await call('pattern_verdict', {
    user: promptFor(theme, evidence),
    schema: verdictResult,
    session,
  })

  /**
   * Unsettled is a real answer and it is written down like the other two.
   *
   * The theme stays a thing that keeps returning, in neither section and with
   * no sentence, and the row is what stops it being asked about again every
   * night until some run happens to say something. It is asked again when the
   * theme grows or when the student answers a check back about it, which are
   * the two things that would actually change the answer.
   */
  const unsettled = result.value.verdict === 'unsettled'

  await db.insert(patternVerdicts).values({
    studentId: theme.studentId,
    schoolId: theme.schoolId,
    districtId: theme.districtId,
    theme: theme.theme,
    /**
     * The student's own verdict wins, always.
     *
     * The model was writing its own answer into this column even where the
     * student's outcomes had already said lighter or worse, which is the one
     * thing this feature cannot do: it marks the row as coming from the
     * student and then stores what the model thought instead. The model is
     * only ever asked for the sentence in that case.
     */
    verdict: theme.studentVerdict ?? result.value.verdict,
    // Not what the model returned. Where the student answered, the verdict is
    // theirs and the model only wrote the sentence, and the row has to say so
    // because the screen prints where a verdict came from.
    source: theme.studentVerdict ? 'outcomes' : 'model',
    // Empty exactly when the verdict is unsettled, which is the one case
    // where there is nothing for a student to read.
    line: result.value.line,
    // What the line was written about. A theme that grows past this number is
    // judged again, because the sentence was written without the entries that
    // arrived since.
    supporting: theme.supporting,
    promptVersion: result.promptVersion,
    modelVersion: result.model,
  })

  return !unsettled
}

/**
 * What the model is shown. Their words, their dates, their answers.
 *
 * The verdict line is the one that matters. good or bad means the student
 * already decided by what they said after doing something about it, and the
 * prompt tells the model to return that verdict unchanged and write only the
 * sentence. unsettled is the only case where the model decides anything.
 */
function promptFor(
  theme: ThemeNeedingVerdict,
  evidence: Awaited<ReturnType<typeof evidenceFor>>,
): string {
  const entries = evidence.entries
    .map((entry, index) => `${index + 1}. ${entry.at}\n${entry.text}`)
    .join('\n\n')

  const outcomes = evidence.outcomes.length
    ? evidence.outcomes
        .map((outcome) => {
          const said = outcome.whatHappened ? `\nthey said: ${outcome.whatHappened}` : ''
          return `they did: ${outcome.chose}${said}\nit left them: ${outcome.felt}`
        })
        .join('\n\n')
    : 'none. They have not said how anything about this went.'

  return [
    `theme: ${theme.theme}`,
    `verdict: ${theme.studentVerdict ?? 'unsettled'}`,
    '',
    'entries, oldest first:',
    entries,
    '',
    'outcomes:',
    outcomes,
  ].join('\n')
}
