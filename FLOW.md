# Flow

How execution actually travels through this codebase. Entry points, call order,
what calls what, and where the AI touched the cycle.

Written before the code exists, so it is the intended flow. Keep it true. If you
change the path, change this file in the same commit.

---

## Entry points

There are only four ways anything starts running.

| Entry point | Trigger | File |
| --- | --- | --- |
| Student holds the mic | Human | `app/lib/features/capture/capture_screen.dart` |
| Student taps send | Human | `app/lib/features/capture/confirm_transcript.dart` |
| Student taps look closer | Human | `app/lib/features/mirror/mirror_screen.dart` |
| A scheduled job fires | Time | `api/src/jobs/runner.ts` |
| Nightly pattern sweep | Time | `api/src/jobs/pattern_sweep.ts` |

Everything else in the system is called by one of these four.

---

## Flow 1: a student submits a reflection

This is the path that matters. Read it in order.

```
capture_screen.dart
  └─ records audio
  └─ POST /transcribe  → services/transcribe/run.ts
  │     ├─ consent/gate.ts   ← checked here too, before audio leaves
  │     ├─ provider call (Deepgram, config driven)
  │     └─ audio deleted immediately, never persisted
  └─ shows the transcript, student sends or discards
  └─ writes to local queue (survives connection loss)
  └─ POST /entries
       │
api/src/routes/entries.ts            ← HTTP boundary, zod validation only
  └─ resolveSession()                 → student, school, district
  └─ services/reflection/submit.ts    ← the orchestrator, read this one
       │
       ├─ 1. consent/gate.ts
       │     checkConsent(studentId, 'third_party_processing')
       │     FAILS → entry stored unprocessed, returns held state, STOP
       │
       ├─ 2. safety/classify.ts
       │     classify(text) → gateway.call('safety', ...)
       │     writes safety_flags row always, hit or miss
       │     HIT → returns help screen payload, STOP. No generation happens.
       │
       ├─ 3. entries/store.ts
       │     insert entry, return entryId
       │
       ├─ 4. generate/beatOne.ts
       │     buildBeatOnePrompt(entry)      ← current entry only, minimal history
       │     gateway.call('beat_one', ...)  ← streamed
       │     writes generations row with prompt_version, model_version
       │
       └─ 5. jobs/enqueue.ts
             enqueue('tag_entry', { entryId })   ← async, nobody waits
```

Two things to notice. Consent and safety come before storage and generation, so
there is no code path where they can be skipped. And the function that returns
the response does not call the tagger; it enqueues it.

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
       │     recent entries
       │     pgvector neighbours of this entry
       │     returns a stable prefix, ordered identically every time
       │
       ├─ 2. generate/mirror.ts
       │     buildMirrorPrompt(context, entry)  ← history first, entry last
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
       ├─ gateway.call('tagger', entryText)
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

services/patterns/confirm.ts   → confirmed_patterns row
services/patterns/reject.ts    → pattern_rejections row, never offered again
```

A confirmed pattern immediately becomes part of `buildContext`, which is how the
loop closes and why the product gets better the longer someone uses it.

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

1. No generation before `classify()` returns.
2. No outbound model call before `checkConsent()` passes.
3. Every query carries student, school and district. Row level security enforces
   it; application code does not get to be the only guard.
4. `parseStructured()` rejects rather than storing free prose.
5. Every generation writes `prompt_version` and `model_version`.
6. Prompt text and crisis wording come from the database.
7. The tagger never runs on the request path.
8. Nothing is written to `confirmed_patterns` without a student confirmation and
   at least three supporting entry ids.
9. Audio is never persisted. It is deleted the moment a transcript returns.
10. No entry is submitted without the student having seen the transcript.
