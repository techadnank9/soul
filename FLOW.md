# Flow

How execution actually travels through this codebase. Entry points, call order,
what calls what, and where the AI touched the cycle.

Written before the code exists, so it is the intended flow. Keep it true. If you
change the path, change this file in the same commit.

---

## Entry points

There are only ten ways anything starts running.

| Entry point | Trigger | File |
| --- | --- | --- |
| Student taps the mic, then taps stop | Human | `app/lib/features/capture/capture_screen.dart` |
| Student taps send on the transcript | Human | `app/lib/features/capture/confirm_transcript.dart` |
| Student finishes the profile | Human | `app/lib/features/onboarding/profile_screen.dart` |
| Student edits their profile | Human | `app/lib/features/profile/profile_tab.dart` |
| Student answers the baseline | Human | `app/lib/features/onboarding/baseline_screen.dart` |
| Student taps look closer | Human | `app/lib/features/mirror/mirror_screen.dart` |
| Student opens a day | Human | `app/lib/features/day/days_screen.dart` |
| A scheduled job fires | Time | `api/src/jobs/runner.ts` |
| Nightly pattern sweep | Time | `api/src/jobs/runner.ts`, booked by `enqueue.ts` |
| A scheduler drains the queue | Time | `api/src/routes/jobs.ts`, calling the same `tick()` |

Everything else in the system is called by one of these ten.

The tenth is the same work as the eighth and ninth, reached differently.
`npm run worker` runs `tick()` in a loop forever, which suits a host that stays
up. `POST /jobs/drain` runs the same `tick()` a bounded number of times when
something with a clock asks it to, which suits a host that does not. It is the
only route with no student on it, and it carries a shared secret instead. With
no secret configured it refuses everybody.

---

## Flow 0: first run

Once, on a device that has never been used. Nothing here blocks anything: every
question can be skipped and a student who skips all of them still gets the
whole product.

```
main.dart / FirstRun
  └─ 0. intro_screen.dart
  │     what the app does, and three lines on what it is not
  │     no account, no sign up, no consent screen (decisions 048 and 055)
  │
  ├─ 1. profile_screen.dart
  │     name, age band, gender, where, one question at a time
  │     the where question offers the device before the list
  │        data/device_location.dart asks for permission, coarse failure and
  │        refusal both fall back to the picker, which is always on screen
  │     POST /profile  → services/profile/save.ts   ← background, nobody waits
  │        writes only the fields that arrived, and null empties a field
  │        coordinates decide the region, so a measured location always wins
  │        over a picked one in the same request. The profile tab can still
  │        set a region on its own later, which leaves the stored coordinates
  │        pointing somewhere else until they are shared again or forgotten
  │        derives timezone from region, never takes one from the client
  │        writes an audit_log row naming the fields, never the values
  │
  ├─ 2. baseline_screen.dart
  │     the ten questions, unchanged
  │     POST /baseline  → routes/consent.ts         ← background, nobody waits
  │
  ├─ 3. capture_screen.dart, the introduction
  │     tell us about yourself, spoken or typed
  │     POST /entries, the whole loop: consent, safety, beat one
  │     the line it generates is never shown. This entry is how the app
  │     learns who it is talking to, not a moment to reflect on, and a
  │     flagged one shows nothing either. See decision 063
  │
  ├─ 4. sign_in_screen.dart
  │     the terms, the privacy policy, an agreement that gates the button
  │     a development skip that is labelled as one
  │
  └─ 5. home
        the week ring, and on a new account nothing in it yet
```

Every question in first run is mandatory. The skips were removed on the
founder's call, so the name field, the four profile questions and all ten
baseline questions have to be answered to reach home. See decision 063.

The profile tab is the same endpoint from the other direction. It reads
`GET /profile`, shows every field held, and writes one field at a time. A field
sent as null empties it, which is how a student takes an answer back.

Both first run posts are fire and forget on purpose. A student should never wait on a
question that is a baseline for later rather than a result for now. The cost is
that a profile given with no connection is lost, and there is no retry.

---

## Flow 1: a student submits a reflection

This is the path that matters. Read it in order.

```
capture_screen.dart
  └─ tap to start, tap to stop. Not hold, so the phone can be set down.
  └─ records wav, sixteen kilohertz mono, to the system temp directory
  └─ waits for the file size to settle before reading it
     an unfinalised container reaches the provider as corrupt audio
  └─ POST /transcribe  → routes/transcribe.ts, two calls on the same bytes
  │     ├─ services/transcribe/run.ts
  │     │    ├─ consent/gate.ts   ← checked here too, before audio leaves
  │     │    ├─ provider call (ElevenLabs Scribe, config driven)
  │     │    └─ word timings measured into prosody: pace, pauses, hesitations,
  │     │       audio events, language. Measured, not judged
  │     ├─ services/tone/judge.ts, in parallel, allowed to fail
  │     │    ├─ consent/gate.ts   ← checked again, a second place audio leaves
  │     │    ├─ gateway.call('voice_tone', audio)  ← the only call that hears
  │     │    │    emotion, intensity, intent, one sentence, confidence
  │     │    └─ storeTone() → voice_tones row, entry_id null, returns toneId
  │     │       a failure here costs the student nothing. Transcript still returns
  │     └─ audio deleted immediately, never persisted
  │        the client deletes its temp file too, success or failure
  │        DELETE /transcribe/:toneId when the student discards the transcript
  └─ a typed entry skips all of the above and the confirm step with it.
     There is nothing to confirm about words a student typed themselves.
  └─ shows the transcript, student sends or discards
  └─ writes to local queue (survives connection loss)
  └─ POST /entries, carrying toneId for a spoken entry
       │
api/src/routes/entries.ts            ← HTTP boundary, zod validation only
  └─ resolveSession()                 → student, school, district
  └─ services/reflection/submit.ts    ← the orchestrator, read this one
       │
       ├─ 1. consent/gate.ts
       │     checkConsent(session, 'third_party_processing')
       │     FAILS → entry stored unprocessed, returns held state, STOP
       │
       ├─ 2. entries/store.ts
       │     insert entry, return entryId
       │     services/tone/store.ts linkTone(toneId, entryId)
       │        spoken entries only, scoped to the student and to rows not
       │        yet linked. A guessed id links nothing. Then loadTone()
       │     Storage comes before classification because a safety_flags row
       │     carries entry_id and cannot be written for an entry that does not
       │     exist yet. Nothing is generated here and nothing is sent out.
       │
       ├─ 3. safety/classify.ts
       │     classify(text, session, entryId) → gateway.call('safety', ...)
       │     writes safety_flags row always, hit or miss
       │     classifier unreachable → treated as high risk, not as a pass
       │     HIT → returns help screen payload, STOP. No generation happens.
       │
       ├─ 4. generate/beatOne.ts
       │     buildBeatOnePrompt(entry, tone) ← current entry only, minimal history
       │                                      plus how it sounded, when spoken
       │     gateway.call('beat_one', ...)  ← not streamed, see the note below
       │     writes generations row with prompt_version, model_version
       │
       └─ 5. jobs/enqueue.ts
             enqueue('tag_entry', { entryId })    ← async, nobody waits
             enqueue('embed_entry', { entryId })  ← async, lands with task 8
```

Two things to notice. Consent comes before storage, safety comes before
generation, and neither can be skipped by any path. And the function that
returns the response does not call the tagger; it enqueues it.

This flow is not streamed anywhere. `submit()` awaits the classifier, then
awaits beat one, then returns one complete body, and the client reads it whole.
The under three seconds target in task 6 is measured against that, and nothing
has measured it yet.

---

## Flow 2: the student asks to look closer

```
mirror_screen.dart
  └─ POST /entries/:id/mirror
       │
api/src/routes/entries.ts
  └─ services/reflection/mirror.ts
       │
       ├─ 1. memory/buildContext.ts        ← the single most important function
       │     confirmed patterns (verbatim)
       │     kept lines
       │     open decisions and past outcomes
       │     recent entries, each with one clause on how it sounded if spoken
       │     services/tone/store.ts loadTone(entryId) for this entry
       │     pgvector neighbours of this entry
       │     returns a stable prefix, ordered identically every time
       │
       ├─ 2. generate/mirror.ts
       │     buildMirrorPrompt(context, entry, tone)  ← history first, entry last
       │     gateway.call('mirror', ...)
       │     parseStructured() → zod schema, REJECT on failure, never store prose
       │
       └─ 3. returns tension, underneath, question
```

`buildContext` is a pure function: student and entry in, prompt string out.
Everything about memory quality lives there. It is the first place to look when
a response feels wrong, and it must stay testable and loggable.

---

## Flow 3: the decision and its outcome

```
mirror_screen.dart, student types what they might do
  └─ POST /decisions
       │
services/decisions/create.ts
  ├─ stores BOTH:
  │     offered_text   ← what the Mirror suggested
  │     chosen_text    ← what the student actually wrote
  ├─ jobs/enqueue.ts → schedule('check_back', { decisionId }, at: horizon)
  └─ done

...days later...

jobs/runner.ts fires check_back
  └─ services/decisions/checkBack.ts
       ├─ sends the neutral prompt
       └─ on reply, services/decisions/recordOutcome.ts
             writes outcome, what they did, whether it felt lighter
             IGNORED also counts. Write the ignore.
```

The gap between `offered_text` and `chosen_text` is the most interesting data in
the system. Never collapse them into one column.

---

## Flow 4: tagging, async

```
jobs/runner.ts fires tag_entry
  └─ services/tagging/tag.ts
       ├─ services/tone/store.ts loadTone(entryId), null for a typed entry
       ├─ gateway.call('tagger', entryText + how it sounded)
       ├─ parseStructured() → { trigger, feeling, coping, confidence }
       └─ insert tags row
```

Runs after the student has already seen their response, so tagging quality never
costs latency. Low confidence tags must not be allowed to support a pattern
claim downstream.

---

## Flow 5: pattern candidates, nightly

```
jobs/pattern_sweep.ts
  └─ services/patterns/findCandidates.ts
       ├─ SQL, not a model call:
       │    same theme across ≥3 entries on ≥3 distinct days
       ├─ excludes anything in pattern_rejections
       └─ insert pattern_candidates with supporting_entry_ids

...next time the student reflects...

services/reflection/mirror.ts
  └─ patterns/surfaceCandidate.ts     ← attaches the question to the Mirror

...student answers...

services/patterns/answer.ts    → one entry point, three answers
     fits         → confirmed_patterns row, needs three supporting entries
     not the same → pattern_rejections row, never offered again
     later        → back to pending, offered again another time
```

A confirmed pattern immediately becomes part of `buildContext`, which is how the
loop closes and why the product gets better the longer someone uses it.

---

## Consent, and where it lives

Consent is recorded by the district at rostering and read by
`consent/gate.ts`. `routes/consent.ts` records it, reads it and writes an audit
row. No student has ever seen a consent screen, per decision 048.

The sign in screen at the end of first run is a different thing and should not
be mistaken for it. It records an agreement to the terms and the privacy
policy, in the app, from the student. Whether a school product should be asking
a child for that at all is open, and it is written up in the decision log.

---

## The read side

Everything above this line writes. These four read, and until they existed the
client could only send. Every screen showed fixed strings from a sample file,
which is why a student on their first day was shown somebody else's week.

```
GET /week       → services/reads/week.ts        the ring, the count, seven days,
                                               and what they are still holding
GET /days       → services/reads/days.ts       every day with something in it
GET /day/:date  → services/reads/day.ts        one day, and its cue cards
GET /patterns   → services/reads/patterns.ts   good, bad, and still forming
GET /reflection → services/reads/reflection.ts one theme, and the entries
                                               behind it
GET /people     → services/people/read.ts      who they write about
GET /people/:id → services/people/read.ts      one person, and where they
                                               come up
```

Three things hold across all of them.

They run inside `asStudent()`, so the row level security role is doing the
scoping and not only the where clause. This is the first code on the request
path that uses it, and decision 026 always said it should.

Days and weeks are cut by the student's own timezone, from `students.timezone`,
falling back to UTC. An entry written late on Sunday evening in Los Angeles is
on Sunday. The seed script learned this the hard way by writing Los Angeles
times into a London student and sliding half the week.

No path takes a student id. There is no id to get wrong.

The write side is a different shape and worth stating plainly. It runs on the
pooled handle rather than inside `asStudent`, so row level security is not
scoping it and the where clause is. Anywhere a write takes an id from the
request, that id is matched against the session's student as well. Decision 188
is the three places where it was not, and what that allowed.

---

## What runs in the background

Nothing below is on the request path. The runner claims one job at a time with
a row lock, so two workers never run the same one.

```
tag_entry        the tagger, and it books the two below
cue_cards        a yes or no question about something they said is coming up
people           the people named in one entry, from its own words
person_profile   what happens between the student and somebody, once that
                 person has come up twice
pattern_sweep    the nightly candidate query, which books the verdicts
pattern_verdicts whether a theme is doing them good or costing them
check_back       days later, on the day they named
embed_entry      never claimed. The runner only claims what it can run, so
                 these stay pending until task 8 gives them a worker
```

Two of these write about somebody who is not a user of this product. See the
people tables in SCHEMA.md and the decision log for what that means and what
was done to narrow it.

---

## The model gateway

Every model call in the system goes through one file: `api/src/gateway/call.ts`.
Nothing calls a provider SDK directly.

```
gateway.call(purpose, input)
  ├─ looks up config for purpose: model, provider order, temperature
  ├─ loads prompt text from the database (never from the binary)
  ├─ tries OpenAI → Gemini → OpenRouter in order
  ├─ validates the response against the purpose's zod schema
  └─ writes a generations row: prompt_version, model_version, latency, purpose
```

If you need a model call, add a purpose. Do not add an SDK import.

---

## Where the AI has been in this cycle

Four places, and only four. Everything else is deterministic code.

| Purpose | Where | Blocking | What happens if it is wrong |
| --- | --- | --- | --- |
| `safety` | Flow 1, step 2 | Yes | The most serious failure in the system |
| `beat_one` | Flow 1, step 4 | Yes | Response reads generic, student does not return |
| `mirror` | Flow 2, step 2 | Yes | Rejected by the schema, or reads as advice |
| `tagger` | Flow 4 | No | Patterns downstream are noise |

Pattern detection is **not** on this list. It is a database query. That is
deliberate, so we can always show a student the exact entries behind any claim.

---

## Before accepting a major change

Any change that touches `submit.ts`, `buildContext.ts`, `call.ts`, the safety
path, the consent gate, or the schema is major.

Before merging, ask the AI to quiz you on it. Five questions, and you should be
able to answer all five without opening the diff:

1. What is the new call order, and what did it used to be?
2. Which function is now doing something it was not doing before?
3. Can the safety classifier still not be skipped? Show the path.
4. What does this change put into the model prompt that was not there before?
5. If this is wrong at 2am for one student, what breaks and what still works?

If you cannot answer, you do not understand the change well enough to own it at
2am. Do not merge it.

---

## Invariants

These hold everywhere. A change that breaks one is wrong regardless of what it
improves.

1. No generation before `classify()` returns. The tone call on the transcribe
   path is a classification of the audio, not a generation: nothing it
   returns is shown to a student, and the words still pass `classify()`
   before anything is written back.
2. No outbound model call before `checkConsent()` passes.
3. Every query carries student, school and district. Row level security enforces
   it; application code does not get to be the only guard.
4. `parseStructured()` rejects rather than storing free prose.
5. Every generation writes `prompt_version` and `model_version`.
6. Prompt text and crisis wording come from the database.
7. The tagger never runs on the request path.
8. Nothing is written to `confirmed_patterns` without a student confirmation and
   at least three supporting entry ids.

   Note what this no longer covers. `pattern_verdicts` is written without any
   confirmation and says plainly whether a theme is worth keeping or worth
   stopping. That is a founder decision taken against the earlier clinical
   guidance, on purpose, and it is written up in CONTEXT.md and the decision
   log. The student's own outcomes still outrank it.
9. Audio is never persisted. It is deleted the moment a transcript returns.
   What is kept about a recording is a `voice_tones` row: a fixed vocabulary
   word for emotion and one for intent, one sentence, and numbers measured
   from word timings. The row goes when the transcript is discarded and
   cascades when the entry is deleted.
10. No entry is submitted without the student having seen the transcript. A
    typed entry has nothing to confirm and skips the step; a spoken one never
    does.
11. A transcript never lands in the typing field. It goes to the confirm step,
    send or discard, because it is the permanent record and the text the safety
    classifier reads.
12. Consent has no student facing screen. It is recorded at rostering and read
    by the gate. The sign in screen at the end of first run records an
    agreement to the terms and the privacy policy, which is a different thing
    and must not be mistaken for it.
13. A card is only ever about something the student named themselves, and a
    person only ever exists because they named them. Neither is invented, and
    an empty answer is the common one.
14. Anything the app holds about a person can be edited and deleted by the
    student who wrote it. The entries stay theirs either way.
