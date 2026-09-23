# Memory, and how a pattern forms

What this app remembers about a person, where it is kept, how it is read
back, how a pattern comes out of it, and how any of it can be taken away.

This is the part of the product that cannot be got wrong. Everything the app
says about somebody is made here, and the promise the product is sold on is
that every one of those claims traces back to a moment the person wrote and
can delete. Read this before changing anything under `services/memory`,
`services/patterns`, `services/noticings`, `services/verdicts`, or the
tagger.

## The rules that do not bend

1. **Finding a pattern is a SQL group by, never a model call.** It is what
   lets the app show the exact entries behind a claim. A model may write the
   sentence about a pattern. A model may never be what decides the pattern
   is there. `services/patterns/findCandidates.ts`.
2. **A pattern is proposed, never asserted, and it is offered with its
   evidence.** The moments go on the screen with their dates, in the
   person's own words, so a yes is a judgement about two things they wrote
   rather than agreement with a sentence about themselves. Decision 290.
3. **Nothing reaches `confirmed_patterns` without the person's yes and at
   least two supporting entries.** Decisions 289 and 290, invariant 8 in
   FLOW.md.
4. **Situations, never traits.** Every value in every list describes what
   happened or what somebody took it to mean. Nothing anywhere names a kind
   of person or a kind of thinking, and no clinical word goes near any of
   it.
5. **Counted values come from closed lists.** Free text never groups: three
   entries that plainly said the same thing came back as three phrasings and
   grouped into three themes of one. Decision 259.
6. **Nothing is paraphrased where evidence belongs.** What is shown as the
   moment behind a claim is what they wrote, cut at a sentence, never a
   model's line about it.
7. **A deleted moment takes everything that stood on it alone.** Decision
   292.
8. **The memory lives in our own Postgres.** No memory vendor, no second
   database. The reasons are at the end of this file.

## What is stored

| table | holds | written by |
| --- | --- | --- |
| `entries` | the moment, whole, as they wrote or said it | `services/reflection/submit.ts` |
| `entry_embeddings` | one vector per entry | `services/memory/embed.ts` |
| `tags` | `trigger`, `feeling`, `coping`, `meaning`, `domain`, `confidence` | `services/tagging/tag.ts` |
| `facts` | subject, predicate, object, a sentence in their register, the entry ids behind it, `valid_from`, `valid_to`, `learned_at`, `retired_at`, a vector, a tier | `services/memory/facts.ts` |
| `people`, `entry_people` | who they named, and where | `services/people/` |
| `decisions`, `outcomes` | what they said they would do, and how it went | `services/decisions/` |
| `pattern_candidates` | a theme the query found, and the entries behind it | `jobs/pattern_sweep.ts` |
| `confirmed_patterns` | a theme they said fits | `services/patterns/answer.ts` |
| `pattern_rejections` | a theme they said does not fit, kept so it is never offered twice | `services/patterns/answer.ts` |
| `pattern_verdicts` | whether a theme is doing them good or costing them | `services/verdicts/` |
| `noticings` | at most two hedged things the app may be seeing, from the first entry | `services/noticings/` |

## How it is written, after an entry lands

The request path writes the entry, runs consent and safety, generates beat
one, and returns. Everything below happens afterwards in the job queue, so
none of it costs the person a second of waiting. `jobs/runner.ts` has the
list.

```
entry stored
  └─ tag_entry            services/tagging/tag.ts
       ├─ trigger, feeling, domain      free text, for reading
       ├─ coping                        closed list, counted
       ├─ meaning                       closed list, counted
       └─ books the rest:
            embed_entry         a vector for the entry
            extract_facts       what the entry says is so
            people              who is in it
            extract_reminders   a time they named out loud
            cue_cards           something to come back to
            pattern_sweep_one   look for a pattern now, for this person
            noticings           at most two hedged things, from entry one
nightly
  ├─ pattern_sweep        everybody, same query
  ├─ pattern_verdicts     over themes with at least two entries
  ├─ consolidate_memory   at most three observations across several facts
  └─ week_notes           what the week said
```

A fact that contradicts an open one closes it with `valid_to` rather than
deleting it, so the graph can answer both what is true now and what was true
in March. A fact said again gains the new entry id and nothing else changes.

## How it is read, when a line is written

`memory/buildContext.ts`. Three sources, fused, history first as a stable
prefix so providers cache it, the current entry last:

- **Time.** The last eight entries.
- **Meaning.** The nearest episodes by vector, from any time, so an entry
  from April about the same situation as today is reachable even when no tag
  matches.
- **Graph.** The open facts the entry touches, and for each, the outcomes of
  decisions attached to the entries behind it. This is the "last three times
  this happened, you did this, and it went like this".

Beat one is told almost none of it on purpose: latency and specificity beat
context there. The Mirror gets the whole person. CLAUDE.md says why.

Facts are quoted in the person's own words. Never paraphrased into a trait
anywhere they are rendered.

## How a pattern forms

```
tags                     two closed lists, coping and meaning
  └─ findCandidates      group by theme, count distinct entries, at least two,
                         excluding anything rejected, confirmed, or already
                         a candidate
       └─ pattern_candidates      status pending, with the entry ids
            └─ surfaceCandidate   attached to a Mirror, with its moments
                 └─ the person answers
                      fits          → confirmed_patterns
                      not the same  → pattern_rejections, never offered again
                      later         → stays pending, asked another time
```

**Two closed lists, counted the same way.** `coping` is what they did, ten
words. `meaning` is what they took it to mean, twelve sentences. The two
share no words, so a theme is one word from one of them and the theme alone
says which list it came from. The second list is where the patterns worth
showing somebody usually are: avoiding three different things is a habit,
and reading three different silences as your own fault is something a person
could act on. Decision 291. The lists are in `contracts.ts` as `copingWays`
and `meaningsTaken`, and in `prompts/tagger.v5.md` with what each one means.

**Null is the common answer on both.** Most entries say what happened and
never say what they concluded. A tagger that reaches for the nearest word
writes a pattern that is not there.

**Two moments, not three.** The count was standing in for confidence and the
person's own answer is a better one. Decision 289. The number lives in
`MIN_ENTRIES` in `findCandidates.ts` and again in `answer.ts`, and it has to
move in both: they disagreed once and a two moment candidate could be
offered and then threw when somebody said yes.

**The offer carries its evidence.** Up to three moments, oldest first, each
with the date and the person's own opening words, and three answers rather
than two. Maybe is a real thing somebody means and reading it as a no throws
away a guess that may have been right. Decision 290.

**A candidate is not spent on being offered.** The status stays pending
until they answer, and `surfaced_at` records that it has been put in front
of them. It used to go to surfaced on attach, which meant anything shown in
a reading somebody closed was gone for good. Decision 293.

**Verdicts are a model call and that is not a hole in rule 1.** Finding the
theme and judging it are two questions. Finding stays in SQL. Judging runs
in `services/verdicts`, at night, over themes with at least two entries, and
where the person's own outcomes have already said lighter or worse, the
model is told that verdict and writes only the sentence.

**Noticings are the early, hedged version.** From the first entry, at most
two things the app may be seeing, for a yes, no or not sure. They are not
patterns and they are not counted. Decision 278.

## How it is forgotten

Anything held can be reworded or taken away, and a moment can be taken back
whole. `services/memory/held.ts`, `services/memory/forget.ts`, the routes in
`routes/memory.ts`, the screen in `app/lib/features/memory/memory_screen.dart`
and the sheet on the day view.

| what | what happens |
| --- | --- |
| a fact standing on that entry alone | retired |
| a fact with other entries behind it | loses the entry, keeps holding |
| a pattern candidate | loses the entry, and goes when it drops under two |
| a pattern they confirmed | loses the entry, and is taken down when it drops under two |
| tags, embedding, cards, people, decisions and their outcomes, the safety row, the generations, the tone | gone with it |

One transaction. A half forgotten entry is worse than a kept one, because
the person was told it was gone.

Facts are retired rather than deleted: `retired_at` already means a fact the
system stopped trusting, nothing loads a retired fact, and the row is what
makes the next question about why something vanished answerable. A person
who wants the rows themselves gone has account deletion, decision 281.

Only the sentence of a fact is editable. Subject, predicate and object are
what the counting and the contradiction check run on, and typing over those
would put free text back where the closed shape has to be.

Two routes reach a delete, and both are needed: the memory screen reaches a
moment through a fact read out of it, and most entries never produce one, so
the day view is where the rest are reachable. Decision 293.

## Why this is representable as a graph

Everything above is rows with ids pointing at other rows. `GET /graph`
returns nodes and edges, and every node opens to the entries behind it
because every fact carries its entry ids. That property is the reason the
memory lives in our database rather than somebody else's.

## Why no memory vendor

Four families of memory system are in production use and they disagree in
ways that matter. Vector first extract and retrieve, Mem0 and Supermemory,
weakest at facts that change. Temporal knowledge graphs, Zep and Graphiti,
the strongest published design for facts that change and the one whose shape
matches a person's life. Agent managed memory, Letta, which fits an
autonomous agent rather than a product where the human never talks to the
memory. And Postgres only hybrids, which report that the production answer
is hybrid retrieval: vector, keyword, graph and time, fused.

Looked at again in September 2026, with cognee, MemPalace, EverOS and
Hindsight added to the field. Hindsight is the one worth reading: MIT, an
ACL 2026 demo paper, Postgres with pgvector, and the highest published
LongMemEval score. It is the benchmarked version of the design we already
built, and the licence lets us read it. MemPalace is a useful confirmation
of one choice: keep episodes whole and invest in retrieval rather than
distilling early. Benchmark numbers across these are not comparable without
care, and a 2026 paper on how scoring targets shape memory benchmarks is
worth reading before anybody picks on a leaderboard.

None of them is adopted, and the reason is not caution. They all end in the
same place: relevant context retrieved and handed to a model. That produces
similarity, not a countable recurrence with the exact entries attached. A
pattern here has to be checkable by the person it is about, and a hosted
memory service would also be a fourth company holding a child's inner life,
named in a district data agreement.

## What is not done

- **None of this has been seen with months of real entries.** Of a hundred
  entries read again in September, three carried a meaning. Whether that is
  the prompt being properly conservative or too conservative cannot be
  answered on writing this thin.
- **Maybe is not yet the maybe the design asks for.** It parks a candidate
  to be asked again another time. It should return only when the same thing
  shows up again, which needs the sweep to compare the evidence it finds
  against the evidence already stored.
- **The pattern offer still rides inside the Mirror** rather than standing
  on its own as its own question after the reflection.
- **Candidates only come from exact tag matches.** Every entry is embedded
  and the vectors are never used to find a pattern. Clustering a person's
  entries by meaning would catch what the closed lists miss, and the
  evidence would stay verbatim and the claim would stay confirmable.
- **Retrieval has never been measured.** Hindsight ships a harness. Pointing
  it at `buildContext` would say whether it is good or merely built.
