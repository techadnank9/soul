# Memory that compounds

How Soul should remember a person over months, so that a line back can say
"the last three times this happened, you did this, and it went like this",
and so that an admin screen can one day show a person as a graph. Research
notes and the design that follows from them. The order of work at the end
says what is built and where.

## What the field has settled on, September 2026

Four families of memory system are in production use, and they disagree in
ways that matter for us.

**Extract and retrieve, vector first.** Mem0 and Supermemory. Every message
is distilled by a model into short facts, each fact is embedded, and the
relevant ones are pulled back by similarity at prompt time. Fastest to add
to an existing app. Weakest at facts that change over time: on LongMemEval,
the benchmark for exactly that, Mem0 scores about 49 percent against
Zep's 64 with the same model.

**Temporal knowledge graph.** Zep and its open source engine Graphiti.
Episodes, the raw events, are kept whole. Entities and relationships are
extracted into a graph, and every relationship carries four timestamps:
when it became true, when it stopped being true, when the system learned it,
and when the system learned it had ended. A fact that is contradicted is not
deleted, it is closed with an end date, so the graph can answer both "what
is true now" and "what was true in March". This is the strongest published
design for facts that change, and it is the one whose shape matches a
person's life.

**Agent managed memory.** Letta. The model itself decides what to keep in
a small always loaded core and what to page out. Fits autonomous agents, not
a product where the human never talks to the memory directly.

**Postgres only hybrids.** MemoriesDB and Hindsight build the same
temporal and graph ideas inside Postgres with pgvector, using recursive
queries for graph walks and HNSW for similarity, and report that the
production answer is hybrid retrieval: vector, keyword and time, fused.

Sources: the Zep paper on arXiv 2501.13956, the Graphiti write up on the
Neo4j blog, MemoriesDB on arXiv 2511.06179, the Hindsight post on knowledge
graphs versus vector search for agent memory, and the 2026 comparisons from
Graphlit and Developers Digest.

## What that means for Soul

Soul is not a chatbot remembering a conversation. It is a record of what
happened to a person, what they did about it, and how that went. That is
already closer to a temporal graph than to a bag of facts, and the schema
already holds the hard parts: entries with timestamps, tags per entry,
people extracted per entry, decisions linked to entries, outcomes linked to
decisions, patterns confirmed with the entries behind them.

Two things are missing.

1. **Nothing is retrieved by meaning across months.** The context builder
   loads the last eight entries and the confirmed patterns. An entry from
   April about the same situation as today's is invisible unless a tag
   matches exactly.
2. **Nothing has a validity window.** A person who "does not talk to their
   mother" and then does has two true facts at different times, and today
   the second overwrites nothing and connects to nothing.

## The design

Build the temporal graph inside the Postgres we have. No Neo4j, no second
database, no hosted memory vendor. Every reason the graph vendors give for
a graph database is answered by recursive queries and pgvector at our
scale, and a hosted memory vendor would be a fourth company holding a
person's inner life.

### Three layers, all already partly there

**Episodes** are entries, kept whole, embedded. This exists. The
embedding job has waited since task 8 and is the first thing to turn on.

**Facts** are a new table, `facts`: subject, predicate, object, one
sentence in the person's own register, the entry ids it came from,
`valid_from`, `valid_to`, `learned_at`, `retired_at`, an embedding, and a
confidence. Extracted by a model after each entry, in the tagger's job, the
same way people are extracted today. A new fact that contradicts an open
one closes it with `valid_to` rather than deleting it. Examples:

    Adnan  avoids   speaking up in maths     valid 2026-08-30 to open
    Adnan  decided  to tell Mr Patel by Fri  valid 2026-09-01 to 2026-09-05
    Adnan  did not  tell Mr Patel            valid 2026-09-05 to open

**Communities** are the patterns screen: clusters of facts and episodes
that keep returning. Confirmed patterns already are this. A nightly job can
propose communities from the fact graph the same way the sweep proposes
patterns from tags.

### Retrieval, at the moment a line is written

Hybrid, fused, in one query:

- **Time:** the last eight entries, as now.
- **Meaning:** the nearest twelve episodes by embedding to the entry just
  written, from any time.
- **Graph:** the open facts about any entity the new entry mentions, and
  for each, the outcomes of decisions attached to those facts. This is the
  "last three times this happened, you did this, and it went like this".

The context builder renders that as it renders everything today: history
first as a stable prefix, current entry last, facts quoted in the person's
own words, never paraphrased into a trait.

### Consolidation, nightly

Generative agents style reflection, bounded. Once a night, for each person
with new entries, a model reads the facts that changed and writes at most
three durable observations, each with the fact ids behind it, into the
same facts table with a higher tier. That is the episodic to semantic step
every survey names, and keeping it in the same table keeps it showable.

### Forgetting

Facts decay by not being retrieved. A fact with `valid_to` set is never
loaded as current. A person can delete any entry, and deleting an entry
retires every fact that has only that entry behind it. Nothing is ever
silently rewritten.

## Why this is representable on an admin screen

Everything above is rows with ids pointing at other rows: person, entries,
facts with subject and object, people, patterns, decisions, outcomes. A
graph screen is one query that returns nodes and edges, and a force layout
in the app or in a web dashboard. Every node can be opened to the entries
behind it, because every fact carries its entry ids. That is the property
none of the hosted memory vendors give you, and it is why the memory should
live in our database rather than theirs.

## Order of work

All six are built. What each one became, and where it lives:

1. Turn on the embedding job. One purpose in the gateway, one column that
   already exists. Built: `api/src/services/memory/embed.ts`, the `embed`
   function in `api/src/gateway/call.ts`, the `embed_entry` job in
   `api/src/jobs/runner.ts`. Decision 205.
2. The facts table and the extraction step in the tagger's job. Built:
   `facts` in `db/src/schema.ts`, `api/src/services/memory/facts.ts`,
   `prompts/facts.v1.md`, the `extract_facts` job booked by the tagger.
   Decisions 206 and 207.
3. Retrieval in the context builder, the three sources fused. Built:
   `loadContext` and `loadFacts` in `api/src/memory/buildContext.ts`.
   Decision 208.
4. Beat one and the Mirror told the outcomes of the last times. Built for
   the Mirror, in the same file: every fact is rendered with the outcomes of
   decisions on the entries behind it. Beat one is still told only the entry
   and how it sounded, on purpose, per CLAUDE.md.
5. Nightly consolidation. Built: `api/src/services/memory/consolidate.ts`,
   `prompts/consolidate.v1.md`, the `consolidate_memory` job booked by
   `scheduleConsolidation` in `api/src/jobs/enqueue.ts`, the `consolidate`
   purpose in the gateway. Decision 209.
6. The graph endpoint, nodes and edges, which the app's map tab and the
   admin screen both read. Built: `GET /graph` in `api/src/routes/graph.ts`,
   the `graphView` contract in `api/src/contracts.ts`. Decision 210.

What has not been done: nothing here has been seen with months of real
entries behind it, and forgetting on entry deletion, retiring every fact that
stood on that entry alone, is still to write.
