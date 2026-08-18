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
| App | Flutter, iOS and Android |
| Transcription | Deepgram, audio deleted immediately, never stored |
| API | TypeScript and Node |
| Database | Postgres on Supabase, pgvector, row level security |
| Schema | Drizzle |
| Jobs | Durable, Postgres backed |
| Models | OpenAI primary, Gemini second, OpenRouter fallback |
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
| BUILD_PLAN.md | Ordered tasks, start at task 0 |
| DECISIONS.md | Every decision, why, what would reverse it |
| FLOW.md | Execution paths, call order, invariants |
| CONTEXT.md | Clinical constraints and the voice rules |
| SCHEMA.md | The data model |
| docs/screens.html | All ten screens, open in a browser |
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

Nothing is built yet. Screens are designed, architecture is settled, the build
plan starts at task 0.
