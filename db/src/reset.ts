import postgres from 'postgres'
import { connectionString } from './client.js'

/**
 * Delete every row, keep every table.
 *
 * The schema, the row level security policies and the migration history all
 * survive. What goes is student data, prompts included, so a reset is followed
 * by seeding prompts and fixtures again.
 *
 * It refuses to run without --yes, and it refuses to run against anything that
 * is not localhost unless --anywhere is also given. Losing a laptop database
 * costs a reseed. Losing a real one costs a district.
 */
async function main() {
  const args = process.argv.slice(2)
  const url = connectionString()
  const local = /@(localhost|127\.0\.0\.1)[:/]/.test(url)

  if (!args.includes('--yes')) {
    console.error('reset deletes every row. Pass --yes to mean it.')
    process.exit(1)
  }
  if (!local && !args.includes('--anywhere')) {
    console.error(`refusing: ${url.replace(/:[^:@]*@/, ':***@')} is not localhost.`)
    process.exit(1)
  }

  const sql = postgres(url, { max: 1 })
  try {
    const tables = await sql<{ name: string }[]>`
      select tablename as name from pg_tables
      where schemaname = 'public' and tablename <> '__drizzle_migrations'
      order by tablename`

    if (tables.length === 0) {
      console.log('nothing to reset, no tables found')
      return
    }

    // One statement, so foreign keys never see a half emptied database.
    const list = tables.map((t) => `"${t.name}"`).join(', ')
    await sql.unsafe(`truncate table ${list} restart identity cascade`)

    console.log(`reset ${tables.length} tables. Seed prompts and fixtures next.`)
  } finally {
    await sql.end()
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
