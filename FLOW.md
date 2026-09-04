# Flow

How execution actually travels through this codebase. Entry points, call order,
what calls what, and where the AI touched the cycle.

Written before the code exists, so it is the intended flow. Keep it true. If you
change the path, change this file in the same commit.

---

## Entry points

There are only eleven ways anything starts running.

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
| Nightly consolidation | Time | `api/src/jobs/runner.ts`, booked by `enqueue.ts` |
| A scheduler drains the queue | Time | `api/src/routes/jobs.ts`, calling the same `tick()` |

Everything else in the system is called by one of these eleven.

The eleventh is the same work as the eighth, ninth and tenth, reached
differently.
`npm run worker` runs `tick()` in a loop forever, which suits a host that stays
up. `POST /jobs/drain` runs the same `tick()` a bounded number of times when
something with a clock asks it to, which suits a host that does not. It is the
only route with no student on it, and it carries a shared secret instead. With
no secret configured it refuses everybody.

---

## Flow 0: first run

Once, on a device that has never been used. Nineteen screens in one sequence,
walked with a progress bar over the fourteen questions, a back chevron and a
slide between steps. `first_run.dart` owns that chrome and holds the answers;
each screen is only its own question.

Before any of it, the phone gets an account. `FirstRun` asks
`POST /auth/device` the moment it opens, `auth/accounts.ts` makes a row in the
self signup district and issues a session, and the token is in the keychain
before the intro's continue is pressed. Everything first run writes goes into
that account. An account a person makes is agreed from the moment it exists:
`createAccount` records consent as it inserts the row, so nothing a person
says or writes ever waits on a checkbox. `POST /consent` and the
`release_held` job remain for rostered accounts whose district records
consent later.

```
main.dart → onboarding/first_run.dart, FirstRun
  └─ POST /auth/device → auth/accounts.ts, a session before a single question
  └─ 0. intro_screen.dart, the welcome
  │     what reflection is, a sign in for somebody who has been here before
  │     no account, no sign up, no consent screen (decisions 048 and 055)
  │
  ├─ 0b. how_it_works_screen.dart
  │     the four things that happen every time, revealed one a second, and
  │     what the app is not. A tap shows all of it at once
  │
  ├─ 1. profile_screen.dart
  │     name, age band, gender, where, one question per screen, each with
  │     its own continue that is dim until there is an answer
  │     the where question is a world map, continent then country, then a
  │     card with the country's states and the state's cities, each with a
  │     search; the phone is asked first. The country and state decide which
  │     of the sixteen regions is stored, and city, state and country are
  │     held as words in place. location_picker.dart holds the names
  │        data/device_location.dart asks for permission, coarse failure and
  │        refusal both fall back to the map, which is always on screen
  │        world_map.dart holds the coastlines and the projection
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
  │     the ten questions, unchanged, one per screen, each answered by a
  │     movement from baseline_scenes.dart: a light dragged to a corner, an
  │     answer sunk in a pond, a wall pushed over, a sun raised. No
  │     continue: a scene settles once chosen and the next follows
  │     POST /baseline  → routes/consent.ts         ← background, nobody waits
  │
  ├─ 3. capture_screen.dart, the introduction
  │     tell us about yourself, spoken or typed
  │     POST /entries, the whole loop: consent, safety, beat one
  │     the line it generates is never shown. This entry is how the app
  │     learns who it is talking to, not a moment to reflect on, and a
  │     flagged one shows nothing either. See decision 063
  │
  ├─ 3b. ready_screen.dart
  │     what was given, handed back as it was given, and nothing scored
  │     no back from here: the introduction has already been sent
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
baseline questions have to be answered to reach home. The continue on the
profile questions is dim until there is an answer, and a baseline scene moves
on only once something has been chosen. See decisions 211 and 212 for the
screens and the contradiction this paragraph used to sit under.

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
  └─ POST /speech/token  → routes/speech.ts
  │     consent/gate.ts, then a single use token from ElevenLabs. The key
  │     never reaches the phone; the token opens one connection and dies in
  │     fifteen minutes
  └─ features/capture/live_speech.dart
  │     a WebSocket straight from the phone to the transcriber, raw sixteen
  │     kilohertz samples up, words back while the person is speaking.
  │     partial_transcript is the guess, committed_transcript is settled, and
  │     both are written into the same box typing uses, after whatever was
  │     typed. The waves are the loudness of each chunk. Stop sends a commit
  │     and waits up to two and a half seconds for the tail
  └─ POST /tone  → routes/speech.ts, in the background after stop
  │     the audio the phone held in memory, judged once by
  │     services/tone/judge.ts, stored as a voice_tones row, then dropped.
  │     Nobody waits: send can go before it lands and the entry has no tone
  └─ send is the same button as for typing. No confirm screen: the words were
     on the screen as they were said and could be fixed there
  └─ POST /transcribe still exists for a whole file, and nothing calls it
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
             enqueue('embed_entry', { entryId })  ← async, flow 6
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
       │     open facts this entry touches, in their words, oldest first,
       │        each with the outcomes of decisions on the entries behind it.
       │        Touched means the subject or object is a word in the entry,
       │        or the fact's embedding is near the entry's
       │     the nearest twelve earlier entries by embedding, from any time,
       │        never one of the recent eight and empty until the entry has
       │        been embedded in the background
       │     recent entries, each with one clause on how it sounded if spoken
       │     services/tone/store.ts loadTone(entryId) for this entry
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

Three sources fused, the way docs/memory.md describes: time is the recent
eight, meaning is the nearest twelve by vector, and the graph is the open
facts with their outcomes. Only the Mirror reads it. Beat one still gets the
current entry and how it sounded, nothing more, and that is deliberate.

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
       ├─ insert tags row
       └─ enqueue cue_cards, people, extract_facts   ← each its own job

jobs/runner.ts fires extract_facts
  └─ services/memory/facts.ts
       ├─ loads the open facts already held, newest forty
       ├─ gateway.call('facts', entryText + the held facts)
       ├─ parseStructured() → { facts: [subject, predicate, object, sentence, confidence] }
       ├─ said again (same subject, predicate, object) → entry id joins the open fact
       ├─ contradicted (same subject and predicate, new object)
       │     → old fact gets valid_to, never deleted
       ├─ gateway.embed(sentence) → the fact's vector, null if it fails
       └─ insert facts row, tier 0, valid_from = the entry's time
```

Runs after the student has already seen their response, so tagging quality never
costs latency. Low confidence tags must not be allowed to support a pattern
claim downstream.

The facts step is booked by the tagger rather than run inside it, so an entry
is never left untagged because a fact could not be written. Everything a fact
says is a situation in the student's words, never a trait, under the same
rule the tagger runs under.

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

## Flow 6: embedding, async

```
jobs/runner.ts fires embed_entry
  └─ services/memory/embed.ts
       ├─ gateway.embed(entryText)        ← OpenAI, text-embedding-3-small
       └─ upsert entry_embeddings row, model_version on it
```

Booked by submit and by release alongside the tagger. Until it has run the
entry is simply not found by meaning, and nothing waits on it. The rows that
queued between task 8 and this job existing were run the first time the
runner named the type.

---

## Flow 7: consolidation, nightly

```
jobs/runner.ts fires consolidate_memory
  └─ services/memory/consolidate.ts
       ├─ SQL: everybody with an open tier 0 fact learned since their last
       │    consolidation, which is their newest generations row with the
       │    purpose consolidate, or ever when they have none
       └─ for each person, one at a time, consent checked first
            ├─ loads the new facts, the older open tier 0 facts, and the
            │    tier 1 observations already written
            ├─ gateway.call('consolidate', the three lists, numbered)
            ├─ parseStructured() → { observations: [subject, predicate,
            │    object, sentence, drawnFrom numbers, confidence] }, at most 3
            ├─ an observation drawn from fewer than two facts, or from none
            │    of tonight's, is dropped
            ├─ said again at tier 1 → the entry ids join the open observation
            ├─ turned over (same subject and predicate, new object) → the old
            │    tier 1 row gets valid_to. Tier 1 never closes tier 0
            ├─ gateway.embed(sentence) → the observation's vector, null if it fails
            └─ insert facts row, tier 1, entry_ids = every entry behind the
                 facts it was drawn from, valid_from = the earliest of them
  └─ books itself for the next night, the way the sweep does
```

The episodic to semantic step in docs/memory.md. It writes into the same
facts table, so a tier 1 row is opened to its entries like any other fact
and is read by `buildContext` like any other open fact. One person's failure
is logged and the night goes on; their facts are still new tomorrow. Nothing
here is on a request path.

---

## What the app reports

The app has no analytics or crash reporting SDK and never will. Instead it
posts small events to `POST /events`, `routes/events.ts`, which writes an
`app_events` row and one log line. Names are fixed strings, the detail is a
status code or a count, and nothing in it is what a person wrote or said.
Reading the service logs during a session shows the whole path: account made,
consent recorded, recording sent and how it ended, entry submitted and in
which state. The server logs the outcome of every transcribe and entry too.

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
GET /graph      → routes/graph.ts              the person as nodes and edges:
                                               open facts, people, patterns,
                                               decisions and outcomes. The
                                               map tab and a later admin
                                               screen read it
```

Three things hold across all of them, the graph included.

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
tag_entry        the tagger, and it books the three below
cue_cards        a yes or no question about something they said is coming up
people           the people named in one entry, from its own words
extract_facts    what the entry says is so, closing what it contradicts
person_profile   what happens between the student and somebody, once that
                 person has come up twice
pattern_sweep    the nightly candidate query, which books the verdicts
pattern_verdicts whether a theme is doing them good or costing them
consolidate_memory
                 nightly, per person with new facts: at most three things that
                 hold across several facts, written as tier 1 facts
check_back       days later, on the day they named
embed_entry      one vector per entry, booked by submit and by release
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

```
gateway.embed(text)
  ├─ OpenAI only, text-embedding-3-small, cut to the column's 1536
  ├─ no prompt and no schema: the check is that the numbers are the right count
  └─ writes a generations row: purpose embedding, prompt_version none
```

Every vector in the database comes from that one model. A second model would
need every row embedded again, not a config change.

---

## Where the AI has been in this cycle

Four places, and only four, on the request path. Everything else is
deterministic code or a background job.

| Purpose | Where | Blocking | What happens if it is wrong |
| --- | --- | --- | --- |
| `safety` | Flow 1, step 2 | Yes | The most serious failure in the system |
| `beat_one` | Flow 1, step 4 | Yes | Response reads generic, student does not return |
| `mirror` | Flow 2, step 2 | Yes | Rejected by the schema, or reads as advice |
| `tagger` | Flow 4 | No | Patterns downstream are noise |
| `facts` | Flow 4 | No | The Mirror is told something they did not say |
| `embedding` | Flow 6 | No | The wrong earlier entries are read back |
| `consolidate` | Flow 7 | No | The Mirror is told a pattern across weeks that the facts do not carry |

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
12. Consent is recorded by the district at rostering, or by the person
    themselves on the sign in screen for an account they made, and it is read
    by the gate. Until it is recorded nothing leaves. What was written before
    it is released through the classifier afterwards, never around it.
13. A card is only ever about something the student named themselves, and a
    person only ever exists because they named them. Neither is invented, and
    an empty answer is the common one.
14. Anything the app holds about a person can be edited and deleted by the
    student who wrote it. The entries stay theirs either way.
