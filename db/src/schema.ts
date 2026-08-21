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
  doublePrecision,
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

/**
 * What the app now says about a theme that keeps returning, and who said it.
 *
 * good and bad are the two sections of the patterns screen. unsettled is the
 * third answer and it is never shown: it is written down so that a theme the
 * model declined to judge is not asked about again every night until a run
 * happens to say something. source records
 * which of the two things decided it: outcomes means the student's own answers
 * to their check backs, model means we judged it because they had not. The
 * student's answer wins wherever there is one, so a row written from a model
 * verdict is replaced by one written from outcomes as soon as they say
 * something.
 */
export const themeVerdict = pgEnum('theme_verdict', ['good', 'bad', 'unsettled'])
export const verdictSource = pgEnum('verdict_source', ['outcomes', 'model'])
export const generationPurpose = pgEnum('generation_purpose', [
  'safety',
  'beat_one',
  'mirror',
  'tagger',
  'cue_cards',
  'pattern_verdict',
  'people',
  'person_profile',
])
export const jobStatus = pgEnum('job_status', ['pending', 'running', 'done', 'failed', 'cancelled'])
export const actorRole = pgEnum('actor_role', ['student', 'system', 'counsellor', 'district_admin'])

/**
 * The profile set, asked once at first run.
 *
 * A band rather than a birthdate, because the product needs to know roughly
 * how old a student is to speak to them properly and has no use at all for the
 * day they were born. not_said is a real answer and is stored as one, so a
 * student who declines is distinguishable from one who never reached the
 * question.
 */
export const ageBand = pgEnum('age_band', [
  'under_13',
  '13_17',
  '18_24',
  '25_34',
  '35_49',
  '50_plus',
])
export const gender = pgEnum('gender', ['male', 'female', 'nonbinary', 'not_said'])

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
 * No surnames, no birthdates. external_ref is the rostering identifier. A
 * first name is held only if the student gives one, and only so the app can
 * call them something.
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

    /**
     * The Apple subject identifier, present once the student has signed in on
     * a device. It is null until then, because rostering creates the student
     * and signing in only attaches a device to a row that already exists.
     *
     * Apple gives a different subject to every developer account, so this is
     * not a shared identifier and cannot be joined against anything outside
     * this database. It is unique because two students cannot be the same
     * Apple account.
     */
    appleUserId: text('apple_user_id'),

    /**
     * The profile, given by the student at first run. Every column is
     * nullable, because a student can leave first run at any point and a
     * half answered profile is a real state rather than a broken one.
     *
     * displayName is a first name and nothing more. It is what the app calls
     * them, not an identity record. There is still no surname and no
     * birthdate anywhere in this schema.
     *
     * region is the answer the student chose. timezone is derived from it and
     * stored beside it, so a check back can fire in their late afternoon
     * rather than the server's.
     */
    displayName: text('display_name'),
    ageBand: ageBand('age_band'),
    gender: gender('gender'),
    region: text('region'),
    timezone: text('timezone'),

    /**
     * Exact coordinates, when the student shared their location.
     *
     * This is precise location data about a child and it is the most sensitive
     * pair of columns in the schema. It is held because the founder asked for
     * it, not because anything in the product needs it: the region and the
     * timezone are derived from it and would work just as well from the
     * picker. See decision 061.
     *
     * Anything reading these should ask first whether the region would do.
     */
    latitude: doublePrecision('latitude'),
    longitude: doublePrecision('longitude'),
    profileRecordedAt: timestamp('profile_recorded_at', { withTimezone: true }),
    consentRecordedAt: timestamp('consent_recorded_at', { withTimezone: true }),
    consentVersion: text('consent_version'),
    notifyOptIn: boolean('notify_opt_in').notNull().default(false),
    createdAt: now(),
  },
  (t) => [
    uniqueIndex('students_school_external_ref_idx').on(t.schoolId, t.externalRef),
    uniqueIndex('students_apple_user_id_idx').on(t.appleUserId),
  ],
)

/**
 * A signed in device.
 *
 * Only the sha256 hash of the token is stored. The token itself is returned
 * once and then exists on the device and nowhere else, so this table read in
 * full still lets nobody in.
 *
 * A row is the answer to which student is asking, so it carries the school and
 * the district alongside the student rather than joining for them on every
 * request. revoked_at is set rather than the row deleted, because a district
 * asking when a device stopped being trusted needs the row to still be there.
 */
export const sessions = pgTable(
  'sessions',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    tokenHash: text('token_hash').notNull(),
    createdAt: now(),
    expiresAt: timestamp('expires_at', { withTimezone: true }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true }),
  },
  (t) => [
    uniqueIndex('sessions_token_hash_idx').on(t.tokenHash),
    index('sessions_student_idx').on(t.studentId),
  ],
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

/**
 * The baseline set, asked once at first run.
 *
 * One row per answered question. Skipped questions have no row, so a partly
 * answered set is a real thing rather than a set of nulls. Nothing here is
 * scored and nothing is shown back to the student.
 */
export const baselineAnswers = pgTable(
  'baseline_answers',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    setVersion: text('set_version').notNull(),
    questionIndex: smallint('question_index').notNull(),
    choiceIndex: smallint('choice_index').notNull(),
    createdAt: now(),
  },
  (t) => [
    uniqueIndex('baseline_answers_student_question_idx').on(
      t.studentId,
      t.setVersion,
      t.questionIndex,
    ),
  ],
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

/* ----------------------------------------------------------- cue cards -- */

/**
 * A card about something the student said was coming up.
 *
 * entry_id is the entry the card was drawn from, so every card can be put
 * back next to the sentence it came from. A card about a thing nobody
 * mentioned is the one failure this feature has, and this column is how it is
 * caught.
 *
 * The prompt and model versions sit here as well as on the generation row.
 * A card outlives the day it was written and the first question about a bad
 * one is which prompt wrote it.
 *
 * A card asks one question the student answers yes or no, and answered_yes is
 * that answer. detail is whatever they wrote in the box under it, which is
 * theirs and optional either way. answered_at is what says a card has been
 * dealt with, and it is what puts the unanswered ones first.
 *
 * A yes writes a decisions row, the same way the Mirror path does, and
 * decision_id is that row. A no writes no decision and books nothing, so a no
 * is a card with an answer, a time, sometimes a sentence, and a null there.
 *
 * options and chosen_index belong to the cards written before the question
 * became a yes or a no. Nothing writes to either column now and nothing reads
 * them on the student's path. They stay because the rows that have them are a
 * record of what a student was actually asked, and dropping the columns would
 * rewrite that history into three blanks.
 */
export const cueCards = pgTable(
  'cue_cards',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    about: text('about').notNull(),
    question: text('question').notNull(),
    options: text('options').array(),
    promptVersion: text('prompt_version').notNull(),
    modelVersion: text('model_version').notNull(),
    chosenIndex: smallint('chosen_index'),
    answeredYes: boolean('answered_yes'),
    detail: text('detail'),
    decisionId: uuid('decision_id').references(() => decisions.id),
    answeredAt: timestamp('answered_at', { withTimezone: true }),
    createdAt: now(),
  },
  (t) => [
    index('cue_cards_student_created_idx').on(t.studentId, t.createdAt.desc()),
    index('cue_cards_entry_idx').on(t.entryId),
  ],
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

/**
 * The verdict on a theme, and the one line the student reads under it.
 *
 * Rows are appended, never updated. The newest row for a theme is the live
 * one and the ones under it are how a line that landed badly gets traced back
 * to the prompt and the model that wrote it, which is the same reason the
 * cue card row carries both versions.
 *
 * `line` is written for the verdict on its own row, so a theme whose verdict
 * turns over gets a new row with a new line rather than the old sentence under
 * a new heading. `supporting` is how many entries were behind the theme when
 * it was judged, which is what says a stored line is out of date.
 */
export const patternVerdicts = pgTable(
  'pattern_verdicts',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),
    theme: text('theme').notNull(),
    verdict: themeVerdict('verdict').notNull(),
    source: verdictSource('source').notNull(),
    line: text('line').notNull(),
    supporting: integer('supporting').notNull(),
    promptVersion: text('prompt_version').notNull(),
    modelVersion: text('model_version').notNull(),
    createdAt: now(),
  },
  (t) => [
    index('pattern_verdicts_student_theme_idx').on(t.studentId, t.theme, t.createdAt.desc()),
  ],
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

/* -------------------------------------------------------------- people -- */

/**
 * The people a student writes about.
 *
 * This table holds records about somebody who is not a user of this product,
 * did not agree to be described, and cannot read or delete what is written
 * here. That was raised and decided, and the shape below is what makes it
 * defensible rather than reckless.
 *
 * name is what the student calls them and nothing more. There is no surname,
 * no contact detail we went looking for, and no identifier that would find
 * this person anywhere else. reach is the student's own note about how they
 * would get hold of them, written by them, empty until they write it.
 *
 * relation and profile are written by the model from this student's own
 * entries. They describe what happens between the two of them. They never
 * describe what the other person is like, because a child's character is not
 * ours to summarise from somebody else's diary.
 *
 * name_is_theirs and the other two flags mark a field the student edited. A
 * later profile run leaves those alone: their words about a person outrank
 * ours, permanently.
 */
export const people = pgTable(
  'people',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),

    name: text('name').notNull(),
    relation: text('relation'),
    profile: text('profile'),
    reach: text('reach'),

    nameIsTheirs: boolean('name_is_theirs').notNull().default(false),
    relationIsTheirs: boolean('relation_is_theirs').notNull().default(false),
    reachIsTheirs: boolean('reach_is_theirs').notNull().default(false),

    mentions: integer('mentions').notNull().default(0),
    firstSeenAt: timestamp('first_seen_at', { withTimezone: true }),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true }),

    promptVersion: text('prompt_version'),
    modelVersion: text('model_version'),
    profiledMentions: integer('profiled_mentions').notNull().default(0),
    createdAt: now(),
  },
  (t) => [
    // One row per name per student. Two Sams in one life are one row until the
    // student renames one of them, which is the only thing that can tell them
    // apart and is not ours to guess.
    uniqueIndex('people_student_name_idx').on(t.studentId, t.name),
    index('people_student_seen_idx').on(t.studentId, t.lastSeenAt.desc()),
  ],
)

/** Where a person was mentioned, and the words they were mentioned in. */
export const entryPeople = pgTable(
  'entry_people',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    entryId: uuid('entry_id').notNull().references(() => entries.id),
    personId: uuid('person_id').notNull().references(() => people.id),
    studentId: uuid('student_id').notNull().references(() => students.id),
    schoolId: uuid('school_id').notNull().references(() => schools.id),
    districtId: uuid('district_id').notNull().references(() => districts.id),

    /** The sentence they appear in, so a mention can be shown in context. */
    said: text('said').notNull(),
    createdAt: now(),
  },
  (t) => [
    uniqueIndex('entry_people_entry_person_idx').on(t.entryId, t.personId),
    index('entry_people_person_idx').on(t.personId),
  ],
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
