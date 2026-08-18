import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import { migrate } from 'drizzle-orm/postgres-js/migrator'
import { connectionString } from './client.js'

const here = dirname(fileURLToPath(import.meta.url))

async function main() {
  const sql = postgres(connectionString(), { max: 1 })
  try {
    await sql.unsafe('create extension if not exists vector')
    await migrate(drizzle(sql), { migrationsFolder: join(here, '..', 'migrations') })
    await sql.unsafe(readFileSync(join(here, '..', 'sql', 'rls.sql'), 'utf8'))
    console.log('migrations applied, row level security applied')
  } finally {
    await sql.end()
  }
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
