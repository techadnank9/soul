import { and, eq, inArray } from 'drizzle-orm'
import { db, noticings, sql } from '../../db.js'
import { call } from '../../gateway/call.js'
import { checkConsent } from '../../consent/gate.js'
import { noticingsResult } from './schema.js'
import type { Session } from '../../session.js'

/**
 * Something the app may be noticing, written from everything the person has
 * said so far. Decision 278.
 *
 * A pattern needs the same coping across three entries and most people
 * never get there, so the returning tab said nothing has repeated yet to
 * almost everybody, for weeks. This runs after every tagged entry, from the
 * first one, and offers back at most two hedged noticings with the entries
 * they came from. Yes, no and not sure are equal answers, and the person's
 * answer is the end of it: a confirmed noticing stays on the screen, a
 * rejected one is shown to the model as a thing not to say again.
 *
 * Off the request path. The person already has beat one by the time this
 * runs, and the tab reads only the rows it leaves behind.
 */
const RECENT_ENTRIES = 12
const REJECTED_SHOWN = 8

export async function writeNoticings(session: Session): Promise<number> {
  // The gate, in front of the call, the way it is in front of every other
  // outbound call in the system.
  if (!(await checkConsent(session, 'third_party_processing'))) return 0

  const entries = await sql<{ id: string; at: string; text: string }[]>`
    select id, to_char(created_at at time zone 'UTC', 'YYYY-MM-DD') as at, text
    from (
      select id, created_at, text from entries
      where student_id = ${session.studentId} and processed = true
      order by created_at desc
      limit ${RECENT_ENTRIES}
    ) recent
    order by created_at`
  if (entries.length === 0) return 0

  const open = await db
    .select({ id: noticings.id, line: noticings.line })
    .from(noticings)
    .where(and(eq(noticings.studentId, session.studentId), eq(noticings.status, 'open')))
    .orderBy(noticings.createdAt)

  const refused = await sql<{ line: string }[]>`
    select line from noticings
    where student_id = ${session.studentId} and status = 'rejected'
    order by answered_at desc
    limit ${REJECTED_SHOWN}`

  const result = await call('noticings', {
    user: promptFor(entries, open, refused),
    schema: noticingsResult,
    session,
  })

  // The numbers back into ids. A number that points at nothing is dropped,
  // and a noticing with no entries left under it is dropped with it.
  const kept = new Set(
    result.value.kept
      .map((number) => open[number - 1]?.id)
      .filter((id): id is string => Boolean(id)),
  )
  const fresh = result.value.noticings
    .map((noticing) => ({
      ...noticing,
      entryIds: noticing.entries
        .map((number) => entries[number - 1]?.id)
        .filter((id): id is string => Boolean(id)),
    }))
    .filter((noticing) => noticing.entryIds.length > 0)

  // What was open and was not kept is superseded, never deleted. It is the
  // record of what was said and when.
  const superseded = open.map((row) => row.id).filter((id) => !kept.has(id))
  if (superseded.length > 0) {
    await db
      .update(noticings)
      .set({ status: 'superseded' })
      .where(and(eq(noticings.studentId, session.studentId), inArray(noticings.id, superseded)))
  }

  if (fresh.length > 0) {
    await db.insert(noticings).values(
      fresh.map((noticing) => ({
        studentId: session.studentId,
        schoolId: session.schoolId,
        districtId: session.districtId,
        line: noticing.line,
        lean: noticing.lean,
        evidenceEntryIds: noticing.entryIds,
        promptVersion: result.promptVersion,
        modelVersion: result.model,
      })),
    )
  }

  return fresh.length
}

/**
 * What the model is shown. Their words and their dates, oldest first, then
 * what is already on the screen, then what they have said no to.
 */
function promptFor(
  entries: { at: string; text: string }[],
  open: { line: string }[],
  refused: { line: string }[],
): string {
  const said = entries
    .map((entry, index) => `${index + 1}. ${entry.at}\n${entry.text}`)
    .join('\n\n')

  const showing = open.length
    ? open.map((row, index) => `${index + 1}. ${row.line}`).join('\n')
    : 'none.'

  const no = refused.length
    ? refused.map((row) => `  ${row.line}`).join('\n')
    : 'none.'

  return [
    'entries, oldest first:',
    said,
    '',
    'already on their screen:',
    showing,
    '',
    'they said no to these, so do not say them again in any form:',
    no,
  ].join('\n')
}
