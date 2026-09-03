# Schema

Postgres. Drizzle for definitions and migrations. Every table carries student,
school and district identifiers and is protected by row level security.

Twenty three tables. This document and `db/src/schema.ts` are kept in step; the
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
`apple_user_id`, `display_name`, `age_band`, `gender`, `region`, `timezone`,
`latitude`, `longitude`, `profile_recorded_at`, `consent_recorded_at`,
`consent_version`, `notify_opt_in`, `created_at`

No surnames, no birthdates. `external_ref` is the rostering identifier. Keep
identifying information in the rostering system, not here.

`apple_user_id` is the Apple subject, written the first time the student signs
in on a device and null until then. Rostering creates the student, signing in
only attaches an account to a row that already exists. Apple issues a different
subject to every developer account, so the value joins against nothing outside
this database. It is unique, and it is written once: a row that already carries
one is never repointed at a second account.

The profile columns are what the student gives at first run, and every one of
them is nullable because every question is skippable. `display_name` is a first
name for the app to call them and nothing more. `age_band` is a band, not a
date, and the bands reach adulthood rather than stopping at eighteen.

`region` is either the region they picked or the one derived from their
coordinates, and `timezone` follows from it on the server, never sent by the
client.

`latitude` and `longitude` are exact coordinates, present only if the student
shared their location, and they are the most sensitive pair of columns here.
Nothing in the product needs them: the region and the hour a check back fires
work identically from the picker. They are held because the founder asked for
them, they are shown back to the student on the profile tab, and clearing them
there clears the columns. See decisions 056, 057, 060 and 061.

`email` is present once a user has signed in with one, lowercased, unique.
The only thing ever sent to it is a sign in code. Accounts people make for
themselves live in the Self signup district and school, with a random
`external_ref`, and look like every other row.

## app_events
`id`, `student_id`, `school_id`, `district_id`, `name`, `detail`,
`app_version`, `created_at`

What the app did and what it saw, written by the app. The product's own
diagnostics, since no third party SDK goes in the client. `detail` is a small
JSON object and never carries what a person wrote or said.

## email_codes
`id`, `email`, `code_hash`, `expires_at`, `attempts`, `consumed_at`,
`created_at`

Sign in codes. Only the hash is stored, a row is used once, expires in ten
minutes, and counts its attempts. Not scoped to a user, because the user may
not exist yet.

## sessions
`id`, `student_id`, `school_id`, `district_id`, `token_hash`, `created_at`,
`expires_at`, `revoked_at`

One row per signed in device. Only the sha256 hash of the token is stored, so
this table read in full still lets nobody in. The token is returned once and
after that it exists on the device and nowhere else.

The school and the district sit alongside the student because a row is the
answer to who is asking and that answer should not need a join. `revoked_at` is
set rather than the row deleted, so a district asking when a device stopped
being trusted still has something to read. Sessions expire in a hundred and
eighty days.

No policy and no grant for `soul_student`. The lookup happens before the role
becomes `soul_student`, so the request path never needs to read this table, and
leaving it readable would put every device's token hash within reach of a
student who already has a token of their own. See decision 063.

---

## entries
`id`, `student_id`, `school_id`, `district_id`, `text`, `input_mode`,
`transcript_confirmed`, `duration_ms`, `local_hour`, `created_at`

`text` is its own column, never inside a JSON blob, so it can be encrypted later
without a rewrite. `input_mode` is voice or typed. `transcript_confirmed`
records that the student saw the transcript and sent it.

No audio is stored. Ever. How it sounded is a `voice_tones` row.

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

## voice_tones
`id`, `entry_id`, `student_id`, `school_id`, `district_id`, `emotion`,
`intensity`, `intent`, `sounded`, `confidence`, `words_per_minute`, `pauses`,
`longest_pause_ms`, `hesitations`, `audio_events`, `language_code`,
`language_probability`, `mean_logprob`, `duration_ms`, `model_version`,
`created_at`

How a spoken entry sounded. One row per spoken entry, none for a typed one.
Written on the transcribe path before the entry exists, because the audio is
gone the moment the transcript returns, so `entry_id` is null until the
student sends and the row is deleted if they discard. `emotion` and `intent`
are fixed vocabularies so they can be counted. `sounded` is one sentence about
the recording, never the person. The prosody columns are measured from the
transcriber's word timings and are not opinions. Nothing here is shown to the
student yet. No audio is stored.

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

## cue_cards
`id`, `entry_id`, `student_id`, `school_id`, `district_id`, `about`,
`question`, `options`, `answered_yes`, `chosen_index`, `detail`, `decision_id`,
`prompt_version`, `model_version`, `answered_at`, `created_at`

A question about something the student said is coming up, answerable yes or no,
with a box under it. Written by a background job after tagging, never on the
request path, and only from entries the classifier cleared.

`options` is dead weight kept for the rows written before the card became a
yes or no question. Nothing writes it now. `answered_yes` is null until they
answer, which makes unanswered, yes and no three states rather than two.

A yes writes a `decisions` row and books the check back. A no writes neither.

---

## pattern_verdicts
`id`, `student_id`, `school_id`, `district_id`, `theme`, `verdict`, `source`,
`line`, `supporting`, `prompt_version`, `model_version`, `created_at`

Whether a theme is doing this student good or costing them, and the sentence
they read under it. `source` says who decided: `outcomes` when their own check
back answers did, `model` when nothing had been answered and the model judged
it from the entries. Their answer always wins.

The newest row per theme is the live one. Older rows stay as the record of what
was said about them and when.

---

## people
`id`, `student_id`, `school_id`, `district_id`, `name`, `relation`, `profile`,
`reach`, `name_is_theirs`, `relation_is_theirs`, `reach_is_theirs`, `mentions`,
`first_seen_at`, `last_seen_at`, `prompt_version`, `model_version`,
`profiled_mentions`, `created_at`

The people a student writes about. This table holds records about somebody who
is not a user of this product, did not agree to be described, and cannot read
or delete what is in it. That was decided deliberately and the shape is what
makes it defensible.

`name` is what the student calls them and nothing more. No surname, no contact
detail, nothing that would find this person anywhere else. `reach` is the
student's own note about how they would get hold of them.

`relation` and `profile` are written by the model from this student's entries
and describe what happens between the two of them, never what the other person
is like. The three `is_theirs` flags mark a field the student edited, and a
later profile run never writes over one.

Unique on student and name, so one name is one person until the student says
otherwise.

---

## entry_people
`id`, `entry_id`, `person_id`, `student_id`, `school_id`, `district_id`,
`said`, `created_at`

Where a person was mentioned, and the sentence they were mentioned in. `said`
is what the profile is written from. What a student reads back is the whole
entry, because one of their sentences lifted out of what they were saying reads
like evidence.

Unique on entry and person, so a job that runs twice does not inflate how often
somebody appears.

---

## Indexes that matter

- `sessions (token_hash)` unique, hit once on every authenticated request
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

---

## The two legacy tables

`legacy_feedback` and `legacy_users` hold people from the previous Soul Space
website: 135 survey answers and 50 accounts. They are here because they answered
questions about this product and some of them may already know who we are.

They are unlike every other table in this file and the difference is the point.

They carry no student, school or district column, because these people are none
of those things. They have no consent recorded here and they never agreed to
anything about this app.

Row level security is forced on both and the student role has no policy and no
grant on either, so the request path cannot read them at all. That is stricter
than `prompts` and the same intent as decision 027. Trying it as `soul_student`
returns permission denied rather than an empty result.

Each row keeps a `raw` column holding the original record exactly as exported.
The parsed columns are for querying, and `raw` is so that a field nobody thought
to map is still there later without going back to a file on somebody's laptop.

The source files are not in this repository and should not be. They contain
names, email addresses and phone numbers. `npm run import:legacy -w @soul/api`
takes their paths as arguments and is idempotent by source.
