import { readFileSync } from 'node:fs'
import { eq } from 'drizzle-orm'
import { db, legacyFeedback, legacyUsers } from '../db.js'

/**
 * Bring the previous website's survey answers and account list into this
 * database, so they are somewhere durable rather than in a download folder.
 *
 * These people are not students. They have no district, no school and no
 * consent recorded here, and nothing in the product reads them: the row level
 * security file gives the student role no policy and no grant on either table.
 * They are kept because they answered questions about this product and because
 * some of them may already know who we are.
 *
 * The files are not committed. They hold names, email addresses and phone
 * numbers, and a git history is the wrong place for that. Pass the paths:
 *
 *   npm run import:legacy -w @soul/api -- feedback.json users.json
 *
 * Idempotent by source. Running it twice replaces that source's rows rather
 * than doubling them.
 */

function read(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, 'utf8'))
  } catch (error) {
    throw new Error(`could not read ${path}: ${(error as Error).message}`)
  }
}

/** Empty strings and the string "None" both mean nobody answered. */
function text(value: unknown): string | null {
  if (value === null || value === undefined) return null
  const trimmed = String(value).trim()
  if (!trimmed || trimmed === 'None') return null
  return trimmed
}

function whole(value: unknown): number | null {
  if (value === null || value === undefined || value === '') return null
  const n = Number(value)
  return Number.isInteger(n) ? n : null
}

/** The exports write dates as plain ISO days. Anything else is left null. */
function day(value: unknown): string | null {
  const t = text(value)
  return t && /^\d{4}-\d{2}-\d{2}$/.test(t) ? t : null
}

async function importFeedback(path: string): Promise<number> {
  const file = read(path) as { source?: string; records?: unknown[] }
  const records = Array.isArray(file.records) ? file.records : []
  if (!records.length) throw new Error(`${path} has no records`)

  // The file names its own origin. Better than a constant in here that drifts.
  const source = text(file.source) ?? path

  await db.delete(legacyFeedback).where(eq(legacyFeedback.source, source))

  const rows = records.map((entry) => {
    const r = entry as Record<string, unknown>
    return {
      source,
      submittedOn: day(r['Date']),
      guestEmail: text(r['Guest Email']),
      rating: whole(r['Rating']),
      ease: text(r['Ease']),
      recommend: text(r['Recommend']),
      useFrequency: text(r['Use Frequency']),
      personalOrGeneric: text(r['Personal or generic']),
      whatConfusedThem: text(r['What confused them']),
      wouldUseAgain: text(r['Would use again']),
      freeText: text(r['Free text']),
      duplicate: text(r['Duplicate']),
      raw: r,
    }
  })

  await db.insert(legacyFeedback).values(rows)
  return rows.length
}

async function importUsers(path: string): Promise<number> {
  const file = read(path)
  const records = Array.isArray(file) ? file : []
  if (!records.length) throw new Error(`${path} has no records`)

  const source = 'Soul Space website, accounts export'
  await db.delete(legacyUsers).where(eq(legacyUsers.source, source))

  // Email is unique on the table. The old site allowed one account per
  // address, so a repeat here is an export artefact and the last one wins.
  const byEmail = new Map<string, Record<string, unknown>>()
  for (const entry of records) {
    const r = entry as Record<string, unknown>
    const email = text(r['email'])
    if (email) byEmail.set(email.toLowerCase(), r)
  }

  const rows = [...byEmail.entries()].map(([email, r]) => ({
    source,
    name: text(r['name']),
    email,
    phone: text(r['phone']),
    age: whole(r['age']),
    gender: text(r['gender']),
    plan: text(r['plan']),
    profileComplete: typeof r['profile'] === 'boolean' ? (r['profile'] as boolean) : null,
    sessions: whole(r['sessions']),
    joinedOn: day(r['joined']),
    raw: r,
  }))

  await db.insert(legacyUsers).values(rows)
  return rows.length
}

const [feedbackPath, usersPath] = process.argv.slice(2)

if (!feedbackPath || !usersPath) {
  console.error('usage: import_legacy.ts <feedback.json> <users.json>')
  process.exit(1)
}

const feedback = await importFeedback(feedbackPath)
const users = await importUsers(usersPath)
console.log(`${feedback} feedback rows and ${users} accounts imported`)
process.exit(0)
