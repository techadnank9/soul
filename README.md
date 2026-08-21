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
| Transcription | Deepgram, audio deleted immediately, never stored |
| API | TypeScript and Node |
| Database | Postgres 17 with pgvector, row level security. Supabase in production, local Postgres in development |
| Schema | Drizzle |
| Jobs | Durable, Postgres backed |
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
/prompts      Versioned prompt text, seeded into the database
/eval         Evaluation runners and the hand judged fixture set
/docs         Architecture, screens, staff roles
```

## Status

The loop runs end to end on real models, against a real database, on an iPhone.

| Task | State |
| --- | --- |
| 0 Two experiments | **Not done.** Needs real devices and forty recordings of real students. Nothing here substitutes for it. |
| 1 Schema | Done. Eighteen tables, row level security forced, tenancy test passing. |
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

What is real: all of it. The sample file is deleted, every screen reads the
student's own rows, and nothing in the app is invented content any more.

What has never been tested on a real student: all of it. Task 0 and task 7 are
both still open, and the eval directory that would answer task 7 is still
empty.

## First run

An intro that says what the app does and what it is not, four profile
questions, the ten baseline questions, then home, empty. Every question can be
skipped and none of them gates anything.

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
flutter run --dart-define=SOUL_API=http://localhost:8080 \
            --dart-define=SOUL_STUDENT=student_with_consent
```

Without provider keys the safety classifier cannot answer, so every entry
returns the help screen. That is the designed behaviour, not a failure.

## Sign in with Apple

The capability is already wired into the project. `app/ios/Runner/Runner.entitlements`
holds `com.apple.developer.applesignin` set to Default, and all three build
configurations of the Runner target point at it. There is no Apple developer team
yet, so signing is left untouched and the simulator build runs as it is.

Once a team id exists, a human has to do four things in Xcode:

1. Open `app/ios/Runner.xcworkspace` and select the Runner target.
2. Under Signing and Capabilities, choose the team. The bundle identifier is
   `space.soul.soul` and it does not change.
3. Check that Sign in with Apple is listed as a capability. It is read from the
   entitlements file, so it should already be there.
4. Enable Sign in with Apple for the same identifier in the Apple developer
   account, then let Xcode regenerate the provisioning profile.

A device build fails until both step 2 and step 4 are done. The simulator build
needs neither.
