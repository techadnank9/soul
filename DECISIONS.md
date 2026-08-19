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

---

### 029. Task 0 is skipped, and both risks stay open
Aug 2026, Adnan

Decision: build the client without running either task 0 experiment. There is no
iPhone or Android hardware available, and no student audio.

Why: waiting on hardware stops the project. The plan put task 0 first because
both halves can invalidate a decision already made, not because the app cannot
be written without them.

What this costs: the keyboard behaviour on screen 6 is now verified in the iOS
simulator only. A simulator types with the Mac keyboard, so it cannot show the
software keyboard covering the card, the scroll fighting the inset, or the lag
on a mid range Android. Decision 010, Flutter for the client, therefore rests on
an untested assumption. Decision 017, Deepgram over Whisper, rests on published
error rates rather than on measured meaning changes in our own age range.

Reverses if: hardware arrives. Both experiments should run before any student
uses this, and the transcription comparison must run before task 3 is trusted.

---

### 030. The entry is stored before the safety classifier runs
Aug 2026, Claude

Decision: the submit path is consent, store, classify, generate. FLOW.md had
classify before store.

Why: safety_flags carries entry_id and is written on every entry, hit or miss.
A row cannot reference an entry that does not exist, so classification cannot
come first without either dropping the flag on blocked entries or inventing an
id before the insert. Storing first keeps the flag on every entry.

The invariant is unchanged. No generation happens before classify returns, and
storage is not generation. Nothing leaves the building between the two.

Reverses if: entry ids are generated in the application rather than by the
database, which would let the flag be written first. Not worth it.

---

### 031. A classifier that cannot answer is treated as high risk
Aug 2026, Claude

Decision: when the safety call fails on every provider, the entry is flagged
high, the help screen is shown, and the flag records why.

Why: the alternative is generating a reflection on an entry nobody has checked,
which is the single outcome the safety path exists to prevent. Failing open on
a timeout would make our safety guarantee conditional on provider uptime.

What it costs: a provider outage shows the help screen to students who did not
need it. That is the direction task 4 already says to bias in.

Reverses if: the false positive cost turns out to be higher than expected,
which needs measuring rather than guessing.

---

### 032. Hono for HTTP, plain fetch for every provider
Aug 2026, Claude

Decision: the API uses Hono. Model and transcription providers are called with
fetch, with no vendor SDKs.

Why: three provider SDKs would be three dependency trees, three release
cadences and three more names in a district data agreement, to save a function
that posts JSON and reads a string back. Hono earns its place because routing
and request parsing by hand is where boundary bugs live.

Rejected: Express, larger and typed worse. The Node standard library alone,
which would mean writing the routing this depends on.

Reverses if: a provider ships something that only its SDK can reach, such as a
streaming protocol we need for beat one.

---

### 033. Pattern answers go through one function, not three
Aug 2026, Claude

Decision: services/patterns/answer.ts handles fits, not the same, and later.
FLOW.md named confirm.ts and reject.ts.

Why: all three read the same candidate row, all three write a status back to
it, and there is a third answer FLOW.md did not have. Splitting them meant the
same lookup in three files.

Reverses if: the counsellor console needs to confirm on a student's behalf,
which would be a different entry point with different authorisation.

---

### 034. Skip leaves first run, it does not advance it
Aug 2026, Adnan

Decision: Skip on the one question goes straight to home. Skip is also
available on the capture screen reached from home, which had none.

Why: a skip that moves you to the next screen in the same sequence is not a
skip. CONTEXT.md is direct that autonomy improves engagement, especially when
an adult initiated the involvement, and a student who wants out needs one tap
rather than three.

Consent has no skip and will not get one. A student can decline to answer
anything, but they cannot be given the product without having seen what it does
with what they say.

Reverses if: nothing. This is the weaker version of what the clinical guidance
asks for.

---

### 035. The surface palette is an elevation scale, not a set of near blacks
Aug 2026, Adnan and Claude

Decision: the base moves from #0C0C0B to #121110 and the surfaces above it are
spaced far enough apart to be seen. Cards carry a faint top highlight, the
quote rule and the focused field carry clay.

Why: the first palette sat at about four percent lightness with cards three
percent above it, so nothing separated and the app read as one flat black
sheet. The published guidance on dark interfaces is consistent: a pure black
base destroys hierarchy and causes text to bloom, and depth on a dark surface
comes from stepped lightness rather than from shadow.

The warm undertone is deliberate. The accents are clay and amber, and a cool
grey underneath them reads as cheap.

docs/screens.html was updated in the same change so the designs and the client
do not drift.

Reverses if: contrast testing against the district accessibility review finds
the steps too close. They can widen without changing the structure.

---

### 036. Colour carries the interface, not decoration
Aug 2026, Adnan and Claude

Decision: the four theme colours appear as bars, tinted counts and filled day
tiles rather than as small dots. The open decision sits in a clay tinted card.

Why: looked at what comparable apps actually do in the store rather than
reasoning about it. How We Feel, an emotional wellbeing journal with an Editors'
Choice award, a 4.9 rating and a 9 plus age rating, is dark and does not read as
empty, because saturated colour fills its surfaces. Stoic is light and stark
black and white. Day One is light and photo led.

The conclusion is that dark is fine for this audience, and the thing our version
was missing was not lightness. We had four theme colours and were showing them
as eight pixel dots.

The restraint still holds in the copy. Nothing here adds a word, an
encouragement or an emoji.

Reverses if: colour starts reading as gamification. The line is that colour
describes what is already there and never rewards.

---

### 037. A scrolling body reserves room for its footer
Aug 2026, Claude

Decision: Screen adds the footer height to the scroll padding.

Why: the footer floats over the scroll view, and once home grew taller the
patterns card ended up underneath the button and could not be read or tapped.
Found by looking at the running app, not by reading the code.

Reverses if: the footer becomes part of the scroll, which would let it scroll
away and lose the always available invitation.

---

### 038. The visual direction is Headspace, and there is a tab bar
Aug 2026, Adnan

Decision: warm cream ground, white cards with soft warm shadows, the four theme
colours as large filled tiles, pill buttons in clay, and a three destination tab
bar with capture floating clear of it.

Why: founder call, with Headspace named as the reference. Two darker versions
read as dull and empty. The category is split, Stoic and Day One are light,
How We Feel is dark and vivid, and Headspace is the warm and light end of it.

The tab bar is a change to the navigation, not a fix. docs/screens.html says
home is the hub and everything is reached from it. Moving between the week, a
day and the patterns is the most common thing a returning student does, and
pushing and popping to reach them made the product feel deeper than it is.

Capture is not a destination. It is an action, so it floats rather than sitting
in the bar, and it is the only thing on that surface a student is encouraged to
do.

What this does not change: the words. CONTEXT.md still governs every string.
Warmer surfaces are not permission for encouragement, exclamation marks or
praise. The visual register got friendlier and the voice did not move.

Reverses if: the warmth starts reading as a wellness product that cheers you on,
which is the thing the clinical guidance is most direct about avoiding.

---

### 039. The confirm step is for speech only
Aug 2026, Claude

Decision: a typed entry goes straight to beat one. Only a spoken entry shows
the transcript for send or discard.

Why: the confirm step exists because transcription can be wrong, and it is
wrong most often for exactly the students this product is meant to serve. A
student who typed their own words has nothing to confirm. Showing them "this is
what we heard" over text they wrote themselves reads as the app not having
listened, and it is a screen of friction between having something to say and
being answered.

Invariant 10 in FLOW.md, that no entry is submitted without the student having
seen the transcript, is unaffected. A typed entry is not a transcript. The
student is looking at their own words as they write them.

Found by typing into the running app, not by reading the code.

Reverses if: nothing.

---

### 040. The light theme broke text that was coloured for the dark one
Aug 2026, Claude

Decision: every colour that was chosen against a dark ground has been rechecked
against the light one. clayLight is now a background rather than a text colour,
and text on a tinted card uses clayDark.

Why: after the palette flip the pattern proposal was cream text on a cream card
and could not be read at all. Three files still carried hexes from the old
palette. Caught by looking at the running app.

The lesson worth keeping: a palette swap is not a token change. Any colour that
was picked for contrast against the old ground has to be rechecked, and the
compiler cannot tell you which ones.

Reverses if: nothing.

---

### 041. A typed entry was never spoken
Aug 2026, Claude

Decision: beat one says how long the student spoke only when they used the mic.
A typed entry reads "in your words".

Why: the screen told a student they had spoken for forty one seconds over text
they had typed. Same family as the confirm step running for typed input. The
app was describing something that did not happen.

Reverses if: nothing.

---

### 042. Open question: a held entry is never classified
Aug 2026, Claude

Not a decision. A gap found by running the submit path against a real database,
recorded so it is not lost.

The consent gate blocks every outbound call. The safety classifier is an
outbound call. So an entry from a student with no consent on file is stored
unprocessed and never read by anything, no safety_flags row is written, and
nothing surfaces to any adult, ever.

Verified: student_no_consent returned held, the entry exists, and safety_flags
has no row for it.

This is what FLOW.md asks for and it is also in tension with CONTEXT.md, which
says a published crisis protocol is required and not a design preference. It
affects new, unrostered and transferring students.

Three options, none of them mine to choose:

  1. An on device word list, no network and so no consent needed. Crude, high
     false positive rate, but nobody writes something urgent into a void.
  2. Treat safety classification as outside third party processing under the
     educational purpose exception. A legal question for whoever holds the
     district agreements.
  3. Refuse the entry rather than store it, and say the app is not ready for
     this student. Honest, and a closed door for someone who may need one open.

Needs an answer before any student uses this.

---

### 043. Reasoning models need a different call shape
Aug 2026, Claude

Decision: the gateway omits temperature for gpt-5 models, sends reasoning_effort
instead, and every token budget was raised to cover reasoning as well as the
reply.

Why: found by running it. Two separate failures, both of which showed every
student the help screen.

First, gpt-5 rejects any temperature other than the default. The safety
classifier asked for zero, every call four hundred'd, and the system failed
closed exactly as designed. The design was right and the request was wrong.

Second, reasoning tokens are billed against the same budget as the reply. The
classifier had two hundred tokens, spent all two hundred thinking, and returned
an empty string with finish_reason length. A model that thinks itself out of an
answer looks identical to a model that is down.

Budgets are now safety 900 at minimal reasoning, beat one 800 at minimal,
tagger 1200 at low, Mirror 4000 at low.

What this costs: the safety classifier can no longer run at temperature zero,
so the same transcript may not produce the same verdict twice. That matters for
an audit trail and it is not recoverable on this model family. Worth measuring
before it matters. gpt-4.1-mini would accept temperature zero if determinism
turns out to be worth more than the newer model.

Reverses if: a measured disagreement rate on repeated classification of the same
entry is high enough to undermine the flag record.

---

### 044. The Mirror thinks less than it wants to
Aug 2026, Claude

Decision: the Mirror runs at low reasoning with a sixty second ceiling.

Why: at medium it ran past forty five seconds on a short entry and was cut off.
The Mirror is asked for, so it may take longer than beat one, but a student who
taps look closer and waits a minute in front of a blank screen has been failed
whatever arrives afterwards. At low it returns in about eleven seconds with
output that passes the schema and the voice rules.

Reverses if: the quality difference between low and medium is large on the task
7 fixture set, which is the place to measure it.

---

### 045. Better models, bigger budgets
Aug 2026, Adnan

Decision: beat one, the Mirror and the tagger all run on gpt-5. Safety stays on
gpt-5-mini but moves from minimal to low reasoning. Budgets and timeouts raised
throughout: safety 2000 at 15s, beat one 2000 at 20s, the Mirror 8000 at medium
reasoning and 120s, the tagger 3000 at medium.

Why: founder call, and task 7 is explicit that a generic first line kills the
product, so beat one is worth the full model even on the latency path. Safety
stays on the smaller model because it blocks every write and a slow classifier
is a slow product, but low reasoning is worth a few hundred milliseconds for
the call that decides whether a student in trouble is seen.

What to watch: beat one on gpt-5 has not been measured against the three second
target. It came back quickly by hand but that is not a measurement.

---

### 046. The Mirror bled context from the previous entry
Aug 2026, Claude

Not a decision. A quality problem found by using the app, recorded before it is
forgotten.

A student wrote about staying up until two on a group project. The Mirror asked
"What stopped you from sending it?" and offered "send it to myself to keep a
record". Neither belongs to that entry. Both belong to the previous one, about
a message that was typed and never sent.

The context builder is working as designed. History goes in as a stable prefix
and the model is meant to know the whole person. What happened is that it
weighted a recent entry over the current one, which is the specific failure
mode decision 014 accepted when it put full history on the Mirror call.

This is what the task 7 fixture set is for, and it argues for extending that
set to cover the Mirror rather than only beat one. Candidate fixes, none tried:
separate the current entry more sharply in the prompt, cap recent entries below
eight, or say plainly in the prompt that the question must come from the
current entry alone.

Do not fix this by removing history. The product is built on the model knowing
the person.

---

### 047. The tab bar is on every place, and on no flow
Aug 2026, Adnan and Claude

Decision: all three destinations carry the tab bar, including home on day one.
The reflection flow, capture through confirm, beat one, the Mirror and the
pattern question, is pushed over the top and covers it.

Why: a place is somewhere you can leave and come back to. A reflection in
progress is not. Decision 001 says every path ends with the student acting,
deciding or talking to a human, and three escape hatches along the bottom of a
half finished reflection works against that.

What was actually broken: home on day one was rendered outside the shell and had
no tab bar at all, so a new student got a different navigation model from
everyone else. That is the same failure as an empty screen looking broken.

Reverses if: students get stuck inside the flow with no way out. The answer then
is a way out inside the flow, not a tab bar under it.

---

### 048. The consent screen is removed for now
Aug 2026, Adnan

Decision: screen 1 is gone. First run opens on the baseline set.

Why: founder call. It is defensible, because the screen's central line was not
true. It said "Nothing is shared with anyone unless you choose to share it"
while a crisis protocol exists that is legally required in California and New
York and involves telling adults. A promise broken the first time it matters is
worse than a narrower promise kept.

Legal consent is unaffected. It comes from the district under the educational
purpose exception, is recorded against the student at rostering, and the
consent gate still blocks every outbound call without it.

What was lost is clinical, not legal: the scope and confidentiality framing
Sofia asks for at the start, which she says determines what a young person is
willing to say. It should come back when the escalation policy exists and it
can state what is private, what must be shared for safety, and how adults are
updated. Until then it would be guessing.

Reverses if: the escalation policy is written, which it must be before any
student uses this.

---

### 049. The baseline set is ten questions, and each is answered differently
Aug 2026, Adnan and Claude

Decision: Set B, ten questions across five sections, asked once at first run.
Stored in baseline_answers, one row per answered question, skipped ones absent.
Nothing is scored and nothing is shown back to the student.

Four ways to answer rather than one: colour tiles for short options, a list
that floods with colour when chosen for longer ones, a scale you drag for the
one question whose options run in an order, and single words for the last.

Why four: ten screens of identical tiles is a form with paint on it. The shape
of the options decides the shape of the answer.

Where the playfulness lives: the interaction, not the words. Options arrive
staggered, tiles press in under the finger, the chosen one settles larger while
the others fall back, and the set advances itself. Nothing on any of these
screens praises the student or tells them what an answer means, because
CONTEXT.md forbids it and the clinical guidance is direct that telling a young
person what their answers say about them primes narratives that may not be
true.

Fixed one typo in the source: "Prompt me seek reassurance" reads "Prompt me to
seek reassurance".

Reverses if: the set proves too long. Ten is already at the edge for a first
run, and every question is skippable for that reason.

---

### 050. Each question gets its own way of answering, and answering is movement
Aug 2026, Adnan and Claude

Decision: five ways to answer rather than one grid. A field where a light is
dragged toward the choice that fits, a list that floods with colour, a scale
that is dragged and then confirmed, a sentence with a hole in it, and single
words. Each question carries its section as a coloured mark.

Why: a reference app was shared, and the thing worth taking from it was not the
palette. It was that every question had its own metaphor and that the answer was
something you moved rather than something you ticked. Ours uses our own warm
palette and our own serif. The reference framing and controls were not copied.

Where the pleasure is allowed to live: the interaction. Options arrive
staggered, the light follows the finger, the nearest choice lights up, the scale
labels itself as it moves. Nothing praises the student and nothing tells them
what a choice means, because CONTEXT.md forbids it and the clinical guidance is
direct that telling a young person what their answers say about them primes
narratives that may not be true.

Reverses if: the drag proves hard for anyone using VoiceOver or with limited
motor control, in which case every dragged control needs a tapped equivalent.
That is an accessibility gap and it is open.

---

### 051. Moving and choosing are separate on the scale
Aug 2026, Claude

Decision: dragging the scale sets where it sits. A confirm button commits it.

Why: committing on release was a dead end. Found by dragging it in the running
app: the label moved, the colour changed, and the screen never advanced,
because the drag end callback did not fire. A student would have sat on
question seven of ten with no way forward and no idea why.

It is also the better design. A slider you cannot adjust before committing is a
slider that punishes exploring it, which is the opposite of what this control is
for.

Reverses if: nothing.

---

### 052. Ten questions, ten controls, no repeats
Aug 2026, Adnan

Decision: every question in the baseline set is answered a different way.

  1  a light dragged across a field toward the corner that fits
  2  a list that floods with colour when chosen
  3  a night sky where the choices are stars
  4  a stack of cards, one pulled to the front
  5  ripples spreading out, the wider the stronger
  6  a deck swiped through one card at a time
  7  a scale dragged, then confirmed
  8  a sentence with a hole in it
  9  a dial turned toward a direction
  10 single words, picked up

Why: the first attempt built four controls and reused two of them across seven
questions, which is the same monotony the founder had already rejected once,
with better paint on it.

The control is chosen to say something about the question. A stack for
competing beliefs. Ripples for what emotion does, because that is what it feels
like. A dial for readiness, because readiness is a direction rather than an item
in a list. A night sky for what someone waits for, because waiting reads better
against something quiet.

Cost, and it is real: ten controls is ten things to maintain, ten things to test
on a small screen, and ten things to make reachable with VoiceOver. The
accessibility gap in decision 050 is now ten times larger. Every dragged and
swiped control needs a tapped equivalent before a district review, and that work
has not been done.

Reverses if: the accessibility review says a set answered ten different ways
cannot be made conformant. Then the answer is fewer controls, chosen well, not
a grid for everything.

---

### 053. The mic sits low and centred, and shows waves while held
Aug 2026, Adnan

Decision: the mic moves down into the middle of the screen with room around it,
and while it is held it fills with colour, grows, and shows a waveform either
side. The label changes from hold to speak to listening.

Why: founder call, and it corrects a real signal problem. The mic sat directly
under the typing field, which made the primary path look like an afterthought
attached to the secondary one. Decision 020 says typing is an equal path, not a
lesser one, and equal cuts both ways.

Not driven by the microphone yet. The bars run off a sine wave because there is
no recording until task 3. When there is, the amplitude replaces the sine and
nothing else about this changes. Until then the waves say the app is listening,
which is true, rather than showing a level, which would be a lie.

The animation runs only while the mic is held. An idle screen animating a thing
nobody is looking at costs battery for nothing.

Not verified visually. Screenshots are taken after the finger lifts, so every
frame that can be captured is the idle state. Confirmed by reading it back, not
by seeing it, and that is a weaker claim.

---

### 054. record for microphone capture, wav rather than aac
Aug 2026, Claude, with Adnan approving the dependency

Decision: the client uses the record package to capture audio, writes wav at
sixteen kilohertz mono, and deletes the file the moment the upload returns.

Why: Flutter has no microphone capture in the standard library, so this is
unavoidable if voice is a path at all. It is the only runtime dependency the
client carries.

Wav rather than aac because an aac container is finalised when recording stops,
and a short clip can reach the provider before that has happened. Deepgram
rejected those as corrupt audio. Wav is written straight through. Sixteen
kilohertz mono is what speech recognition wants anyway, so the file is barely
larger than the compressed one.

The transcript never lands in the typing field. It goes to the confirm screen,
send or discard, per decision 019.

Reverses if: a first party capture API appears, or upload size on school wifi
turns out to matter more than the container reliability.
