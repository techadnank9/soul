import { Hono } from 'hono'
import { eq } from 'drizzle-orm'
import { db, students } from '../db.js'
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
      displayName: students.displayName,
      ageBand: students.ageBand,
      gender: students.gender,
      region: students.region,
      place: students.place,
      timezone: students.timezone,
      latitude: students.latitude,
      longitude: students.longitude,
      recordedAt: students.profileRecordedAt,
    })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  const row = rows[0]
  return c.json({
    recorded: Boolean(row?.recordedAt),
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
