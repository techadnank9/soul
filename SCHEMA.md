# Schema

Postgres. Drizzle for definitions and migrations. Every table carries student,
school and district identifiers and is protected by row level security.

Eighteen tables. This document and `db/src/schema.ts` are kept in step; the
schema file is the one the database is built from.

## Tenancy

Three columns appear on nearly every table: `student_id`, `school_id`,
`district_id`. There is one district today. They exist anyway, because adding
them later means a migration on live student data.

Row level security policies scope every read and write to the session's student.
Application code is not the only guard. Test it by trying to read another
student's row and failing.

---

## baseline_answers
`id`, `student_id`, `school_id`, `district_id`, `set_version`, `question_index`,
`choice_index`, `created_at`

The ten question baseline from first run. One row per answered question, unique
on student and question within a version, so answering again replaces rather
than duplicates. Nothing is scored and nothing is shown back. `set_version`
exists because the question set will change and old answers must not be read as
answers to new questions.

Skipped questions have no row. Absence is the record of a skip.

---

## districts
`id`, `name`, `consent_model`, `retention_days`, `escalation_policy`,
`created_at`

## schools
`id`, `district_id`, `name`, `created_at`

## students
`id`, `school_id`, `district_id`, `external_ref`, `year_group`,
`consent_recorded_at`, `consent_version`, `notify_opt_in`, `created_at`

No names, no birthdates. `external_ref` is the rostering identifier. Keep
identifying information in the rostering system, not here.

---

## entries
`id`, `student_id`, `school_id`, `district_id`, `text`, `input_mode`,
`transcript_confirmed`, `duration_ms`, `local_hour`, `created_at`

`text` is its own column, never inside a JSON blob, so it can be encrypted later
without a rewrite. `input_mode` is voice or typed. `transcript_confirmed`
records that the student saw the transcript and sent it.

No audio is stored. Ever.

## kept_lines
`id`, `entry_id`, `student_id`, `text`, `created_at`

The sentence the student chose to carry forward, in their words.

---

## tags
`id`, `entry_id`, `student_id`, `trigger`, `feeling`, `coping`, `domain`,
`confidence`, `tagger_version`, `created_at`

Written by the async tagger. Never shown to the student directly. Values
describe situations, never traits. Low confidence tags must not support a
pattern claim.

## entry_embeddings
`entry_id`, `embedding vector(N)`, `model_version`

pgvector. The semantic fallback for when the same experience is worded
differently. Queried by background jobs, never on the request path.

---

## decisions
`id`, `entry_id`, `student_id`, `offered_text`, `chosen_text`, `horizon`,
`status`, `created_at`

`offered_text` is what the Mirror suggested. `chosen_text` is what the student
actually wrote. Two columns, never merged. The gap between them is the most
interesting data in the system.

`status`: open, closed, abandoned.

## outcomes
`id`, `decision_id`, `student_id`, `what_happened`, `felt`, `responded_at`,
`ignored_count`

`felt` is lighter, same or worse. An ignored check back is written too.

---

## pattern_candidates
`id`, `student_id`, `theme`, `supporting_entry_ids[]`, `proposed_at`,
`surfaced_at`, `status`

Produced by the nightly SQL sweep. `status`: pending, surfaced, confirmed,
rejected. Cannot exist without at least three supporting entry ids on three
distinct days.

## confirmed_patterns
`id`, `student_id`, `theme`, `supporting_entry_ids[]`, `confirmed_at`,
`reminder_armed`, `removed_at`

Only the student creates these, by confirming. `reminder_armed` is opt in, per
pattern. `removed_at` supports this is not me.

## pattern_rejections
`id`, `student_id`, `theme`, `rejected_at`, `reason`

Checked by the sweep so the same wrong idea is never offered twice.

---

## safety_flags
`id`, `entry_id`, `student_id`, `risk_level`, `categories[]`,
`classifier_version`, `action_taken`, `resources_shown`, `status`,
`reviewed_by`, `reviewed_at`, `created_at`

Its own record with a status field, not a boolean on an entry, because it
becomes a workflow when the counsellor console exists. Written on every entry,
hit or miss.

## generations
`id`, `entry_id`, `student_id`, `purpose`, `prompt_version`, `model_version`,
`provider`, `latency_ms`, `input_tokens`, `output_tokens`, `created_at`

`purpose` is safety, beat_one, mirror or tagger. Written by the gateway for
every call. This is how you tell whether a prompt change helped.

---

## prompts
`id`, `purpose`, `version`, `text`, `active`, `created_at`

Prompt text, crisis wording and thresholds live here, not in the app binary.
Flutter has no over the air updates and the words a student sees during a crisis
cannot wait on a store review.

## jobs
`id`, `type`, `payload`, `run_at`, `attempts`, `status`, `created_at`

Postgres backed queue rather than Redis. Check backs fire days later and must
survive deploys. Fewer services also means a shorter sub processor list.

## audit_log
`id`, `actor_id`, `actor_role`, `action`, `subject_student_id`, `subject_type`,
`subject_id`, `created_at`

Written from day one even though nobody reads it yet. Districts have inspection
rights and will ask who viewed what.

---

## Indexes that matter

- `entries (student_id, created_at desc)` for the context builder
- `tags (student_id, feeling)` and `tags (student_id, trigger)` for the sweep
- `jobs (status, run_at)` for the runner
- ivfflat or hnsw on `entry_embeddings.embedding`

## The query that finds a pattern

Roughly: group tags by theme for one student, count distinct entries and
distinct days, keep rows where both are at least three, exclude anything in
`pattern_rejections`, return with the supporting entry ids attached.

It is a query on purpose. When the app tells a student this is the third time,
we can show exactly which three entries and why.
