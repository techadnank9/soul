import { createClient } from '@soul/db'
import { env } from './env.js'

/**
 * One connection for the service. Row level security is enforced by the
 * database against the session student, set per transaction in session.ts.
 */
const client = createClient(env.databaseUrl())

export const db = client.db
export const sql = client.sql
export * from '@soul/db'
