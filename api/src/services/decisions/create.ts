import { db, decisions } from '../../db.js'
import { enqueue, inDays } from '../../jobs/enqueue.js'
import type { Session } from '../../session.js'

/**
 * Flow 3. The decision.
 *
 * Two columns, never merged. offered_text is what the Mirror suggested,
 * chosen_text is what the student actually wrote. The gap between them is the
 * most interesting data in the system.
 */
export async function createDecision(
  session: Session,
  input: {
    entryId: string
    offeredText?: string
    chosenText: string
    horizonDays: number
  },
): Promise<string> {
  const horizon = inDays(input.horizonDays)

  const rows = await db
    .insert(decisions)
    .values({
      entryId: input.entryId,
      studentId: session.studentId,
      schoolId: session.schoolId,
      districtId: session.districtId,
      offeredText: input.offeredText ?? null,
      chosenText: input.chosenText,
      horizon,
    })
    .returning({ id: decisions.id })

  const row = rows[0]
  if (!row) throw new Error('decision insert returned no row')

  // Days later, on the day the student named. A durable job, because it has to
  // survive every deploy between now and then.
  await enqueue('check_back', { decisionId: row.id }, session, horizon)

  return row.id
}
