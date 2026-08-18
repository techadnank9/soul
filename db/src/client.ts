import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'
import * as schema from './schema.js'

export function connectionString(): string {
  const url = process.env.DATABASE_URL
  if (!url) throw new Error('DATABASE_URL is not set')
  return url
}

export function createClient(url = connectionString()) {
  const sql = postgres(url, { max: 10 })
  return { sql, db: drizzle(sql, { schema }) }
}

export type Database = ReturnType<typeof createClient>['db']
