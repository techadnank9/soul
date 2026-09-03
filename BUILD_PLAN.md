# Build plan

Ordered. Each task states what gets built, how, and what has to be true before
moving on. The order is not arbitrary: everything before task 6 exists to make
task 6 possible, and task 6 is the one that decides whether the product works.

Do not start a task without being asked.

**Current state is in README.md.** The short version: tasks 1 through 6 and 8
through 13 are built, task 0 was never done, and task 7 has not started. The
order was not followed. Task 0 needs hardware and real students, and the rest
was built around it rather than after it. That is a real gap, not a completed
step, and decisions 010 and 017 still rest on it.

---

## Task 0 — Two experiments before any architecture

Both can invalidate decisions already made, so they come first.

**0a. The keyboard test.** Build screen 6 alone in Flutter, nothing behind it. A
scrolling card with a text field inside it and a serif at 17 points. Type into it
on a real iPhone and a real Android. This is the single most likely place the app
feels broken, and it is cheap to find out now.

**0b. The transcription comparison.** Record forty clips from students in the
real age range and the real environment, noisy corridors included. Run each
through ElevenLabs Scribe and through Whisper. Correct both by hand. Count meaning
changes, not word errors.

This matters more than it sounds. Published research puts word error rates for
child speech far above adult speech, and worse again in classrooms, and worst for
students from non English speaking homes. There is no edit step in this product,
so the transcript is the permanent record and the input to the safety classifier.

Done when: text entry feels right on both platforms, and you have a measured
meaning change rate for both providers on real student audio.

**Still open.** Neither half has been done. The keyboard has only been typed
into on a simulator, which uses a hardware keyboard and cannot show what the
software one does to the layout. No student audio has been recorded or compared,
and the machine used for development has no microphone at all.

---

## Task 1 — Schema first

See SCHEMA.md. Fourteen tables.

Rules baked in from the start, because they are expensive to retrofit:

- Every row carries student, school and district identifiers, even though there
  is one of each today
- Row level security policies on every table, tested by trying to read another
  student's row and failing
- Entry text in its own column, not inside a JSON blob, so it can be encrypted
  later without a rewrite
- Safety flags are their own records with a status field, not a boolean
- audit_log is written to from day one even though nobody reads it yet
- prompt_version and model_version columns on every generated row

Done when: migrations run clean, and a query as student A returns nothing
belonging to student B.

---

## Task 2 — The API skeleton

TypeScript service, one endpoint that accepts an entry and returns a stub
string. Session resolves student, school and district. Zod schemas shared with
the client contract.

Done when: the Flutter app can post an entry and get a response back.

---

## Task 3 — Transcription

Record on device, upload, transcribe, delete the audio immediately. Never
persist it, never let it reach a backup.

Behind a single `transcribe()` function with the provider in config, the same
pattern as the model gateway, so switching provider is a config change.

Then the confirm step: show the student the transcript with send or discard. Not
an edit field. Given the error rates on child speech, an unreviewed permanent
record is not defensible.

Typing is an equal path on the same screen, not a fallback, because the students
recognised worst are disproportionately those from non English speaking homes.

Done when: audio is provably absent from storage and backups after a submission,
and a student can discard a bad transcript.

---

## Task 4 — Safety classifier

Before any generation exists, so it can never be skipped later. A small fast
model call, blocking, on the write path. Stores risk level, categories,
classifier version and action taken, on every entry, hit or miss.

Bias the threshold toward false positives. A wrongly flagged entry costs a
student one screen. A missed one costs much more, and the transcript it reads may
be imperfect.

Write the human help screen now too, including the option to reach someone the
student already knows.

Done when: a test entry containing distress returns the help screen instead of a
reflection, and the flag is recorded.

---

## Task 5 — Consent gate

Sits in front of any outbound call, transcription and models both. Confirms
school consent covers third party processing for this student. Without it the
entry is stored unprocessed and nothing goes out.

Done when: with consent revoked, an entry saves but no external call is made.

---

## Task 6 — Capture and beat one

Screens 3 and 5. Voice or text in, one line back, streamed. Local queue so a
dropped connection loses nothing. Current entry only in the prompt, minimal
history, because specificity and speed are the whole point.

Done when: from tapping the mic to seeing the first word is under three seconds
on a mid range Android on school wifi.

---

## Task 7 — Make beat one good

Not a coding task. The most important one.

Collect 20 real entries. Write beat one candidates. Judge them by hand against
one rule: could this line be pasted into a different person's entry unchanged? If
yes, it failed.

Iterate the prompt. Keep every version. Build the eval fixture set here: those 20
entries with hand written verdicts become the thing every future prompt change is
measured against.

Done when: 15 of 20 lines name something specific that only that entry contained.

**If this cannot be reached, stop. Nothing downstream fixes a generic first
line.**

**Not started.** Everything downstream of this is built, which means the risk
this task exists to catch has not been caught. The prompt in `prompts/beat_one.v1.md`
has never been measured against real entries.

---

## Task 8 — The Mirror and the decision

Screen 6. Second model call, only on request. Full context: confirmed patterns
verbatim, kept lines, open decisions, outcomes, recent entries, pgvector
neighbours. History first as a stable prefix so providers cache it, current entry
last.

Structured output validated against a schema before display or storage. Tension,
what sits underneath, one question, all phrased so they can be rejected.

Then the decision field. Store two things separately: what the Mirror offered,
and what the student actually chose.

Done when: the Mirror returns valid structured output on 20 out of 20 test
entries, with no diagnosis or advice in any of them.

---

## Task 9 — Tagging, invisible

Async worker. Extracts trigger, feeling, what they did next, plus a confidence
score. Nothing shown to the student.

Then hand tag 50 entries yourself and compare. This is the only way to know
whether the layer everything downstream depends on is any good.

Done when: agreement with your own labels is high enough that you would defend a
pattern built on them.

---

## Task 10 — Check backs and outcomes

Screen 8. A durable job scheduled for the day the student named, surviving
deploys. Neutral wording. Outcome stored either way, including ignored.

Done when: a job scheduled for three days out fires after a redeploy.

---

## Task 11 — Home, with empty states first

Screen 4. Build the day one version before the full one: no week circle, no
patterns, one invitation. Then the populated version.

Done when: a brand new account looks intentional rather than broken.

---

## Task 12 — Pattern candidates and confirmation

Screens 9 and 10. A query, not a model call: same theme across three separate
entries on separate days, or nothing is proposed. Candidates surface as a
question inside a later reflection. Confirmations and rejections both stored.

Done when: no pattern can be surfaced without the three supporting entries being
retrievable and displayable.

---

## Task 13 — The day view

Screen 7. A lens over data that already exists by this point. Cheap, and last for
that reason.

---

## Running throughout

- Prompt text, crisis wording and thresholds live in the database, never in the
  binary
- Every generated row records prompt version and model version
- The eval fixture set from task 7 is rerun on every prompt change
- No third party analytics or crash SDKs in the student app
- Every unprompted decision gets logged in DECISIONS.md

## Not in this plan

Counsellor console, district admin, circles, personalization by user group,
SOC 2 and district contracting. All deferred, see docs/staff-roles-later.md.

## The two open questions that can change the plan

1. **Accessibility.** Ask one district technology director what their review
   actually involves. If VoiceOver and TalkBack conformance is a hard gate,
   Flutter may not survive it and the client decision reopens.

2. **Under 13.** Sofia's consultation covered ages 16 to 18. Nobody has reviewed
   this product for younger children, and the escalation policy, what gets
   reported to whom and how the student is told, has no written answer yet.
