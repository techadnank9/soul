import { readFileSync, readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { and, eq, ne } from 'drizzle-orm'
import { db, prompts } from '../db.js'
import { clearPromptCache } from '../gateway/prompts.js'

/**
 * Loads /prompts into the database and makes each newest version active.
 *
 * The files are the source under version control. The database is what the
 * running service reads, so a prompt can be changed without a deploy and a
 * crisis screen can be changed without a store review.
 */
const here = dirname(fileURLToPath(import.meta.url))
const folder = join(here, '..', '..', '..', 'prompts')

const purposes = [
  'safety',
  'beat_one',
  'mirror',
  'tagger',
  'cue_cards',
  'pattern_verdict',
  'people',
  'person_profile',
  'voice_tone',
  'facts',
  'welcome',
  'weather_question',
  'consolidate',
] as const

async function main() {
  for (const file of readdirSync(folder).sort()) {
    const match = /^(.+)\.(v\d+)\.md$/.exec(file)
    if (!match) continue

    const [, purpose, version] = match
    if (!purposes.includes(purpose as (typeof purposes)[number])) {
      console.warn(`skipping ${file}, unknown purpose`)
      continue
    }

    const text = readFileSync(join(folder, file), 'utf8')
    const typed = purpose as (typeof purposes)[number]

    // One active prompt per purpose. The unique index enforces it, so the old
    // one has to be stood down before the new one is raised, not after. The
    // other order held only while each purpose had a single version, and it
    // failed the first time a second one arrived.
    await db
      .update(prompts)
      .set({ active: false })
      .where(and(eq(prompts.purpose, typed), ne(prompts.version, version!)))

    await db
      .insert(prompts)
      .values({ purpose: typed, version: version!, text, active: true })
      .onConflictDoUpdate({
        target: [prompts.purpose, prompts.version],
        set: { text, active: true },
      })

    console.log(`${purpose} ${version} is active`)
  }

  clearPromptCache()
  process.exit(0)
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
