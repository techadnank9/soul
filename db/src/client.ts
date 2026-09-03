import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import * as schema from './schema.js'

export function connectionString(): string {
  const url = process.env.DATABASE_URL
  if (!url) throw new Error('DATABASE_URL is not set')
  return url
}

/**
 * Four connections per process. The Supabase session pooler allows fifteen
 * across everything, and the API, the worker, a laptop and a script all
 * share them. Ten each was enough to have a probe refused mid query.
 */
export function createClient(url = connectionString()) {
  const sql = postgres(url, { max: 4 })
  return { sql, db: drizzle(sql, { schema }) }
}

export type Database = ReturnType<typeof createClient>['db']
