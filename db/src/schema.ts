import { sql } from 'drizzle-orm'
import {
  pgEnum,
  pgTable,
  uuid,
  text,
  integer,
  smallint,
  boolean,
  timestamp,
  real,
  index,
  uniqueIndex,
  vector,
} from 'drizzle-orm/pg-core'

/**
 * Every table carries student, school and district identifiers and is
 * protected by row level security. There is one district today. The columns
 * exist anyway, because adding them later means a migration on live student
 * data.
 */

export const EMBEDDING_DIMENSIONS = 1536

const now = () => timestamp('created_at', { withTimezone: true }).notNull().defaultNow()

/* ---------------------------------------------------------------- enums -- */

export const consentModel = pgEnum('consent_model', ['school', 'parent', 'dual'])
export const inputMode = pgEnum('input_mode', ['voice', 'typed'])
export const riskLevel = pgEnum('risk_level', ['none', 'low', 'medium', 'high'])
export const safetyStatus = pgEnum('safety_status', ['open', 'acknowledged', 'closed'])
export const decisionStatus = pgEnum('decision_status', ['open', 'closed', 'abandoned'])
export const feltAfter = pgEnum('felt_after', ['lighter', 'same', 'worse'])
export const candidateStatus = pgEnum('candidate_status', ['pending', 'surfaced', 'confirmed', 'rejected'])
export const generationPurpose = pgEnum('generation_purpose', ['safety', 'beat_one', 'mirror', 'tagger'])
export const jobStatus = pgEnum('job_status', ['pending', 'running', 'done', 'failed', 'cancelled'])
export const actorRole = pgEnum('actor_role', ['student', 'system', 'counsellor', 'district_admin'])

/* ------------------------------------------------------------- tenancy -- */

export const districts = pgTable('districts', {
  id: uuid('id').primaryKey().defaultRandom(),
  name: text('name').notNull(),
  consentModel: consentModel('consent_model').notNull().default('school'),
  retentionDays: integer('retention_days').notNull(),
  escalationPolicy: text('escalation_policy'),
  createdAt: now(),
})

export const schools = pgTable(
  'schools',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    name: text('name').notNull(),
    createdAt: now(),
  },
  (t) => [index('schools_district_idx').on(t.districtId)],
)

/**
 * No names, no birthdates. external_ref is the rostering identifier.
 * Identifying information stays in the rostering system, not here.
 */
export const students = pgTable(
  'students',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    externalRef: text('external_ref').notNull(),
    yearGroup: smallint('year_group'),
    consentRecordedAt: timestamp('consent_recorded_at', { withTimezone: true }),
    consentVersion: text('consent_version'),
    notifyOptIn: boolean('notify_opt_in').notNull().default(false),
    createdAt: now(),
  },
  (t) => [uniqueIndex('students_school_external_ref_idx').on(t.schoolId, t.externalRef)],
)

/* ------------------------------------------------------------- entries -- */

/**
 * text is its own column, never inside a JSON blob, so it can be encrypted
 * later without a rewrite. No audio is stored. Ever.
 */
export const entries = pgTable(
  'entries',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    text: text('text').notNull(),
    inputMode: inputMode('input_mode').notNull(),
    transcriptConfirmed: boolean('transcript_confirmed').notNull().default(false),
    durationMs: integer('duration_ms'),
    localHour: smallint('local_hour'),
    processed: boolean('processed').notNull().default(false),
    createdAt: now(),
  },
  (t) => [index('entries_student_created_idx').on(t.studentId, t.createdAt.desc())],
)

/** The sentence the student chose to carry forward, in their words. */
export const keptLines = pgTable(
  'kept_lines',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    text: text('text').notNull(),
    createdAt: now(),
  },
  (t) => [index('kept_lines_student_created_idx').on(t.studentId, t.createdAt.desc())],
)

/* ---------------------------------------------------------------- tags -- */

/**
 * Written by the async tagger, never shown to the student directly. Values
 * describe situations, never traits. Low confidence tags must not support a
 * pattern claim.
 */
export const tags = pgTable(
  'tags',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    trigger: text('trigger'),
    feeling: text('feeling'),
    coping: text('coping'),
    domain: text('domain'),
    confidence: real('confidence').notNull(),
    taggerVersion: text('tagger_version').notNull(),
    createdAt: now(),
  },
  (t) => [
    index('tags_student_feeling_idx').on(t.studentId, t.feeling),
    index('tags_student_trigger_idx').on(t.studentId, t.trigger),
    index('tags_entry_idx').on(t.entryId),
  ],
)

/** The semantic fallback, queried by background jobs, never on the request path. */
export const entryEmbeddings = pgTable(
  'entry_embeddings',
  {
    entryId: uuid('entry_id').primaryKey().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    embedding: vector('embedding', { dimensions: EMBEDDING_DIMENSIONS }).notNull(),
    modelVersion: text('model_version').notNull(),
    createdAt: now(),
  },
  (t) => [
    index('entry_embeddings_hnsw_idx').using('hnsw', t.embedding.op('vector_cosine_ops')),
    index('entry_embeddings_student_idx').on(t.studentId),
  ],
)

/* ----------------------------------------------------------- decisions -- */

/**
 * offered_text is what the Mirror suggested. chosen_text is what the student
 * actually wrote. Two columns, never merged.
 */
export const decisions = pgTable(
  'decisions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    offeredText: text('offered_text'),
    chosenText: text('chosen_text').notNull(),
    horizon: timestamp('horizon', { withTimezone: true }).notNull(),
    status: decisionStatus('status').notNull().default('open'),
    createdAt: now(),
  },
  (t) => [index('decisions_student_status_idx').on(t.studentId, t.status)],
)

/** An ignored check back is written too. */
export const outcomes = pgTable(
  'outcomes',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    decisionId: uuid('decision_id').notNull().references(() => decisions.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    whatHappened: text('what_happened'),
    felt: feltAfter('felt'),
    respondedAt: timestamp('responded_at', { withTimezone: true }),
    ignoredCount: integer('ignored_count').notNull().default(0),
    createdAt: now(),
  },
  (t) => [index('outcomes_decision_idx').on(t.decisionId)],
)

/* ------------------------------------------------------------ patterns -- */

/**
 * Produced by the nightly SQL sweep. Cannot exist without at least three
 * supporting entry ids on three distinct days.
 */
export const patternCandidates = pgTable(
  'pattern_candidates',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    theme: text('theme').notNull(),
    supportingEntryIds: uuid('supporting_entry_ids').array().notNull(),
    proposedAt: timestamp('proposed_at', { withTimezone: true }).notNull().defaultNow(),
    surfacedAt: timestamp('surfaced_at', { withTimezone: true }),
    status: candidateStatus('status').notNull().default('pending'),
    createdAt: now(),
  },
  (t) => [index('pattern_candidates_student_status_idx').on(t.studentId, t.status)],
)

/** Only the student creates these, by confirming. removed_at supports this is not me. */
export const confirmedPatterns = pgTable(
  'confirmed_patterns',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    theme: text('theme').notNull(),
    supportingEntryIds: uuid('supporting_entry_ids').array().notNull(),
    confirmedAt: timestamp('confirmed_at', { withTimezone: true }).notNull().defaultNow(),
    reminderArmed: boolean('reminder_armed').notNull().default(false),
    removedAt: timestamp('removed_at', { withTimezone: true }),
    createdAt: now(),
  },
  (t) => [index('confirmed_patterns_student_idx').on(t.studentId)],
)

/** Checked by the sweep so the same wrong idea is never offered twice. */
export const patternRejections = pgTable(
  'pattern_rejections',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    theme: text('theme').notNull(),
    rejectedAt: timestamp('rejected_at', { withTimezone: true }).notNull().defaultNow(),
    reason: text('reason'),
    createdAt: now(),
  },
  (t) => [index('pattern_rejections_student_theme_idx').on(t.studentId, t.theme)],
)

/* -------------------------------------------------------------- safety -- */

/**
 * Its own record with a status field, not a boolean on an entry, because it
 * becomes a workflow when the counsellor console exists. Written on every
 * entry, hit or miss.
 */
export const safetyFlags = pgTable(
  'safety_flags',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    riskLevel: riskLevel('risk_level').notNull(),
    categories: text('categories').array().notNull().default(sql`'{}'::text[]`),
    classifierVersion: text('classifier_version').notNull(),
    actionTaken: text('action_taken').notNull(),
    resourcesShown: boolean('resources_shown').notNull().default(false),
    status: safetyStatus('status').notNull().default('open'),
    reviewedBy: uuid('reviewed_by'),
    reviewedAt: timestamp('reviewed_at', { withTimezone: true }),
    createdAt: now(),
  },
  (t) => [
    uniqueIndex('safety_flags_entry_idx').on(t.entryId),
    index('safety_flags_status_created_idx').on(t.status, t.createdAt.desc()),
  ],
)

/* ------------------------------------------------------- observability -- */

/** Written by the gateway for every call. This is how you tell whether a prompt change helped. */
export const generations = pgTable(
  'generations',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    purpose: generationPurpose('purpose').notNull(),
    promptVersion: text('prompt_version').notNull(),
    modelVersion: text('model_version').notNull(),
    provider: text('provider').notNull(),
    latencyMs: integer('latency_ms'),
    inputTokens: integer('input_tokens'),
    outputTokens: integer('output_tokens'),
    createdAt: now(),
  },
  (t) => [index('generations_purpose_created_idx').on(t.purpose, t.createdAt.desc())],
)

/**
 * Prompt text, crisis wording and thresholds live here, not in the app binary.
 * Flutter has no over the air updates and the words a student sees during a
 * crisis cannot wait on a store review.
 */
export const prompts = pgTable(
  'prompts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    purpose: generationPurpose('purpose').notNull(),
    version: text('version').notNull(),
    text: text('text').notNull(),
    active: boolean('active').notNull().default(false),
    createdAt: now(),
  },
  (t) => [
    uniqueIndex('prompts_purpose_version_idx').on(t.purpose, t.version),
    uniqueIndex('prompts_active_idx').on(t.purpose).where(sql`${t.active}`),
  ],
)

/**
 * Postgres backed queue rather than Redis. Check backs fire days later and must
 * survive deploys. Fewer services also means a shorter sub processor list.
 */
export const jobs = pgTable(
  'jobs',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    type: text('type').notNull(),
    payload: text('payload').notNull(),
    studentId: uuid('student_id').references(() => students.id),
    schoolId: uuid('school_id').references(() => schools.id),
    districtId: uuid('district_id').references(() => districts.id),
    runAt: timestamp('run_at', { withTimezone: true }).notNull().defaultNow(),
    attempts: integer('attempts').notNull().default(0),
    lastError: text('last_error'),
    status: jobStatus('status').notNull().default('pending'),
    createdAt: now(),
  },
  (t) => [index('jobs_status_run_at_idx').on(t.status, t.runAt)],
)

/** Written from day one even though nobody reads it yet. Districts have inspection rights. */
export const auditLog = pgTable(
  'audit_log',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    actorId: uuid('actor_id'),
    actorRole: actorRole('actor_role').notNull(),
    action: text('action').notNull(),
    subjectStudentId: uuid('subject_student_id').references(() => students.id),
    subjectType: text('subject_type').notNull(),
    subjectId: uuid('subject_id'),
    createdAt: now(),
  },
  (t) => [index('audit_log_subject_student_created_idx').on(t.subjectStudentId, t.createdAt.desc())],
)
