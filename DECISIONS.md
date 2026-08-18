# Decisions

Every decision that shapes this product, why it was made, and what would
reverse it. Newest at the bottom.

## How to use this file

Read it before proposing anything that contradicts an entry here. If a decision
is wrong, add a new entry that supersedes the old one and say why. Do not edit
history.

**Rule for AI assistants working on this codebase:** if you make a choice that
was not explicitly instructed, log it here in the same format before you finish
the task. That includes library choices, schema shapes, naming conventions,
error handling approaches, and anything you decided because the instruction was
ambiguous. If you are unsure whether something counts, log it. An over full
decision log is recoverable; a silent choice discovered six months later is not.

## Format

```
### NNN. Short title
Date, who decided
Decision: one sentence.
Why: the reasoning.
Rejected: what else was considered, and why not.
Reverses if: the condition that would make this wrong.
```

---

### 001. The product is a reflection loop, not a chatbot
Aug 2026, Adnan and Pooja

Decision: every path ends with the student acting, deciding, or talking to a
human. No multi turn conversation with the AI.

Why: it is the one position competitors cannot copy without abandoning their own
product. It also aligns with the clinical guidance that supported tools with a
human in the loop outperform unsupported ones.

Rejected: a companion model. Better retention, worse outcomes, and directly
against the clinical advice we hold.

Reverses if: students consistently want to continue and disengage instead. Even
then, extend the loop rather than open a chat.

---

### 002. The unit of the product is a decision, not an entry
Aug 2026, Adnan

Decision: a reflection can name something the student might do. That gets stored
with a rough timeframe, and the app asks later how it went.

Why: an entry has no ending, so there is nothing to come back to. A decision
does. It also produces outcome data, which is behaviour rather than text, and
nothing else in this market collects it.

Rejected: a pure journal loop, which was the original design. It gives no reason
to return and no evidence anything helped.

Reverses if: students find the follow up intrusive rather than welcome. Watch
the ignore rate.

---

### 003. Two responses, not one
Aug 2026, Adnan

Decision: a short line first, fast. The fuller reflection only if the student
asks for it.

Why: someone in a raw state cannot read a structured analysis. Splitting also
gives the sharpest quality metric available: the share of people who tap to see
more tells you whether the first line landed.

Rejected: one full response. Slower, heavier, and hides the signal.

Reverses if: almost everyone taps through, in which case the split is friction
rather than kindness.

---

### 004. Patterns are proposed, never asserted
Aug 2026, Adnan, on Sofia's guidance

Decision: a possible pattern appears as a question inside a reflection. It
becomes real only when the student says it fits. Rejections are stored too.

Why: asserting a pattern is a statement about who someone is. The clinical
advice is explicit that this creates rigid self narratives a therapist then has
to undo. A confirmed pattern is also the student's own words, which makes it
both accurate and defensible.

Rejected: computing and displaying patterns directly, which was the original
Pattern View design.

Reverses if: nothing. This is a floor, not a preference.

---

### 005. Threshold, not self judgement
Aug 2026, Adnan

Decision: a pattern is proposed only when the same theme appears in at least
three separate entries on separate days. The model does not judge whether its
own observation is sound.

Why: models justify their own wrong answers convincingly. A rule is auditable
and we can always show the three entries behind a claim.

Rejected: asking the model to check its own evidence.

Reverses if: the threshold proves too slow or too fast in real use. Tune the
number, keep the mechanism.

---

### 006. Tags describe situations, never traits
Aug 2026, Adnan, on Sofia's guidance

Decision: "avoided a conflict", not "avoidant". Applies to stored tags and to
anything shown to a student.

Why: a trait is an identity claim. For children especially, an identity claim
made by software and repeated by adults is a harm we cannot undo.

Reverses if: nothing.

---

### 007. No emotional quantification
Aug 2026, Adnan

Decision: no hours in a loop, no scores, no percentages of a person. Counts of
real entries only.

Why: the numbers would be invented. We have a handful of short entries, not
continuous tracking, and presenting inference with the precision of a screen
time graph is a claim we cannot back. Structured reflection that increases
symptom focus can also amplify rumination.

Rejected: the Emotional Screen Time dashboard as originally specified.

Reverses if: nothing, unless the underlying data changes shape entirely.

---

### 008. A crisis path is mandatory
Aug 2026, Adnan

Decision: the safety classifier runs before any generation, on every entry, and
a published crisis protocol exists.

Why: California SB 243 and New York's law require a protocol for detecting
expressions of self harm, referring to crisis services, and publishing that
protocol. SB 243 carries a private right of action. Separately, it is the right
thing to do.

Rejected: removing it from the product. It was removed from the screen deck for
presentation purposes only.

Reverses if: nothing.

---

### 009. Target is schools, including under 13
Aug 2026, Pooja

Decision: the buyer is a district, and students under 13 are in scope.

Why: founder decision.

Consequences accepted: full COPPA compliance, FERPA via district agreements,
state student privacy laws, SOC 2 for procurement, an escalation policy, and
first year compliance cost in the region of $60,000 to $150,000.

Reverses if: the compliance load proves to outweigh the market before the
product is proven. The alternative is to validate with adults first.

---

### 010. Flutter for the client
Aug 2026, Adnan

Decision: one Flutter codebase for iOS and Android. No web.

Why: greenfield, mobile only, full UI sharing is the case Flutter is most
travelled for. The app is almost entirely typography and text input, where
Flutter's stack is the most settled. Voice is the only native integration and an
existing package wraps it. Curated packages avoid the dependency churn we wanted
to escape.

Rejected: Kotlin Multiplatform, which suits shared logic under native UI or
adding to an existing native app, neither of which applies. React Native and
Expo, rejected on dependency and build fragility. Separate Swift and Kotlin,
rejected as double the work for quality nobody can perceive in a text UI.

Reverses if: district accessibility review requires native accessibility
conformance that a canvas rendered UI cannot meet. Unresolved, see FLOW and
CONTEXT.

---

### 011. TypeScript and Node for the backend
Aug 2026, Adnan

Decision: one TypeScript service for the API, workers and evaluation runners.

Why: evaluation is being done by calling models rather than by numerical
analysis, which removes the main argument for Python. One language keeps prompt
construction identical between the API and the evaluation runners, which is the
drift failure we most wanted to avoid.

Rejected: Python and FastAPI, which was the earlier recommendation and was
correct only under the assumption that evaluation meant labelled sets and
scikit.

Reverses if: evaluation shifts to statistical analysis over labelled data at
scale.

---

### 012. Postgres, not a document store
Aug 2026, Adnan

Decision: Postgres on Supabase, with pgvector and row level security. Jobs in
Postgres rather than Redis.

Why: pattern detection is a group by over tag columns joined back to supporting
entries. The data is relational. pgvector keeps the semantic fallback in the
same database, and row level security enforces student isolation at the database
rather than in application code, which is a control we can evidence to a
district. Fewer services also means a shorter sub processor list.

Rejected: MongoDB, wrong shape. Neon, better pure database but auth to build
separately.

Reverses if: a district requires data residency or VPC isolation we cannot
evidence on a shared platform. Keep the schema portable so the move is a dump
and restore.

---

### 013. Model provider order
Aug 2026, Adnan

Decision: OpenAI primary, Gemini second, OpenRouter as fallback, all behind one
gateway. Model name in config, model version stored on every generated row.

Why: swapping providers per call becomes configuration rather than a rewrite.
Gemini's long context and caching suit the Mirror call, where the whole history
is sent. OpenRouter covers availability.

Caveat: OpenRouter routes to providers we do not contract with directly, which
is another sub processor under a school consent model. Restrict it to a named
allowlist.

Reverses if: cost or quality benchmarks favour a different order.

---

### 014. Full history in the Mirror, not in beat one
Aug 2026, Adnan

Decision: the Mirror call receives the student's whole context. Beat one
receives the current entry and little else.

Why: the founder decision is that responses should know the whole person. But
time to first token scales with prompt size, and models attend less reliably to
the middle of long contexts, which makes responses drift generic. Generic is the
one failure this product cannot survive. Splitting gets both.

Implementation: history first as a stable prefix so providers cache it, current
entry last.

Reverses if: measured latency and specificity show beat one improves with more
context.

---

### 015. Prompt text lives in the database
Aug 2026, Adnan

Decision: crisis wording, safety thresholds and all prompt text are served from
the database, not compiled into the app.

Why: Flutter has no over the air updates. The words a student sees during a
crisis cannot wait on an App Store review.

Reverses if: nothing.

---

### 016. Server transcription, not on device
Aug 2026, Adnan

Decision: audio is recorded on the phone, uploaded, transcribed by Deepgram, and
deleted immediately. Never persisted.

Why: the earlier plan was on device recognition, chosen to keep audio off our
servers. That held only while a student could edit the transcript. Without an
edit step the transcript is the permanent record and the input to the safety
classifier, so accuracy outweighs data minimisation.

The research is not close. Whisper reaches around 3 percent word error rate for
an adult reading in quiet and around 25 percent for child voices in the same
conditions. Models trained specifically on children's speech still report 30 to
60 percent in places. A tuned model reached 9 percent on clean elicited child
speech but 54 percent on real classroom audio. Errors also hit word, phrase and
semantic level tasks hardest, which is exactly where the safety classifier and
the tagger operate.

Rejected: on device recognition, which is the smallest model on the hardest
population.

Reverses if: on device quality closes the gap for our age range, measured rather
than assumed.

---

### 017. Deepgram over OpenAI Whisper
Aug 2026, Adnan

Decision: Deepgram for transcription.

Why: existing credit, and cost is not a real factor either way. At roughly a
third of a cent per thirty second entry, transcription will never be a meaningful
line item next to the model calls.

Caveat: this was a credit decision, not a quality one. Task 0b measures both on
real student audio before it becomes permanent.

Rejected: OpenAI Whisper, which keeps the vendor count at one and has a
documented fine tuning path on child speech. Still the fallback if measurement
favours it.

Reverses if: measured meaning change rate on real student audio favours Whisper,
or a district objects to the vendor.

---

### 018. Transcription sits behind a provider interface
Aug 2026, Claude

Decision: one `transcribe()` function with the provider in configuration, the
same pattern as the model gateway. No provider SDK is imported anywhere else.

Why: the provider was chosen partly because of a credit balance, which is not a
durable reason. Switching should be a config change rather than a refactor.

Reverses if: nothing.

---

### 019. A confirm step before an entry is submitted
Aug 2026, Adnan and Claude

Decision: after speaking, the student sees the transcript and chooses send or
discard. Not an edit field.

Why: the product decision is that students do not edit transcripts. Given the
error rates above, submitting an unreviewed permanent record about a child is not
defensible, and it is the text a safety classifier will read. Showing it also
matters for trust: a student who sees the words go in has been heard, one who
speaks into a void has been recorded.

Rejected: full editing, which the founder ruled out. Silent submission, which the
research rules out.

Reverses if: measurement shows meaning changes are rare enough that the step adds
friction without value.

---

### 020. Typing is an equal path, not a fallback
Aug 2026, Claude

Decision: the text field sits on the same screen as the mic, at the same level of
prominence, and is never framed as an alternative for when voice fails.

Why: recognition error rates vary dramatically with the speaker's linguistic
background, so the students least well served by voice are disproportionately
those from non English speaking homes. A district will ask about this.

Reverses if: nothing.

---

### 021. Safety classification biases toward false positives
Aug 2026, Claude

Decision: the classifier threshold is set to over trigger rather than under.

Why: it reads a transcript that may be imperfect, on a population where
recognition is weakest. A wrongly flagged entry costs a student one screen. A
missed one costs much more.

Reverses if: the false positive rate is high enough that students stop using the
product, which is a real risk worth measuring.

---

### 022. The product is called Soul
Aug 2026, Adnan

Decision: the name is Soul everywhere. Project, repository, package names,
documentation and product copy.

Why: founder call. The shorter name carries the same meaning and reads better in
a school setting.

Reverses if: a trademark conflict surfaces during district contracting.

---

### 023. postgres.js as the driver, npm workspaces as the layout
Aug 2026, Claude

Decision: the repository is an npm workspace with two packages so far, @soul/db
and @soul/api. The driver is postgres.js rather than node postgres.

Why: Drizzle documents both, postgres.js is the lighter of the two and ships its
own connection pooling, which matters against a Supabase pooler. Workspaces keep
the schema importable by the API without a publish step.

Rejected: a single flat package. It would let route code import the schema and
reach past the service layer, which FLOW.md is built to prevent.

Reverses if: a Supabase or Drizzle release makes node postgres the better
supported path.

---

### 024. Seventeen tables, not fourteen
Aug 2026, Claude

Decision: the schema implements the seventeen tables listed in SCHEMA.md.

Why: BUILD_PLAN.md task 1 says fourteen tables while SCHEMA.md defines
seventeen. The list is the specific document and the count is the loose one, so
the list wins. Flagging rather than silently choosing, as CLAUDE.md requires.

Reverses if: three of these were meant to be deferred, in which case say which.

---

### 025. Tenancy columns on every child table, enforced by check constraints later
Aug 2026, Claude

Decision: student_id, school_id and district_id appear on every student owned
table, including tables that could reach them through a join.

Why: row level security policies read these columns directly. A policy that has
to join to find the tenant is slower and easier to get wrong. Denormalising
three ids is the cheap side of that trade.

Rejected: deriving school and district from the entry. It puts a join inside
every policy on the request path.

Reverses if: nothing. Removing them later is the migration this avoids.

---

### 026. Row level security keys off a session variable and a dedicated role
Aug 2026, Claude

Decision: the request path connects as the soul_student role and sets
app.student_id for the transaction. Policies compare against
app_current_student(). Tables are set to force row level security so the owner
is subject to them too.

Why: it is the pattern Supabase uses, it works with an ordinary Postgres
connection rather than requiring their auth service, and forcing means a
mistake in connection configuration fails closed.

Rejected: Supabase Auth JWT claims. It would tie the schema to their auth
product, and students are rostered by the district rather than signing up.

Reverses if: we adopt Supabase Auth for student sessions, in which case the
helper function reads the JWT claim instead and no policy changes.

---

### 027. prompts and audit_log are unreadable from the request path
Aug 2026, Claude

Decision: both tables have row level security enabled and no select policy for
soul_student. Prompt text is read by the service role inside the gateway.
audit_log takes inserts and returns nothing.

Why: a student session has no reason to read prompt text or the audit trail, and
a table with no policy denies every row, which is the strongest available
default.

Reverses if: the counsellor console needs audit reads, which is a different role
with its own policies, not a change to this one.

---

### 028. Embeddings are 1536 dimensions with an hnsw cosine index
Aug 2026, Claude

Decision: entry_embeddings.embedding is vector(1536), indexed with hnsw using
vector_cosine_ops.

Why: 1536 matches the current OpenAI small embedding model, which is the primary
provider. hnsw builds slower than ivfflat but does not need a representative
training set, and we have no entries yet.

Reverses if: the embedding provider changes dimension, which is a column type
change and a rebuild rather than a schema redesign.
