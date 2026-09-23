import { and, eq, inArray } from 'drizzle-orm'
import { db, entries, patternCandidates } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * Attaches a waiting candidate to a Mirror, as a question with its evidence.
 *
 * A pattern is never asserted. It is proposed, hedged, and stored only when
 * the student confirms it. The wording here has to be rejectable without the
 * student feeling they got something wrong.
 *
 * The moments go out with it, and that is the point of the whole design.
 * Finding a pattern is a SQL group by precisely so the exact entries behind
 * a claim can be shown, and until now they never were: the student was asked
 * to agree or disagree with a sentence about themselves and given nothing to
 * check it against. Agreeing on a feeling is not confirmation. Reading two
 * things you wrote yourself, on two dates, and saying yes is.
 *
 * The moments are the student's own words, never a summary of them. A model
 * writing a line about an entry would put a paraphrase where the evidence is
 * supposed to be, and a paraphrase is not evidence.
 */

/** How many moments go on the screen. The rest are behind see the moments. */
const SHOWN = 3

/** The opening of what they wrote, enough to recognise it by. */
const SAID_CHARS = 140

export type SurfacedMoment = {
  entryId: string
  at: string
  said: string
}

export type Surfaced = {
  candidateId: string
  proposal: string
  moments: SurfacedMoment[]
}

export async function surfaceCandidate(session: Session): Promise<Surfaced | null> {
  const rows = await db
    .select({
      id: patternCandidates.id,
      theme: patternCandidates.theme,
      supportingEntryIds: patternCandidates.supportingEntryIds,
    })
    .from(patternCandidates)
    .where(
      and(
        eq(patternCandidates.studentId, session.studentId),
        eq(patternCandidates.status, 'pending'),
      ),
    )
    .limit(1)

  const row = rows[0]
  if (!row) return null

  const supporting = row.supportingEntryIds ?? []

  // Scoped to the student as well as to the ids. The ids came out of our own
  // row, but a query that reads entries by id alone is one refactor away from
  // reading somebody else's, and row level security should never be the only
  // thing that noticed.
  const written = supporting.length
    ? await db
        .select({ id: entries.id, text: entries.text, at: entries.createdAt })
        .from(entries)
        .where(and(inArray(entries.id, supporting), eq(entries.studentId, session.studentId)))
    : []

  written.sort((a, b) => a.at.getTime() - b.at.getTime())

  const moments = written.slice(0, SHOWN).map((entry) => ({
    entryId: entry.id,
    at: entry.at.toISOString(),
    said: opening(entry.text),
  }))

  await db
    .update(patternCandidates)
    .set({ status: 'surfaced', surfacedAt: new Date() })
    .where(eq(patternCandidates.id, row.id))

  return {
    candidateId: row.id,
    proposal: propose(row.theme, written.length || supporting.length),
    moments,
  }
}

/**
 * The sentence that carries the claim.
 *
 * It used to read "this feels close to something you have written before,
 * around went quiet", which put a raw tag in the middle of a sentence and
 * read like a machine emptying a column onto the screen.
 *
 * The theme is a coping word from the tagger's closed list, and every word on
 * that list is already something a person would say about what they did, so
 * it needs no mapping. A theme that is not one of them reads as a phrase on
 * its own, which is what a later list of interpretations would give us.
 */
function propose(theme: string, count: number): string {
  const how = COPING.has(theme) ? `you ${theme}` : theme
  const many = count === 2 ? 'two moments' : `${words(count)} moments`

  return (
    `In ${many} you wrote, what you did next looks like the same thing: ` +
    `${how}. Does that feel connected, or am I missing it?`
  )
}

const COPING = new Set([
  'went quiet',
  'said it directly',
  'avoided it',
  'put it off',
  'agreed anyway',
  'asked for help',
  'pushed back',
  'made it smaller',
  'carried on',
  'did it anyway',
])

function words(n: number): string {
  const said = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine']
  return said[n] ?? String(n)
}

/**
 * The first part of what they wrote, cut at a sentence where there is one so
 * the quote does not stop mid thought.
 */
function opening(text: string): string {
  const clean = text.trim().replace(/\s+/g, ' ')
  if (clean.length <= SAID_CHARS) return clean

  const cut = clean.slice(0, SAID_CHARS)
  const stop = Math.max(cut.lastIndexOf('. '), cut.lastIndexOf('? '), cut.lastIndexOf('! '))
  if (stop > SAID_CHARS / 2) return cut.slice(0, stop + 1)

  const space = cut.lastIndexOf(' ')
  return `${space > 0 ? cut.slice(0, space) : cut}...`
}
