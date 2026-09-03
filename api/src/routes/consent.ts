import { Hono } from 'hono'
import { z } from 'zod'
import { eq, sql } from 'drizzle-orm'
import { db, students, auditLog, baselineAnswers } from '../db.js'
import { enqueue } from '../jobs/enqueue.js'
import type { Session } from '../session.js'

/**
 * Consent is a recorded event with a version, not a flag.
 *
 * A student who agreed to v1 has not agreed to v2. When the wording changes the
 * version changes, and every student is asked again. That is what makes it a
 * process rather than a checkbox, which is what the clinical guidance asks for.
 */
type Vars = { Variables: { session: Session } }

export const consent = new Hono<Vars>()

const body = z.object({ version: z.string().min(1).max(20) })

consent.get('/consent', async (c) => {
  const session = c.get('session')
  const rows = await db
    .select({
      recordedAt: students.consentRecordedAt,
      version: students.consentVersion,
    })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  const row = rows[0]
  return c.json({
    recorded: Boolean(row?.recordedAt),
    version: row?.version ?? null,
  })
})

consent.post('/consent', async (c) => {
  const parsed = body.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid consent' }, 400)

  const session = c.get('session')

  const before = await db
    .select({ recordedAt: students.consentRecordedAt })
    .from(students)
    .where(eq(students.id, session.studentId))
    .limit(1)

  await db
    .update(students)
    .set({
      consentRecordedAt: new Date(),
      consentVersion: parsed.data.version,
    })
    .where(eq(students.id, session.studentId))

  // Anything written before this moment was stored held. Now it can go
  // through the classifier and the tagger, in the queue, in that order.
  if (!before[0]?.recordedAt) await enqueue('release_held', {}, session)

  // Districts have inspection rights and will ask when a student agreed and to
  // which wording. This is the row that answers them.
  await db.insert(auditLog).values({
    actorId: session.studentId,
    actorRole: 'student',
    action: `consent_recorded:${parsed.data.version}`,
    subjectStudentId: session.studentId,
    subjectType: 'student',
    subjectId: session.studentId,
  })

  return c.json({ ok: true })
})

/**
 * The baseline set. One row per answered question, skipped ones simply absent.
 *
 * Idempotent on question, so a student who goes back and changes an answer
 * updates it rather than leaving two.
 */
const baselineBody = z.object({
  setVersion: z.string().min(1).max(40),
  answers: z
    .array(
      z.object({
        questionIndex: z.number().int().min(0).max(99),
        choiceIndex: z.number().int().min(0).max(9),
      }),
    )
    .max(100),
})

consent.post('/baseline', async (c) => {
  const parsed = baselineBody.safeParse(await c.req.json())
  if (!parsed.success) return c.json({ error: 'invalid baseline' }, 400)

  const session = c.get('session')
  const { setVersion, answers } = parsed.data
  if (answers.length === 0) return c.json({ ok: true, stored: 0 })

  await db
    .insert(baselineAnswers)
    .values(
      answers.map((answer) => ({
        studentId: session.studentId,
        schoolId: session.schoolId,
        districtId: session.districtId,
        setVersion,
        questionIndex: answer.questionIndex,
        choiceIndex: answer.choiceIndex,
      })),
    )
    .onConflictDoUpdate({
      target: [
        baselineAnswers.studentId,
        baselineAnswers.setVersion,
        baselineAnswers.questionIndex,
      ],
      set: { choiceIndex: sql`excluded.choice_index` },
    })

  return c.json({ ok: true, stored: answers.length })
})
