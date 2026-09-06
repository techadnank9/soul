import { Hono } from 'hono'
import { count, eq } from 'drizzle-orm'
import { db, entries, students } from '../db.js'
import * as contracts from '../contracts.js'
import { saveProfile } from '../services/profile/save.js'
import type { Session } from '../session.js'

/**
 * The profile a student gives at first run.
 *
 * A first name, an age band, a gender, a region, and exact coordinates when
 * the student shared their location. No surname and no birthdate.
 *
 * The coordinates are the one field here that is not needed for anything the
 * product does. They are held because the founder asked for them. See
 * decision 061.
 *
 * GET answers whether first run has happened, so the client does not ask a
 * student the same four questions on a second device.
 */
type Vars = { Variables: { session: Session } }

export const profile = new Hono<Vars>()

profile.get('/profile', async (c) => {
  const session = c.get('session')
  const rows = await db
    .select({
      id: students.id,
      displayName: students.displayName,
      ageBand: students.ageBand,
      gender: students.gender,
      region: students.region,
      place: students.place,
      timezone: students.timezone,
      latitude: students.latitude,
      longitude: students.longitude,
      recordedAt: students.profileRecordedAt,
      email: students.email,
      phone: students.phone,
      appleUserId: students.appleUserId,
    })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  // How many moments they have written, ever. It is the one number that
  // says whether somebody has actually used this, and the client hands it
  // to the funnels so a question can be asked of people who have rather
  // than of everybody who opened it once.
  const written = await db
    .select({ n: count() })
    .from(entries)
    .where(eq(entries.studentId, session.studentId))

  const row = rows[0]
  return c.json({
    entriesWritten: written[0]?.n ?? 0,
    // The account's own id. It goes to the funnels as the person there, so
    // the same account on two phones is one person rather than two. It is a
    // random uuid and it carries nothing about anybody.
    accountId: row?.id ?? null,
    recorded: Boolean(row?.recordedAt),
    // Whether anything but this phone can reach this account. A device
    // account with neither is one log out away from being unreachable, and
    // the profile offers sign in when this is false.
    signedIn: Boolean(row?.email || row?.phone || row?.appleUserId),
    // The address itself, so the client can hand it to the funnels. A
    // response from a tester has to be a person somebody can write back to,
    // and a uuid is not one. Decision 226.
    email: row?.email ?? null,
    phone: row?.phone ?? null,
    displayName: row?.displayName ?? null,
    ageBand: row?.ageBand ?? null,
    gender: row?.gender ?? null,
    region: row?.region ?? null,
    place: row?.place ?? null,
    timezone: row?.timezone ?? null,
    // Shown back to the student, because a product holding a child's exact
    // position and not showing it to them is the worse version of this.
    latitude: row?.latitude ?? null,
    longitude: row?.longitude ?? null,
  })
})

profile.post('/profile', async (c) => {
  const parsed = contracts.saveProfile.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid profile' }, 400)

  await saveProfile(c.get('session'), parsed.data)
  return c.json({ ok: true })
})
