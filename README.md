# Soul

A reflection app for students. A student speaks for thirty seconds about
something that just happened. The app reflects it back in one line, offers to
look closer, and asks what they might do about it. Days later it asks how that
went. Over months, the things that keep returning become patterns the student
themselves confirms.

It is not therapy, not a diagnosis, and not a chatbot you can talk to
indefinitely. Every path in the product ends with the student acting, deciding,
or talking to a human.

## Why it exists

There is a gap between something happening and a person deciding what to do
about it. Therapy fills the weeks after; friends fill some of it; nothing fills
the two minutes in the middle. That is the space this product occupies.

## What makes it different

Most reflection tools store what you wrote. This one also records what you did
and how it turned out. A student says they will talk to their teacher by Friday;
on Friday the app asks whether they did. That produces patterns built on
behaviour rather than on text, which is both more useful to the student and
harder for anyone else to reproduce.

Everything the app says about a person traces back to specific entries that
student can see and delete. Nothing becomes a pattern until they agree it is one.

## Who it is for

Students in schools, including under 13. The product is sold to districts, which
means school consent, per district data agreements, an audit trail, and a
written escalation path when something serious appears. Those constraints shape
the architecture more than any feature does.

## How it works

Three layers of memory feed every response:

- Always loaded: confirmed patterns, kept lines, open decisions, recent entries
- Queried: a few descriptive tags per entry, so finding a repeat is a database
  query and we can always show the exact entries behind a claim
- Semantic fallback: an embedding per entry in the same Postgres, for when the
  same experience is described in different words

Two model calls, not one. A short fast call that lands in under three seconds,
and a fuller reflection only if the student asks for it. A safety classifier
runs before either, blocking, on every entry.

## Stack

| Layer | Choice |
| --- | --- |
| App | Flutter, iOS and Android. One runtime dependency, `record`, for the microphone |
| Transcription | ElevenLabs Scribe, audio deleted immediately, never stored |
| Tone | The same recording heard once by an OpenAI audio model, judged for emotion and intent, stored as words and numbers, never as audio |
| API | TypeScript and Node |
| Database | Postgres 17 with pgvector, row level security. Supabase in production, local Postgres in development |
| Schema | Drizzle |
| Jobs | Durable, Postgres backed |
| Memory | A temporal graph in the same Postgres: facts with validity windows, nightly consolidation, an embedding per entry and per fact, and a graph endpoint. docs/memory.md |
| Errors | Sentry, app and service, on only when a DSN is set |
| Models | OpenAI primary, Gemini second, OpenRouter fallback. gpt-5 for beat one, the Mirror and the tagger, gpt-5-mini for safety |
| Observability | Prompt and model version stored on every generated row |

## Rules the code has to hold

1. No response is generated before the safety classifier returns.
2. Nothing leaves for a third party before consent is confirmed for that student.
3. Every row is scoped to one student in one district, enforced in the database.
4. A pattern is never asserted. It is proposed as a question, and stored only
   when the student confirms it. Rejections are stored too.
5. Tags describe a situation, never a trait. "Avoided a conflict", not
   "avoidant".
6. Crisis wording, safety thresholds and prompt text live in the database, not
   in the app binary, so they can be changed without a store release.
7. No third party analytics or crash SDKs in the student app.
8. Audio is never persisted. The transcript is the record.

## Documents

| File | What it holds |
| --- | --- |
| CLAUDE.md | Instructions for AI assistants working here |
| BUILD_PLAN.md | Ordered tasks, and which ones are actually done |
| DECISIONS.md | Every decision, why, what would reverse it |
| FLOW.md | Execution paths, call order, invariants |
| CONTEXT.md | Clinical constraints and the voice rules |
| SCHEMA.md | The data model |
| docs/screens.html | The original ten screens, open in a browser |
| docs/architecture.svg | System architecture |
| docs/user-flow.svg | The product across three time horizons |
| docs/staff-roles-later.md | Counsellor and district admin, deferred |

## Repository layout

```
/app          Flutter client
/api          TypeScript service
/db           Drizzle schema and migrations
/www          The public site at soulspacehealth.com
/prompts      Versioned prompt text, seeded into the database
/eval         Evaluation runners and the hand judged fixture set
/docs         Architecture, screens, staff roles
```

## Status

The loop runs end to end on real models, against a real database, on an iPhone.

| Task | State |
| --- | --- |
| 0 Two experiments | **Not done.** Needs real devices and forty recordings of real students. Nothing here substitutes for it. |
| 1 Schema | Done. Twenty five tables, row level security forced on every one, tenancy tests passing against the live database. |
| 2 API skeleton | Done. |
| 3 Transcription | Built and proven with real speech. Audio is deleted after every attempt. |
| 4 Safety classifier | Done. Blocking, written on every entry, fails closed. |
| 5 Consent gate | Done. With consent revoked an entry saves and nothing goes out. |
| 6 Capture and beat one | Built. The under three seconds target has not been measured on school wifi. |
| 7 Make beat one good | **Not started.** The one the plan says decides whether the product works. |
| 8 Mirror and decision | Built. |
| 9 Tagging | Built. The fifty entry hand check has not been done. |
| 10 Check backs | Job runner built. Not yet exercised across a redeploy. |
| 11 Home with empty states | Done, day one version first. First run now ends here. |
| Profile tab | Fourth destination. Reads and writes every held field. |
| 12 Pattern candidates | Query built. Not yet seen with real tags behind it. |
| 13 Day view | Built on the student's own entries. Days list, then one day. |
| Cue cards | A yes or no question about something they said is coming up, with a box. |
| Reflections | Good and bad patterns, one line each, opening on the entries behind them. |
| People | Everyone they write about, with a profile the model writes. |
| Sign in with Apple | Built, and unusable until the capability has a team behind it. |
| The public site | Live. `www`, deployed from `main`, with terms, a privacy policy and a contact address. |
| Production database | Supabase, migrated and seeded. The service that talks to it is not hosted anywhere yet. |
| Memory layer | Built, steps 1 to 6 of docs/memory.md. Embeddings, facts, retrieval in the context builder, nightly consolidation and `GET /graph`. Not yet seen with months of real entries behind it. |
| Hosting | **Not done, and deliberately.** See below. |

What is real: all of it. The sample file is deleted, every screen reads the
student's own rows, and nothing in the app is invented content any more.

What has never been tested on a real student: all of it. Task 0 and task 7 are
both still open, and the eval directory that would answer task 7 is still
empty.

## Where this runs

The database is on Supabase. Everything else runs on a laptop, which is a
decision rather than an oversight, and it has a trigger.

Nothing can ship until there is an Apple developer team, task 7 has been done
and the account model is settled. Until one of those changes there is no user to
be offline for, so paying for hosting buys nothing. **When the app is published,
the service moves to Render**, a web service for the API and a background worker
for the queue. The `Dockerfile` and `POST /jobs/drain` are already in the
repository, so that move is configuration rather than building.

What this costs while it lasts: the job queue only drains while somebody's
machine is awake. Check backs scheduled for a day when the laptop is closed do
not fire on time, they fire whenever the worker next runs. That is survivable in
development and it is exactly what stops being survivable on the day a real
person installs the app.

Both processes have to be running for the product to work, not just the API:

```
npm start -w @soul/api     # the HTTP API
npm run worker -w @soul/api # the queue: tagging, cue cards, sweeps, check backs
```

## First run

A welcome, a screen that reveals the four things that happen every time and
what the app is not, four profile questions, the ten baseline questions, a
spoken introduction, a landing that hands back what was given, then sign in
and home, empty. One sequence with a progress bar over the questions, a back
chevron and a slide between steps. Every question has to be answered: the
profile questions have a continue that is dim until there is an answer, and
each baseline question is a scene answered by a movement, a light dragged to
a corner, an answer sunk in a pond, a wall pushed over, that moves on by
itself once something is chosen.

The profile is a first name, an age band, a gender and a location. There is no
surname and no birthdate. The where question offers the device before the list,
and a student who shares their location has their exact coordinates stored; one
who refuses picks a region and nothing else is asked. Either way the timezone is
derived on the server and never sent by the client.

A fourth tab shows everything held, changeable and emptiable, next to a plain
statement of what is not held. Decisions 055 to 061 have the reasoning, and 061
has the argument against storing coordinates at all.

## Running it locally

Postgres 17 with pgvector, no containers needed.

```
brew install postgresql@17 pgvector
brew services start postgresql@17
createdb soul
export DATABASE_URL="postgres://$(whoami)@localhost:5432/soul"

npm install
npm run db:migrate                  # schema, then row level security
npm run seed                        # prompts, then the two test students
npm run db:test                     # the tenancy test
npm start -w @soul/api
```

To start from nothing again:

```
npm run db:reset -- --yes           # every row, gone. Refuses anything remote
npm run seed
```

The client, pointed at that API:

```
cd app
flutter run --flavor soul \
            --dart-define=SOUL_API=http://localhost:8080 \
            --dart-define=SOUL_STUDENT=student_with_consent

The flavor is the Xcode scheme, which is named Soul like everything else in
the project. Flutter only finds a scheme by that name when told the flavor.
```

Without provider keys the safety classifier cannot answer, so every entry
returns the help screen. That is the designed behaviour, not a failure.

## Shipping the first TestFlight build

Everything below is in order, and each step is blocked by the one before it.
The code is ready. What is missing is accounts and keys, and none of those can
be created by an assistant.

1. **An Apple Developer Program membership.** This Mac has no signing identity
   and Xcode has no team. Join at developer.apple.com, then in Xcode open
   `app/ios/Runner.xcworkspace`, select the Runner target, Signing and
   Capabilities, and pick the team. Automatic signing is already on and the
   bundle identifier is `com.soulspacehealth.soul`. Add the Sign in with Apple
   capability on the same screen. Register the bundle identifier in App Store
   Connect and create the app record there.

2. **The API on Render.** `render.yaml` at the repository root is a blueprint
   for a web service and a worker. In Render, New, Blueprint, point it at this
   repository, and it asks for the four secrets: `DATABASE_URL`, the Supabase
   connection string already in `.env`, `OPENAI_API_KEY`, `ELEVENLABS_API_KEY`,
   and it generates `SOUL_JOBS_SECRET` itself. `RESEND_API_KEY` and
   `RESEND_FROM` are for sign in codes by email; without them Apple sign in
   still works and the email path says it is not available. When it is up,
   `https://soul-api.onrender.com/health` answers.

3. **An ElevenLabs key.** Without it every spoken entry fails with a clear
   message and typed entries work. Put it in the Render dashboard and, for
   local runs, in `.env`.

4. **The build and the upload.** Raise `version` in `app/pubspec.yaml`,
   because Apple refuses a second upload with the same version, then:

   ```
   app/release.sh
   ```

   It builds the signed archive against the Render API and uploads it through
   the Apple account Xcode is signed in to. `SOUL_API=https://...` in front
   of it points the build somewhere else. Apple processes the build for ten
   to twenty minutes and it appears under the app's TestFlight tab, where
   internal testers are added. Nothing is submitted for review by this.

5. **On the device.** First run is the welcome, how it works, the profile
   questions, the ten baseline questions, the spoken introduction, the
   landing, then sign in. The simulator
   has no microphone, so this is the first time the voice path, the transcript
   confirm step, and the tone judgement can be seen for real. Every model call
   is written to the `generations` table with its latency, which is how to
   read whether beat one lands inside three seconds on school wifi.

## Running it somewhere real

A laptop is not a deployment. When it sleeps the API stops answering and, worse,
the job runner stops: check backs never fire on the day a student named, the
nightly sweep never books its next night, and entries are never tagged. None of
that recovers by itself.

The service is two processes and they have different needs.

**The API.** `Dockerfile` at the repository root builds it and is host neutral.
It runs on Fly, Railway, Render, App Runner, Cloud Run or a plain virtual
machine. Nothing in it is specific to one of them. Every secret comes from the
environment: `DATABASE_URL`, the provider keys, `APPLE_BUNDLE_ID`. Do not set
`SOUL_ROSTER_TOKENS` anywhere real.

**The job queue.** Two ways to drain it, and the code is the same either way.

Run the worker as a second process, which is `loop()` and is right on a host
that stays up:

```
npm run worker -w @soul/api
```

Or let a scheduler drive it, which is right anywhere that sleeps or bills by
the hour:

```
curl -X POST https://your-api/jobs/drain \
  -H "Authorization: Bearer $SOUL_JOBS_SECRET"
```

`POST /jobs/drain` runs up to twenty five jobs and stops early when the queue is
empty, so a quiet minute costs one query. It has no session, because a scheduler
is not a student. It carries a shared secret instead, and with
`SOUL_JOBS_SECRET` unset it refuses every caller rather than running jobs for
anybody who finds the URL.

Supabase can schedule this itself. `pg_cron` and `pg_net` are both available on
the project and `pg_cron` runs to the minute, which is far better than the once
a day most free platform crons offer. That matters: a queue drained daily means
a student waits a day for the tags everything downstream is built on.

What Supabase cannot do is host the API. Its only compute is Edge Functions,
which are Deno, and this is a Node service with npm workspaces and Node imports.
The Mirror and cue card calls also allow up to a hundred and twenty seconds,
which sits badly with Edge Function limits. Supabase holds the data and can hold
the clock. Something else has to hold the service.

## Sign in with Apple

The capability is already wired into the project. `app/ios/Runner/Runner.entitlements`
holds `com.apple.developer.applesignin` set to Default, and all three build
configurations of the Runner target point at it. There is no Apple developer team
yet, so signing is left untouched and the simulator build runs as it is.

Once a team id exists, a human has to do four things in Xcode:

1. Open `app/ios/Runner.xcworkspace` and select the Runner target.
2. Under Signing and Capabilities, choose the team. The bundle identifier is
   `com.soulspacehealth.soul` and it does not change.
3. Check that Sign in with Apple is listed as a capability. It is read from the
   entitlements file, so it should already be there.
4. Enable Sign in with Apple for the same identifier in the Apple developer
   account, then let Xcode regenerate the provisioning profile.

A device build fails until both step 2 and step 4 are done. The simulator build
needs neither.
