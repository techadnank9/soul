import { sql } from '../db.js'

/**
 * The human help screen.
 *
 * Crisis wording lives in the database so it can be changed without a store
 * release. The fallback below exists only for the case where the database is
 * unreachable, because a student in distress must never see an empty screen.
 * It is deliberately plain and it names a person the student already knows
 * before it names a service.
 */
const FALLBACK = {
  heading: 'Let us stop here for a moment',
  body: 'Some of what you wrote sounds heavy, and it is not something this app '
    + 'should answer on its own. Talking to someone is worth more than anything '
    + 'we could say back.',
  contacts: [
    { label: 'Someone you already trust', detail: 'A teacher, a parent, an older sibling, a friend' },
    { label: 'Your school counsellor', detail: 'They can be reached during school hours' },
    { label: '988 Suicide and Crisis Lifeline', detail: 'Call or text 988, any time' },
  ],
}

export type HelpScreen = typeof FALLBACK

export async function helpScreen(): Promise<HelpScreen> {
  try {
    const rows = await sql<{ text: string }[]>`
      select text from prompts
      where purpose = 'safety' and version like 'help-%' and active = true
      limit 1`
    const row = rows[0]
    if (!row) return FALLBACK
    return { ...FALLBACK, ...(JSON.parse(row.text) as Partial<HelpScreen>) }
  } catch {
    return FALLBACK
  }
}
