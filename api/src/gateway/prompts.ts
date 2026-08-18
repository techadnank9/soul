import { eq, and } from 'drizzle-orm'
import { db, prompts } from '../db.js'

export type Purpose = 'safety' | 'beat_one' | 'mirror' | 'tagger'

/**
 * Prompt text comes from the database, never from the binary.
 *
 * Flutter has no over the air updates. The words a student sees during a
 * crisis cannot wait on a store review, so crisis wording and thresholds live
 * here with the prompts.
 *
 * Cached in memory for a minute. A prompt change reaches production within the
 * minute without a deploy, and a thousand entries do not become a thousand
 * extra queries.
 */
const CACHE_MS = 60_000
const cache = new Map<Purpose, { version: string; text: string; at: number }>()

export async function activePrompt(
  purpose: Purpose,
  now: number = Date.now(),
): Promise<{ version: string; text: string }> {
  const hit = cache.get(purpose)
  if (hit && now - hit.at < CACHE_MS) return { version: hit.version, text: hit.text }

  const rows = await db
    .select({ version: prompts.version, text: prompts.text })
    .from(prompts)
    .where(and(eq(prompts.purpose, purpose), eq(prompts.active, true)))
    .limit(1)

  const row = rows[0]
  if (!row) throw new Error(`no active prompt for ${purpose}`)

  cache.set(purpose, { ...row, at: now })
  return row
}

/** Used by tests and by the seed script so a change is visible immediately. */
export function clearPromptCache(): void {
  cache.clear()
}
