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

Reversed by decision 193. Kept because 016 and 018 refer to it.

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

---

### 055. First run is an intro, a profile, the baseline set, then home
Aug 2026, Adnan

Decision: first run is four screens in order. An intro that says what the app
does, four profile questions, the ten baseline questions, then home. It ends on
home rather than on a capture.

Why: founder call, and it closes two gaps. The product had no screen that said
what it was before asking a student to answer eleven questions, which decision
048 left open when the consent screen was removed. And first run used to end by
pushing a student straight into a capture, which made the first thing the app
ever asks of somebody a thirty second recording. Landing on home makes the
first capture a thing they choose.

The intro says what this is not, in three lines: it does not score you, name
what you feel, or replace anyone you would talk to. That is the scope framing
Sofia asks for, minus the confidentiality promise, which still cannot be made
until the escalation policy exists.

Rejected: keeping the baseline set first, which is what shipped. Eleven
questions before the product has said anything about itself is a lot to ask of
a twelve year old.

Reverses if: first run measurably loses students before home, in which case the
baseline set is the part to cut, not the intro.

---

### 056. The profile is a first name, an age band, a gender and a region
Aug 2026, Adnan, against the advice recorded here

Decision: first run asks four questions and stores the answers on the student
row. What we call you, how old you are as a band, your gender, and which region
you are in. Every question is skippable and none of them gates anything.

Why: the founder wants the app to know who it is speaking to. A reflection
product that writes a line back about a student and has to avoid naming them or
referring to them at all is working with one hand tied.

The shape is narrowed on purpose, and this is the part that was argued. The
schema held no names and no birthdates by design, because the students include
under 13s, the product is sold to districts, and every field held about a child
is a field named in a data agreement. So it is a first name and not a full one,
a band and not a birthdate, and a region and not a place. None of it is
required, and a student who skips every question still gets the whole product.

Rejected: full name, exact age and free text location, which is what was first
asked for. It adds a directly identifying record of a minor for no capability
the narrower version does not already give.

Also rejected: asking pronouns instead of gender. Pronouns are what generated
text actually needs. Gender was the founder's call and it answers the same
question for the model, less precisely.

Reverses if: a district review objects to any of it, in which case the first
name is the one worth defending and the rest can go.

---

### 057. The timezone is derived on the server from the region
Aug 2026, Claude

Decision: the client sends a region key from a fixed list. The server maps it
to an IANA timezone and stores both. The client never sends a timezone, and
"somewhere else" stores a null zone rather than a guess.

Why: a check back is scheduled days out and fired against whatever zone we hold
for that student, so the zone is a scheduling input rather than a display
preference. A string that arrived from a device is one we would have to trust.
A null is a state the scheduler can notice; a wrong zone is not.

Note what this does not yet fix. `enqueue.inDays` still hardcodes seventeen
hundred server time, so the stored zone is not read by anything. Wiring it is
a separate change to the job path.

Rejected: reading the zone from the device with a package. One more dependency
and one more name in a data agreement, to get a value we can derive.

Reverses if: the region list stops covering where students actually are, at
which point this becomes a real timezone picker.

---

### 058. Reset and fixtures are scripts, not rows made by hand
Aug 2026, Claude

Decision: `npm run db:reset -- --yes` truncates every table, and
`npm run seed` loads prompts and the two test students. The reset refuses to
run without the flag and refuses anything that is not localhost without a
second flag.

Why: the two test students CLAUDE.md promises existed only on the machine that
created them, so the documentation was true in one place and the first thing a
reset destroyed was the fixtures. Both are now reproducible in one command.

The guards are because this is the one script in the repository whose whole
purpose is to delete student data.

Reverses if: fixtures need to differ per developer, which would make this a
config file rather than a script.

---

### 059. The profile is a tab, not a settings screen
Aug 2026, Adnan

Decision: a fourth destination on the tab bar, after the week, the days and
the patterns. It shows every field the app holds about the student, each one
changeable, each one emptiable, and it names what is not held.

Why: founder call, and it is the right shape. What a product holds about a
child should not be behind a gear icon in a corner. Putting it on the bar means
a student can check it in one tap and a district reviewer can be shown it in
one tap.

Emptying is a real answer rather than a cancel. A field sent as null clears the
column; a field left out is untouched. That distinction is in the contract on
purpose, so taking an answer back reaches the database rather than only the
screen.

Reverses if: the bar gets a fifth destination, at which point four plus a
floating capture button is too many and this becomes the first thing to move.

---

### 060. The age bands reach adulthood
Aug 2026, Adnan

Decision: six bands rather than four. Under 13, 13 to 17, 18 to 24, 25 to 34,
35 to 49, 50 or over.

Why: founder call. The four school age bands assumed every user is a student in
a school, and the ladder now covers whoever else ends up holding the app.

Asked for as under 13, then 13 to 18, then 18 to 25, which puts an eighteen
year old in two bands at once. Each band ends where the next begins instead.

Six options do not fit as centred colour tiles on a small phone, so the age
question moved to the same scrolling list the regions use. The migration drops
old answers rather than mapping them, because 17_18 straddles two new bands.
That is safe only while no student outside this machine has answered it.

Reverses if: the product stays inside schools, in which case the four school
bands were the more useful cut.

---

### 061. Exact coordinates, asked from the device
Aug 2026, Adnan, against the advice recorded here

Decision: the where question asks the device for the student's position. The
coordinates are sent, stored on the student row, and shown back to the student
on the profile tab, where they can be removed. The region and the timezone are
derived from them on the server. Refusing the permission falls back to the
picker and costs nothing.

Why: founder call, asked for twice.

The case against it, recorded because it will be asked in a district review.
Nothing in the product needs a position. The region and the hour a check back
fires were already answered by the picker, and the picker is still there for
every student who refuses. What the coordinates add is precise location data
about a child, in a database sold to school districts, some of whose students
are under 13. That is a category of data with its own rules, its own breach
consequences and its own line in every agreement, held for a capability we
already had.

What was done to narrow it. The coordinates never choose their own meaning: the
server derives the region and drops back to elsewhere when nothing is within
two thousand kilometres. Nothing is geocoded, so no address is ever produced
and no third party sees a position. The permission string says plainly that the
exact position is saved and can be removed. The profile tab shows it as its own
line rather than folded into the region, and forgetting it clears both columns.

The cost that is not narrowed. geolocator is the second runtime dependency the
client carries and it brought twenty five transitive packages, each of which is
now a name in a data agreement that previously listed one.

Reverses if: a district review objects, or the escalation policy work concludes
that holding a child's position changes what has to be reported and to whom. At
that point the picker alone is a complete answer and the columns can be
dropped.

---

### 062. The intro says what reflection is before it says what the app does
Aug 2026, Adnan, wording his

Decision: the first screen opens with two paragraphs the founder wrote.
Reflection is not thinking harder about something, it is saying it out loud and
hearing what was actually in there. Most of it never gets said, it just sits,
shaping what you do next without you noticing. The mechanic follows in one
line, and the heading shortens to "Thirty seconds, out loud."

Why: the old opening described the product and never said what it was for. A
student who does not know what reflection is cannot want it, and the founder's
two paragraphs answer that in the product voice already, with no hyphens, no
reassurance and no jargon.

The heading shortened because the founder's first paragraph says what the old
one was reaching for. Thirty seconds stays, because it is the only concrete
promise on the screen and the whole product is built to keep it.

The order is idea, then absence, then mechanic. What this is not stays last and
unchanged.

Reverses if: students read the first two paragraphs as abstract and skip them,
which would put the mechanic back on top.

---

### 063. Sessions are a table the request path cannot read
Aug 2026, Claude

Decision: a signed in device is a row in `sessions` holding the sha256 hash of
its token, the student, the school, the district, an expiry a hundred and
eighty days out and a nullable `revoked_at`. The table is granted to nobody and
carries no policy, so `soul_student` cannot read it at all. The token itself is
returned once and stored nowhere on the server. A token starting with `soul_`
is looked up by hash, and anything else falls through to the `external_ref`
lookup that has driven the product from a laptop since the first day.

Why: the lookup happens before the transaction becomes `soul_student`, so the
request path never needs this table. Granting it read anyway would put every
device's token hash one missing where clause away from a student who already
holds a token of their own, which is the one row in this database that is worth
stealing. Every other table is scoped by a policy because the student has to
read it. This one is denied outright because they do not.

Storing the hash rather than the token is the same argument one layer down. A
leaked backup of this table is a list of hashes and a hash cannot be sent as a
bearer token.

`revoked_at` is set rather than the row deleted, because a district asking when
a device stopped being trusted needs a row to read. Signing in on a second
device leaves the first session alone, since a student with a phone and an iPad
has two devices rather than a problem.

Reverses if: something on the request path genuinely needs to list a student's
own devices, at which point this needs a policy scoped to `student_id` and a
column set that does not include the hash.

---

### 064. Apple tokens are verified with node crypto, and the link is written once
Aug 2026, Claude

Decision: the identity token is verified in about eighty lines using
`node:crypto`. Apple's keys are fetched, cached in memory for ten minutes, and
turned into public keys with `createPublicKey` from the JWK modulus and
exponent. A key identifier that is not in the cache triggers exactly one
refetch before the token is refused. The algorithm has to be RS256, the issuer
has to be Apple, the audience has to be `APPLE_BUNDLE_ID`, the expiry has to be
in the future, and the subject has to match the account the client named.
Claims are read only after the signature has verified.

Why: the alternative is a JWT library, which is a package on the dependency
list and a name in every district data agreement, for work that is one fetch,
one key construction and one signature check. The rule in CLAUDE.md is one more
function over one more package, and this is what that rule looks like when it
costs something.

The refetch matters more than it looks. Apple rotates signing keys without
notice, and a rotation mid cache is indistinguishable from a forged key
identifier at the moment it arrives. One extra request is cheaper than a
student who cannot sign in until a cache expires.

Also decided, because the contract does not say: when the roster bearer
resolves to a student who already carries a different `apple_user_id`, the
sign in is refused rather than the column overwritten. Overwriting would hand
one student's entries to another Apple account, and a debug build carrying a
roster reference is exactly the situation where that happens by accident. When
the Apple subject is already linked, that student wins over the roster bearer,
because the account is the credential that was just proven and the roster
reference is only the build's default.

Every refusal is one status and one body. The reason goes to the log, never to
the client, because a caller working out which check it failed is being helped
to pass it.

Reverses if: a district needs a device moved between students without touching
the database, which would need a revoke and relink path rather than a silent
overwrite.

---

### 065. The session token is the only thing the client keeps on the device
Aug 2026, Claude

Decision: `app/lib/data/session_store.dart` is the only place in the client
that touches secure storage. It holds one key in the keychain, at Apple's
default accessibility, reads it once per launch and remembers the answer, and
never throws at a caller. `SoulApi` picks its bearer per request: the stored
session token when there is one, the compile time roster token otherwise.

Why: the token is the one secret the app carries, so it belongs in the keychain
rather than a preferences file that ships in plain text inside a backup. One
file owns it because a secret read from four places is a secret leaked from the
fourth. The bearer is chosen per request rather than fixed at construction
because every screen builds its own `SoulApi` and none of them should have to
know whether sign in has happened yet.

The expiry the server returns is not stored. The only thing the client could
do with an expired token is refuse to send it, and the server refuses it
anyway, so keeping the date would add a second clock that can disagree with the
first.

A keychain that will not open reads as no token. That walks a student through
first run again, which is a bad morning rather than a broken app, and it is a
better failure than a screen that cannot load.

Reverses if: something else on the device has to be kept, at which point this
becomes a store with more than one key and the read once cache needs a way to
be invalidated.

---

### 066. A signed in student opens on the populated home
Aug 2026, Claude

Decision: on launch, a stored session token opens `Home` with its default
week rather than the day one version. No token opens first run.

Why: day one is a real state and it is the one first run ends on, but a student
who signed in has already been through the loop at least once, so showing them
the empty week would be describing a day they have already had. The week itself
is still sample content, like the rest of the shell, so this chooses between
two placeholders and picks the one that is not actively false.

The development skip stores nothing, on purpose. A skip that left a token
behind would hide first run from the next launch, which is usually the exact
thing the person pressing it wants to see again.

Reverses if: there is a call that returns the real week, at which point the
count comes from the server and this stops being a choice.

---

### 067. The three read screens each ask for their own data and own three states
Aug 2026, Claude

Decision: `HomeScreen`, `DayScreen` and `PatternsScreen` are stateful, hold a
`SoulApi`, and call `/week`, `/day/:date` and `/patterns` themselves. Each one
renders exactly three states before it renders anything else: waiting, a
failure with a Try again button, and an empty state written for that screen.
The shell passes a `revision` counter that changes when an entry lands, and a
screen whose revision changed asks again rather than counting anything up on
the device.

This is the call decision 066 said would settle it. A signed in student now
opens on whatever the server returns, and the day one screen is shown when the
week has no moments in it rather than when a flag says so.

Why: `ProfileTab` already worked this way and it is the right shape. A tab that
failed to load is retryable on its own, without taking the other three with it,
and the shell does not have to know the shape of three different responses. The
counter exists because the alternative, adding one to a number the server gave
us, creates a second version of the week that can disagree with the stored one.

Every empty state is written before the populated one, so a student with no
entries this week sees the day one screen, a day with nothing in it says so in
one line, and a student with nothing repeating yet is told that plainly instead
of being shown three patterns nobody has.

Reverses if: two screens need the same response, at which point one owner above
them beats two calls that can disagree.

---

### 068. Every date is a string the server wrote, except one
Aug 2026, Claude

Decision: dates cross the wire as YYYY-MM-DD and the client keeps them as text.
The date on a week dot is passed back to `/day/:date` untouched, and nothing on
the device works out where a week starts or which day an entry belongs to. The
one exception is `todayOnDevice()` in `day_screen.dart`, which is the day the
Days tab opens on before the student has picked one, and the day the week strip
outlines as today.

The instant on an entry, `at`, is held and not shown. Reading a clock time off
it would mean choosing a timezone in the client, and the order the entries
arrive in already says what the screen needs.

Why: weeks and days are bounded by `students.timezone` on the server, so a
Sunday evening in Los Angeles lands on Sunday. Parsing those strings into
instants here would put a second clock, the device one, next to the student's
own, and the two disagree for exactly the students the boundary rule exists
for. The one exception is a default selection rather than a boundary: a phone
in a different zone to the student's region can open the neighbouring day, the
entries inside it are still cut by the server, and every dot on the week strip
carries a server date so tapping one is always exact.

Reverses if: the day screen has to show times, which needs the offset the
entry was written at, either sent as its own field or read off the string.

---

### 069. The four colours are handed out by position, not by feeling
Aug 2026, Claude

Decision: nothing maps a feeling to a colour. The week ring colours its arcs by
position in the themes list, which arrives highest first, and the day timeline
colours its dots in the order the feelings appear on that day. An entry the
tagger has not reached yet takes a quiet grey. The same feeling can therefore
be one colour on the week and another on the day.

The day dots on home carry no feeling colour at all. They are filled when
something was written that day and empty when nothing was.

Why: the read contract has no colour in it and feelings are free text from the
tagger, so any fixed mapping would be a table in the client guessing at words
it has not seen. Position gives four distinct colours where distinctness is the
whole job, which is telling one arc from another and one line of the key from
the next. A day dot that guessed a feeling from a count would be the app making
something up on the screen that is meant to be a record.

Reverses if: the contract starts naming a colour, or feelings become a closed
set, at which point one mapping can be true everywhere.

---

### 070. Anything on these screens with no data behind it was removed
Aug 2026, Claude

Decision: `app/lib/data/sample.dart` is deleted. Four things that only existed
because of it went with it: the held decision card on home and its three
outcome buttons, the pattern count under the What keeps returning card, the
closing observation and the Yes and Not really buttons on the day screen, and
the twelve week strip under each pattern. The `SOUL_SCREEN` entries for beat
one, the Mirror, the confirm step, the outcome screen and the pattern question
are gone too, because opening one of those directly means handing it a
reflection nobody wrote.

Why: the read contract carries no held decision, no pattern count for home, no
per week marks and no observation about a day, and the way to show one anyway
is to invent it. Moving the strings into another file would have kept the same
problem with a different name on it. Those five screens are still reachable in
design review by walking the loop with the API running, which is also the only
way to see them with real words on them.

Reverses if: a held decision is added to the week contract, or pattern
supporting entries come back with the weeks they fall in, at which point the
card and the strip come back with something true in them.

---

### 071. Reads have a deadline, writes do not
Aug 2026, Claude

Decision: `SoulApi._get` gives up after twenty seconds. The write path is left
alone.

Why: the connection timeout does not cover a connection that opens and then
goes quiet, and the three screens that read are the ones a student sits in
front of. Without a deadline their waiting state has no end and no way out of
it. Writes are different: the Mirror thinks for a while, and cutting one off
would show a student a failure for a response that was on its way.

Reverses if: a read gets slow enough to be worth waiting longer for, which
would mean the twenty seconds moves rather than that it goes.

---

### 072. The read side runs as the student, inside the row level security role
Aug 2026, Claude

Decision: `/week`, `/day/:date` and `/patterns` do their work inside
`asStudent()`, so the role is `soul_student` and `app.student_id` is set for
the transaction. Every query inside still names `student_id` itself.

Why: `asStudent()` has been in `session.ts` since the beginning and nothing
called it, which meant invariant 3 was true on paper and application code was
the only guard in practice. Reads are the place that matters most, because a
missing where clause on the write path writes a row nobody sees and a missing
one on a read puts another student's entries on a screen. Both guards cost one
transaction and neither is load bearing on its own.

The write path was left as it was. It is not this task and changing how the
orchestrator talks to the database is a change that needs the quiz.

Reverses if: a read has to cross students, which the counsellor console will
need. That is a different role with its own policies, not this one widened.

---

### 073. Weeks and days are cut in Postgres, with the student's own timezone
Aug 2026, Claude

Decision: the boundary is `(created_at at time zone tz)::date` and the week
starts at `date_trunc('week', now() at time zone tz)`, where tz is
`students.timezone` and UTC when that is null. The week is always seven rows,
built from `generate_series` and left joined to entries, so a week with nothing
in it is seven zeros rather than a short list. Monday first comes free with
`date_trunc('week')`, which is the ISO week. `moments` is the sum of the seven
days rather than a count of its own.

Why: a student in Los Angeles writes at eight in the evening on Sunday and that
is Sunday. Anywhere else in the system that boundary would be a preference; on
this screen it decides which week the entry appears in at all, and for the
students furthest from the server it is wrong every night rather than
occasionally. Postgres knows the rules, including the two days a year the
offset changes, and doing it here means the app cannot draw a different week to
the one the database counted.

Seven rows always, because the empty state is the first one built. A ring with
three dots on it is a broken looking screen, and the day one week has to look
like the same week as any other.

`moments` is summed from the days it is drawn from, so the number above the
ring cannot disagree with the ring under it.

Reverses if: a student can be in two timezones in one week, which is a trip
rather than a move and would need the offset stored per entry.

---

### 074. A theme belongs to the week the entry was written in
Aug 2026, Claude

Decision: the themes on `/week` come from `tags` joined to `entries`, bounded
by `entries.created_at`, never by `tags.created_at`.

Why: the tagger runs after the student already has their response, so a tag can
be written minutes or hours after the entry, and an entry written at eleven at
night can be tagged after midnight. Bounding on the tag would move that theme
into the next week, where the student would read a feeling that has no entry
under it in the same seven days.

Reverses if: nothing sensible. The tag time is the time we did the work, which
is our fact about the entry rather than the student's.

---

### 075. A tag the tagger was unsure of does not reach a screen
Aug 2026, Claude

Decision: both read endpoints ignore tags below 0.6 confidence, the same floor
`findCandidates` applies before a theme can support a pattern. Where an entry
carries more than one tag above the floor, the newest wins.

Why: the schema rule is that low confidence tags must not support a pattern
claim, and a theme on the week screen and a feeling under an entry are the same
kind of claim in a smaller font. The database already holds tags at 0.1 and
0.2, and the honest answer for those entries is nothing rather than a guess in
the student's own words back at them. Newest wins because a second tag on one
entry means the tagger ran again, and the later run is the one that saw the
current tagger version.

The cost is that the number is now written in two files. They are the two
places that decide what a tag is allowed to become, and a floor for a pattern
that differs from the floor for a label would be worse than the repetition.

Reverses if: the tagger's confidence becomes well calibrated enough to be worth
showing a weak tag differently rather than not at all.

---

### 076. Instants cross the wire as UTC text the database wrote
Aug 2026, Claude

Decision: `at` and `confirmedAt` are formatted by `to_char` at time zone UTC,
in the shape `2026-08-24T06:30:00.000Z`.

Why: drizzle turns off date parsing on the connection it shares with the raw
query path, so a timestamp arrives from the driver as the string Postgres
printed, in the server's own offset. Formatting in the query means nothing on
this side parses that string and nothing depends on a driver setting made
somewhere else. UTC because the week and day boundaries were already drawn
against the student's timezone, so nothing downstream has a boundary left to
work out, which is also what decision 068 relies on.

Reverses if: the day screen has to show clock times, which needs the offset the
entry was written at rather than a normalised instant.

---

### 077. The runner claims only the types it can run
Aug 2026, Claude

Decision: the claim query filters on a list of handled types. `embed_entry` is
not in it, so those rows sit pending until task 8 gives them a worker. The
three rows that had already been claimed and marked done were set back to
pending, because the entries behind them are still unembedded.

Why: the case in the runner returned without doing anything and the row was
then marked done, so the backlog the comment promised did not exist and three
entries were quietly written off. Not claiming at all is the smallest way to
say that: the rows stay due, `jobs` still reads as the truth about what is
outstanding, and an old worker meeting a job type it has never heard of leaves
it for the worker that can run it instead of failing it five times.

Rejected: claiming the job and pushing `run_at` into the future. The runner
would take a job it cannot do every hour, and every one of those is an attempt
against a limit that exists for jobs that are actually failing.

Reverses if: a typo in a job type needs to be loud. Today it waits silently,
which is the same shape as a job type that has not shipped yet.

---

### 078. The sweep is a job, and it books its own next night
Aug 2026, Claude

Decision: `pattern_sweep` is a job type. The runner runs `sweep()` unchanged
and then schedules the next one for three in the morning, server time. Exactly
one sweep is pending at any moment, and the runner books one at startup if
there is none, so the chain starts itself and cannot double when the worker
restarts.

Why: it was a script with a main block that nobody ran, so `pattern_candidates`
was always empty and no pattern could ever be offered to a student. The whole
loop past the tagger depended on somebody remembering to type a command. A job
means the only thing that has to be running is the worker that is already
running for tagging and check backs.

The sweep is the one job with no student, because it is one query across all of
them. Reading the student out of the row where it is used rather than before
the switch is what lets that be true without a second runner.

Three in the morning is the server's clock, not a student's. Students are in
several timezones and the sweep is one query over all of them, so the hour is
about when the database is quiet rather than when anybody is asleep. Nothing it
writes is seen until the student next opens the app.

Rejected: a timer inside the API process, which dies with a deploy and runs
twice the moment there are two instances. Rejected: a cron entry, which is a
second thing to install on every machine and is invisible from inside the
product.

Reverses if: the sweep grows long enough that one run for every student at one
hour is too much, at which point it splits by district and each piece gets its
own run time.

---

### 079. What the patterns screen counts, and what it leaves out
Aug 2026, Claude

Decision: `reflections` is every entry the student has ever written. `confirmed`
excludes anything with `removed_at` set. `forming` is the candidates at pending
and surfaced, newest first, and `supporting` is the number of entries behind
each one rather than the ids.

Why: a pattern the student took back with this is not me should be gone from
the screen, not greyed out on it; the row stays in the database because a
rejection is signal, and that is a different question from whether to show it.
Surfaced counts as forming because a candidate that was offered and not
answered is still waiting, and a student who tapped later is asking to be shown
it again rather than saying no. The count is enough for the screen that exists;
the ids matter when a student asks which entries, and that is the screen that
shows the entries.

Reverses if: the screen has to show which entries are behind a pattern, which
needs the ids and probably the entries themselves rather than a number.

---

### 080. What the student chose lives on the screen, not on the wire
Aug 2026, Claude

Decision: `DayView.cards` carries exactly the five fields the contract names,
so a card says that it was answered and never says what with. `DaysScreen`
keeps a `CueCardAnswer` per card id for the cards answered in front of it, and
a card answered on an earlier day shows the thing it was about and the single
word answered.

Why: the day shape was given and the client does not get to add fields to it on
a guess. The words matter for the seconds after the student taps, which is
where the card has to say what it now holds rather than snapping to a blank,
and the map covers exactly that. Holding it on the screen rather than inside
the card widget means the answer survives the day being read again, which
answering a card causes.

Rejected: parsing a chosen field that the contract does not promise. It would
be dead code until the server happened to send it and would read as a contract
that exists.

Reverses if: the day starts returning what was chosen, at which point the map
goes and the card reads the answer off the card like everything else.

---

### 081. One field, in both directions
Aug 2026, Claude

Decision: there is a single field under the three options. With an option
selected it is anything the student wants to add and the label says so. With
nothing selected it is their own words and becomes the whole answer, which is
`optionIndex` null on the wire. Tapping a selected option again clears it,
which is the way back from an option to their own words. The button is off
until there is an option or some words, and off again past five hundred
characters, under a line saying that is the most it holds.

Why: the product turns on the gap between what was offered and what the student
actually chose, so writing their own has to be as reachable as picking one of
the three rather than sitting behind a fourth option called something else. A
second field for their own words would ask them to understand the difference
between two empty boxes before they could answer.

Cutting their words down to five hundred characters silently was the other way
to keep inside the contract, and a student who is mid sentence deserves to be
told the field is full rather than to find the end of what they wrote missing.

Reverses if: students pick an option and then type over the top of it, which
would mean the field reads as an edit of the option rather than an addition.

---

### 082. Four days to choose from, not thirty
Aug 2026, Claude

Decision: the card offers tomorrow, in three days, in a week and in two weeks,
which are horizons of 1, 3, 7 and 14. It starts on three days, the same horizon
the Mirror path holds a decision for.

Why: the endpoint takes 1 to 30 and a calendar for it would be the largest
thing on the card, aimed at the smaller half of the question. Four named
distances are the ones a student says out loud, and they cover the exam on
Friday and the conversation that has been waiting a fortnight. Starting on a
day rather than on nothing means a student with nothing to say about timing
still has a card that works, and three matches what a held decision already
means everywhere else in the app.

Reverses if: check backs land wrong often enough that the day is worth asking
for exactly, which is a calendar and a different card.

---

### 083. A card the server has already answered is not a failure
Aug 2026, Claude

Decision: a 409 or a 404 from the answer endpoint reads the day again and says
nothing. Every other failure is thrown on to the card, which shows a line and a
way to try again.

Why: both of those mean the card is not open any more, either because it was
answered somewhere else or because it is not this student's. Offering try again
for those puts a student in front of a button that cannot work. Reading the day
again brings the card back in the state it is actually in, which for an already
answered card is the answered one. A dropped connection is the opposite case:
nothing was written, and trying again is exactly right.

Reverses if: the day read after a 409 becomes expensive enough to be worth
telling the card directly that it is answered.

---

### 084. Try again inside an open day now tries again
Aug 2026, Claude

Decision: the failure line inside an open day calls the read, not `_openDay`.

Why: `_openDay` closes the day it is already on, and the day is open while its
failure line is showing, so the only thing try again did was shut the day. A
student whose day did not load had no way to ask for it a second time short of
tapping the row twice. Cue cards arrive inside that same read, so the one way
back into a day that did not load had to work before anything was put in it.

Reverses if: nothing.

---

### 085. A cue card belongs to the day of the entry it came from
Aug 2026, Claude

Decision: `/day/:date` bounds cards on `entries.created_at` in the student's
own timezone, never on `cue_cards.created_at`.

Why: the generation job runs after the tagger, which runs after the student
already has their response. A card made from an entry written at half past
eleven can be written after midnight, and bounding on the card would put it on
a day with nothing behind it while the day it is about shows none. Same rule
and same reason as the themes on the week, which are bounded by the entry and
not by the tag.

Also decided here, because the shape says at most two and does not say which
two: unanswered first, then oldest first inside each group, which is the order
the entries above them read in. An answered card stays on its day rather than
vanishing from it, so a student can see what they said they would do.

Reverses if: nothing. The card is about something in the entry, so the entry is
what dates it.

---

### 086. offered_text holds the whole offer, all three options
Aug 2026, Claude

Decision: a decision written from a card stores `chosen_text` as the option the
student took or the words they wrote instead, and `offered_text` as the three
options joined one per line.

Why: the gap between those two columns is the most interesting data in the
system, and a card offers three things rather than one. A student who wrote
their own turned down three specific sentences, and a row recording nothing as
offered would say they were given nothing. Uniform either way, so asking
whether the student took what was offered is asking whether `chosen_text` is
one of the lines, rather than asking two different questions depending on how
they answered.

Nothing shows `offered_text` to a student today, so the column is free to be a
record rather than a sentence.

Rejected: storing only the option they picked, which loses the offer in exactly
the case worth looking at. Rejected: a column of its own, which would be a
change to the decisions table so that a card could be a different kind of
decision, and the whole point is that it is not one.

Reverses if: `offered_text` reaches a screen, at which point three lines in one
column is the wrong shape and the card row is where the options should be read
from.

---

### 087. Answering a card claims it under a lock, and the decision is the existing one
Aug 2026, Claude

Decision: `services/cards/answer.ts` opens a transaction, selects the card
`for update` scoped by `student_id`, decides the 404 and the 409 under that
lock, calls `createDecision`, and then writes the decision id, the chosen
index, the detail and `answered_at` onto the card.

Why: the card is claimed by the decision being written onto it, and the
decision has to exist before it can be written. Without the lock a student
tapping twice writes two decisions and is asked about the same thing twice,
days later. `createDecision` rather than a copy of it, because a decision made
from a card and one made from the Mirror have to be the same thing everywhere
downstream, which includes the check back it schedules.

Three smaller choices the contract does not make.

An id that is not a uuid gets the same 404 as an id belonging to somebody else.
It names no card of theirs either, and separating the two would tell a caller
which of them they got wrong.

`horizonDays` is required rather than defaulting to three the way `/decisions`
does. The student names a day on the card, so a call without one is a client
that lost it rather than a student who did not say.

The write runs on the ordinary connection with `student_id` in the where
clause, not inside `asStudent`. That is what every other write in the product
does, and decision 072 left moving the write path under row level security as
its own change with its own quiz. The read side is untouched, so the cards on
`/day/:date` are read as `soul_student` like everything else on that screen.

Reverses if: the write path moves under `asStudent`, which this should move
with rather than be left behind by.

---

### 088. A card names the entry it came from, and the number is checked
Aug 2026, Claude

Decision: the entries are numbered in the message the model is given, every
card has to return `from` as one of those numbers, and `cue_cards.entry_id` is
the entry that number points at. A card whose number is outside the list is
dropped and the other one is kept.

Why: the whole feature rests on a card being about something the student
actually named, and a model can be asked to prove that rather than be trusted
with it. A number into a list it was just given is the cheapest proof it can
offer and the only one this side can check without reading the entries again.
It also makes the row honest: the card sits on the day of the entry it came
from, per decision 085, and attributing every card to whichever entry
triggered the job would have put a card about Friday on a Sunday.

Dropping the one card rather than the whole reply, because the second card may
be about a thing the student really did name and refusing it too would punish
the good half of an answer.

Reverses if: the model starts numbering reliably enough that a card can name
the entry id itself, which would remove the mapping step rather than the check.

---

### 089. What the cue card row holds beyond the card
Aug 2026, Claude

Decision: `cue_cards` stores the prompt version and the model version that
wrote it, and `answered_at` is what says a card has been dealt with.

Why: the versions are already on the generation row, and they are here as well
because a card outlives the day it was made. The first question about a bad
card is which prompt wrote it, and answering that from a generations join
means matching on a student and a minute rather than reading one row.

`answered_at` rather than reading `decision_id`, because `chosen_index` is
null when the student wrote their own words and null is a real answer there.
The screen wants the unanswered ones first, which is an order, and an order
wants a time.

Reverses if: cards start being rewritten rather than written once, at which
point the version belongs to a revision of the card and not to the row.

---

### 090. A dash in a card refuses the card
Aug 2026, Claude

Decision: the zod schema rejects any about, question or option containing a
hyphen, an en dash or an em dash, and rejects three options that are not three
different sentences. A card that fails is not repaired.

Why: no hyphens in anything a human reads is a house rule, and the last moment
it can be kept is before the row is written. Cleaning the text instead would
put us in the business of editing what the model said, and a card is student
facing copy that nobody reviews before it appears.

Refusing costs almost nothing here, which is the part that makes it the right
choice. The feature is built on no card being an acceptable answer, so a
refused card is the same outcome as a quiet day.

Reverses if: refusals start showing up often enough to be silencing real cards,
which would mean the prompt is not carrying the rule and the prompt is what
should change.

---

### 091. Two cards a day, in the student's own day, counted before the model is called
Aug 2026, Claude

Decision: the cap is two cards per student per day, the day is bounded by
`students.timezone` the way the week and day screens are, and the count is read
before the gateway call rather than after it.

Why: a student who writes five times in an evening is five jobs, and four of
them have nothing to do. Checking after the call would spend five model calls
to write two rows, and the whole point of this being a job is that it is
allowed to be slow, not that it is free.

The student's own day, for the reason decision 073 gives: an entry written at
nine on Sunday evening in Los Angeles is Sunday, and a card written against the
server's clock would be the third of a day the student is still in.

Reverses if: cards move to being made once a night for everybody, which makes
the cap a property of the sweep rather than of the job.

---

### 092. Cards are made only from entries that passed the classifier
Aug 2026, Claude

Decision: both the entry the job names and every entry the model reads are
joined to `safety_flags` and kept only at risk level none or low. An entry with
no flag row has not passed anything and is not read.

Why: a card asks a student what they want to do about something, and the one
kind of entry that must never turn into that question is the one the classifier
flagged. Requiring the row rather than checking for the absence of a bad one is
what makes it fail closed: an entry the classifier never saw reads the same as
one it stopped.

This is why the demo student's ten entries were given safety rows by hand,
carrying the same seeded classifier version the fixture already puts on its
tags. The fixture writes rows straight into the database rather than going
through `submit`, so it had never written the flag the write path always
writes, and without it the demo student could produce no cards at all.
`seed_demo.ts` should write them itself and belongs to whoever owns that file.

Reverses if: nothing. This is the same shape as invariant 1 one step further
down the line.

---

### 093. The tagger enqueues the card job, and the card call is the slowest one we have
Aug 2026, Claude

Decision: `tagEntry` enqueues `cue_cards` after the tag row is written. The
purpose runs at temperature 0.3 with medium reasoning and a hundred and twenty
second timeout, the same budget the Mirror has.

Why: two jobs rather than one, so a card is never the reason an entry ends up
untagged. Tags are what patterns, themes and the week screen are built on, and
this call is the longest in the queue: the run against the demo student took
fifty seven seconds and spent most of it thinking.

Low temperature because a card has to quote the student rather than write a
better sentence than the one they wrote. Medium reasoning because the answer
this call gets wrong when it is hurried is the empty one: deciding that a week
of entries points at nothing is harder than writing a card about it.

Nobody is waiting for any of this. It happens after the student has read their
line and gone.

Reverses if: the queue grows a class of jobs that are actually urgent, at which
point a hundred and twenty second job needs its own worker rather than a place
in the same line.

---

### 094. The worked example in the prompt names a situation nobody wrote
Aug 2026, Claude

Decision: the good example in `cue_cards.v1.md` is a trial for a team on
Tuesday, which appears in no entry any test student has written.

Why: the first version of the prompt used three things due Friday, taken from
the demo week because it read well. The model returned that card almost word
for word, including two of the three options, and there was no way to tell
whether it had read the student or copied the example. Changing the example to
a situation the entries do not contain made the next run quote the student
instead.

An example in a prompt is training data for one call. If it overlaps the input,
the output stops being evidence of anything, and this is the one prompt in the
product whose failure mode is writing about something that was never said.

Reverses if: nothing. Any example added here should be checked against the
fixtures first.

---

### 096. The two outcome sections are titled as a record, not as a result
Aug 2026, Claude

Decision: on the Returning tab the two new groups read `What left you lighter`
and `What left you heavier`, each under the small line `from what you said
afterwards`. No other wording sits near them. The page is titled `So far`, the
confirmed section keeps `What keeps returning`, and the candidates sit under
`Still forming` with `not enough to say yet`.

Why: the split is the student's own verdict, taken from `outcomes.felt`, and
the screen has to look like it. A heading that named the app as the source, or
any line offering what to do with a heavier theme, would turn a record of their
words into advice and then into a telling off. The attribution line is the
whole defence: it says where the group came from, once, and stops.

Nothing on the screen praises the lighter group either. Praise for one half is
what makes the other half a warning, and the two sections are deliberately the
same shape, the same size and the same amount of language.

`So far` for the page because `What keeps returning` moved down to become the
heading of the confirmed section and the page needed a title that claims less
than its parts.

Reverses if: a student reads the heavier section as being told off anyway, in
which case the fix is the section, not the sentence.

---

### 097. A proportion bar carries each row, in colours that are not a verdict
Aug 2026, Claude

Decision: every row on the tab is the theme, a bar, and one line of two facts,
how many times and when the last one was. Bar colours are moss for lighter,
violet for heavier, clay for confirmed and border2 for forming. The two verdict
sections share one scale and the two pattern sections share another.

Why: the tab had been stripped to plain text and read as a list rather than a
screen. The bar is the same idea the week ring on home is built on, that the
proportion answers which of these came back most before any number is read.

Green against red was refused. A traffic light is the app grading the two
groups, and the point of the split is that it is not grading anything. Moss and
violet are two of the four theme colours the ring already uses, neither of them
loaded, and violet in particular carries no alarm.

Two scales because the verdict rows count answered check backs and the pattern
rows count entries behind a claim. One shared scale would draw those two
different things against each other and mean nothing. The fill is floored at
nine percent so a count of one against a count of nine is still visible.

Reverses if: a student is shown a theme in both groups at once and reads the
two bars as a comparison. They are not comparable in that direction and would
need splitting visually.

---

### 098. The device turns the two timestamps into whole days, and never finer
Aug 2026, Claude

Decision: `lastAt` and `confirmedAt` are rendered on the device as today,
yesterday, a count of days, weeks or months. The difference is taken between
two local midnights rather than in elapsed hours, and an unparseable string
gives no phrase at all, leaving the line with one fact instead of two.

Why: the founder asked for when it last happened and the wire carries an
instant, so something on the device has to read it. `DayEntry.at` is held and
deliberately not shown because a clock time would mean picking a timezone here,
and that reasoning still holds. A whole day count does not: it survives a
student travelling, and midnight to midnight is what makes an entry written at
half past eleven read as yesterday rather than as today.

The lists themselves are parsed through a missing group rather than a required
one, though the contract sends both arrays always and the server already does.
A client that is ahead of a server costs the student two sections that way, and
costs them the whole tab otherwise.

Reverses if: the server starts sending a rendered phrase, which would be the
better answer since it already knows the student's timezone and the device is
only guessing with the one it is set to.

---

### 096. Lighter and heavier come from outcomes.felt and from nothing else
Aug 2026, Claude

Decision: `GET /patterns` carries two more arrays. `lighter` and `heavier` are
built by one query that joins `outcomes` to `decisions` to the `tags` row on the
entry the decision came from, keeps `felt` of lighter or worse, and groups by
theme and by verdict. `same`, an outcome the student never answered, and a
decision with no outcome yet are all left out, so a theme nobody has answered
about is in neither list and stays what it was.

The confidence floor is `MIN_TAG_CONFIDENCE`, the same one the rest of the read
side and the nightly sweep apply. A theme too uncertain to print under an entry
is too uncertain to head a section.

Why: the split had to be the student's verdict and not ours. The only column in
the database that holds a verdict is `outcomes.felt`, which nothing but the
student writes, so the query groups by it and does no reading of its own. It
does not score an entry, it does not look at the feeling tag, and it cannot
put a theme in a list the student did not put it in.

The word on the wire is heavier rather than worse. Worse is the student's answer
to what happened, in their own head. Heavier is what the app is willing to call
a section, and the difference matters because a section named worse reads as a
verdict on them rather than a record of what they said. Nothing downstream may
turn that list into a warning: it holds what they said left them heavier and
adding so maybe stop to it would be the app saying something they did not.

Reverses if: outcomes gain a second signal the student sets themselves, at which
point the grouping is over both and not over `felt` alone.

---

### 097. The two lists are ordered by when it was last said, and a theme can be in both
Aug 2026, Claude

Decision: rows in `lighter` and `heavier` are ordered by `lastAt` descending,
not by `times`. A theme the student answered lighter once and worse once appears
in both lists, once each, carrying only its own count.

Why: ordering by count builds a chart of their worst theme at the top and holds
it there for months. Ordering by recency means the list moves when their life
moves, which is the only thing on this screen a student can affect.

Letting a theme sit in both lists is the same argument. Picking a winner would
mean deciding which of two things they said is the truer one, and the app has no
grounds for that. Both rows are things they said, so both rows stay.

`times` is the count of outcomes behind the row, distinct on the outcome, so a
second tag on the same entry cannot inflate it.

Reverses if: a student is shown both lists and reads a theme in both as the app
contradicting itself. That is a question for task 7 and not one to answer from a
desk.

---

### 098. Card decisions already reached the context builder, so nothing was added to it
Aug 2026, Claude

Decision: `buildContext.ts` gained a comment and no code. Answering a cue card
already writes a `decisions` row, and the builder reads open decisions and past
outcomes from that table with no filter on where the decision came from, so a
thing chosen on a card has been in the model prompt since cards existed. The new
`lighter` and `heavier` query counts them for the same reason.

Why: the check was worth making and the result was worth writing down. Two
places write a decision, `services/decisions/create.ts` and
`services/cards/answer.ts`, and the second one writes it on its own transaction
rather than calling the first, for the connection pool reason written up in that
file. Two writers of one table is the
shape most likely to drift, and the day one of them grows a column the other
does not is the day a card answer stops being a decision everywhere downstream.
The comment says what would have to be added back by hand if cards ever get a
table of their own.

Verified by answering both of the demo student's cue cards through
`POST /cards/:id/answer` and rendering the context: the card answers came back
under things they are currently holding, then under what happened when they
acted before once outcomes were recorded, in the same list as the decision the
seed wrote, with nothing to tell them apart.

Reverses if: cards ever need something on the decision row the Mirror path does
not write, in which case the two writers should become one before the column is
added.

---

### 099. The two card cap goes, and so does the read bound that disagreed with it
Aug 2026, Claude

Decision: `generateCards` no longer counts what it has written today and
`/day/:date` no longer limits what it returns. A day carries the cards it has,
unanswered first.

Why: the two numbers were the same number and they were counting different
things. The job counted cards by the day they were written. The read counted
them by the day of the entry they came from, which decision 085 is the reason
for. A card made after midnight for an entry written at half past eleven
belongs to yesterday, and if yesterday already showed two, that card was
written, stored, and never seen by anybody. Nothing in the product could reach
it. Taking one bound away would have left the other one, so both went.

Beyond the disagreement, a cap is a cap on the wrong thing. The claim the
feature makes is that a card exists only where something is open and somebody
could say something back about it. Zero is the common answer and three is a
real week. A number in front of that decides how many things a student is
allowed to have going on, which nothing in this code is in a position to know.

What it costs, and it is a real cost: the count was read before the gateway
call, so a student who wrote five times in an evening spent one model call and
was turned away at the door four times. Now they spend five. This is the
slowest call in the queue per decision 093 and nobody is waiting for it, so the
cost is spend and queue time rather than a student watching a spinner. It is
worth a second look once more than a handful of students are writing.

Reverses if: the spend is what hurts. The answer then is one sweep per student
per night rather than a number, because a cap put back on the job brings the
card nobody can see back with it.

---

### 100. The bar is four questions in the prompt, and nothing counts cards anywhere
Aug 2026, Claude

Decision: what a card has to clear is written in `cue_cards.v1.md` as four
questions. They named it. It has not resolved. It is still ahead of them. A
person could say something back about it. A thing that fails any one of the
four is not a card. `cueCardsResult` has no length limit on the list.

Why: the cap was doing two jobs and only one of them was real. It held the
number down, and it stood in for a bar that was never written. Taking it out
without writing the bar would have turned a quiet feature into a chatty one,
so the gate moved into the prompt and the voice was left alone. The fourth
question is the new one and it is the one that does the work: a thing can be
named, open and ahead of them and still be nothing anybody could say a useful
sentence about, and that is most of what a student writes.

No number in the schema, because a length there would be the old cap living on
in the one file nobody would think to look in, and it would refuse the third
card of a genuinely full week rather than the thin one. The schema checks what
a card is. Whether there should be one is the prompt's question.

Checked against the demo student's ten days: with nothing on the already asked
list the model wrote one card, not two. A student whose six entries were a walk
home, a test already marked, a falling out with somebody who has moved away and
some toast at eleven at night got none.

Reverses if: a real week produces a screen that reads as a list of demands, at
which point the thing to change is the fourth question rather than to put a
number back.

---

### 101. The already asked guard compares the words that carry the thing
Aug 2026, Claude

Decision: `sameThing` in `services/cards/generate.ts` replaces the exact string
match. Both cards are lowercased, stripped of punctuation, folded from plurals
onto singulars, and emptied of the words a student wraps around a noun. What is
left is compared as a set: they are one thing when the shared words are three
fifths or more of the shorter card. One word in common counts only when it is
the whole of the shorter card.

Why: the old guard compared strings, so a card reworded by a single word was a
second card about a thing the student had already been asked, days later, as if
nobody had been listening. The model is told the same rule in stronger words
and is the first thing that should catch this. This is the backstop, and a
backstop that only catches a character for character repeat catches nothing.

The threshold is set where it is because of the two cases that pull against
each other. The coursework due Friday and the coursework due on Friday have to
be one card. The exam on Tuesday and the exam on Friday have to be two, and the
day is exactly what the prompt makes a card name, so the words that pin a thing
down are the words that have to be able to separate two of them. Two words of
three is the same thing. One word of two is not.

It leans towards refusing on purpose. The cost of refusing wrongly is no card,
which this feature already treats as an acceptable answer. The cost of letting
one through is a student asked the same question twice.

A word list rather than a library, and a set overlap rather than a distance,
because no dependency was going to be added for this and a second model call to
ask whether two short phrases mean the same thing would cost more than the card
is worth. It will miss a rewording with no words in common. The prompt is what
catches those, and it did on every run.

`sameThing` is exported, which nothing in the product calls. It is the one
piece of this file that can be checked without a model, and leaving it private
would mean the only way to ask whether it is right is to spend a minute and a
gateway call.

Reverses if: a real student is refused a card they should have had. The list of
empty words is the first thing to look at, then the threshold.

---

### 130. A card asks one question, and a no is an answer rather than a gap
Aug 2026, Claude

Decision: `POST /cards/:id/answer` takes `{ answer: "yes" | "no", detail?,
horizonDays? }`. A yes writes the decision and books the check back exactly as
the three option version did. A no writes the answer and the box and books
nothing, and the route returns two hundred with `decisionId: null`.

`chosen_text` on a yes is the card's question word for word. Turning it into a
statement would read better on home, and it would be a sentence the student
never saw. They said yes to those words, so those are the words the check back
asks them about days later.

`offered_text` is left empty on a decision made from a card. It exists for the
gap between what was put in front of a student and what they did instead, and
it used to hold all three options because a student who wrote their own had
turned three specific things down. There is no gap in a yes: the offer and the
answer are one sentence, and writing it into both columns would claim a
difference that is not there.

The box is stored on the card and nowhere else. A yes with something in the box
still writes the question as the decision, so what the check back asks is the
thing they agreed to rather than the aside they added to it. An empty box is
stored as nothing, because an empty string is not something a student said.

`horizonDays` is optional and defaults to three, the same as the Mirror path,
and it is ignored on a no. A client that has nothing to say about when should
not have to invent a day, and a no has no day to name.

Why a no books nothing: the check back exists to ask how a thing went. Nothing
went. Booking one anyway would ask a student in three days about something they
already told us they were not going to do, which is the app not listening, and
it would put a question on home that has no honest answer.

Gone with the three options: the `no_such_option` result. A four hundred on this
route now only ever comes from the boundary, which is where the shape of a body
is decided everywhere else in this codebase.

Every status proved with curl: yes two hundred with a decision id, no two
hundred with null, four oh four on another student's card and on an id that is
not a uuid, four oh nine on a second answer to either kind, four hundred on an
answer that is not yes or no, on a missing answer, on a horizon outside one to
thirty, on a box over five hundred characters, on a body that is not json, and
on the old `optionIndex` shape. Counted either side of a no: no decision, no
job, card answered.

Ten answers fired at once still come back two hundred and the API keeps
serving, and two taps on one card give one decision and one four oh nine. The
decision and the job are still written on the transaction's own connection, for
the reason the comment in `answer.ts` gives.

Reverses if: students say no to almost everything, which would mean the
question being asked is the wrong question. The fix then is in `cue_cards.v1.md`
rather than here, because a no that books a check back is worse than a bad
question.

---

### 131. The answer is written down, never worked out from the decision
Aug 2026, Claude

Decision: a yes writes `cue_cards.answered_yes` true and a no writes it false.
Nothing infers the answer from whether a decision exists.

Why: a no is a card with an answer, a time, sometimes a sentence, and no
decision, so the answer could be read off the missing decision instead. It
would be right today and wrong the first day a yes fails to write one, and on
that day every one of those rows quietly becomes a no. What a student said is
not something to derive from the behaviour of another table.

`chosen_index` and `options` are left alone. Nothing writes to either now. They
hold what the cards written before this were actually asking, and blanking them
would rewrite that into three empty offers nobody ever made.

The column arrived while this was being written, from the work changing the
schema alongside it. The first version of this path put the answer on
`chosen_index` as one and nought, because two of us generating migrations at
once is a broken chain for everybody. That is gone and no row was ever written
that way outside a proof.

Reverses if: nothing. A column that says what happened is the floor.

---

### 140. The card is one question, and the box under it is never required
Aug 2026, Claude

Decision: `CueCardTile` asks the card's question with Yes and No side by side,
the same size as each other, and one filled button under them that sends. The
button reads `Answer it` and `Answering` while it goes, and it is dim until one
of the two is picked. The box takes anything the student wants to say, is
labelled `anything you want to say, or nothing`, and is never part of whether
the button is live. The four day chips appear only under a Yes. An answered
card says `you said`, then Yes or No, then their own words in a Quote if there
were any, then the day it comes back on if there is one.

Why the box is optional now: with three written options it was the only way to
say something the card had not thought of, so an answer needed either a pick or
words. A yes or a no is a complete answer on its own, and a box that holds the
button hostage would make a student write something to get past a question they
had already answered.

Why a tap does not unpick: the three options toggled off, because getting from
an option back to your own words was a thing a student needed to do. There is
nowhere to go back to now. The only thing an unpick could do here is lose an
answer somebody had already given, so the second tap on Yes leaves it on Yes.

Why the day is under the Yes only: a no books nothing, and asking which day to
come back on after a no would be the card refusing to hear it.

`CueCardAnswer` carries `yes`, the box and a nullable `horizonDays`, null on a
no because nothing was booked. The one call site in `day_screen.dart` changed
with it, from `optionIndex: answer.optionIndex` to `yes: answer.yes`, and its
comment says what a no does now. That file was outside this task and the build
does not compile without it.

`Answer it` rather than `Hold it` because the button now sends a no as often as
a yes, and nothing is held on a no. It is the same shape as the rest of the
buttons in the app, a short thing to do with an it on the end.

Reverses if: students pick Yes to be agreeable. The signal would be a run of
yes answers whose check backs all come back as nothing happened, and the fix is
the question in `cue_cards.v1.md`, not a third button here.

---

### 141. The returning tab says which patterns are worth keeping and which are worth stopping
Aug 2026, Claude

Decision: the Returning tab is two named groups and what is still forming.
`Worth keeping` sits over the good group with a moss dot, a moss tinted card
and a moss outline. `Worth stopping` sits over the other one in clay. Under
each theme is the sentence the server wrote, then one muted line of facts. The
page keeps `So far` and `from N reflections`, forming keeps `Still forming` and
`not enough to say yet` in the quiet colour with no outline, and the screen
with nothing in it still says `Nothing has repeated yet` and stops.

This reverses the second 096 and 097. Those said the sections were a record and
not a result and that the colours were not a verdict. They are a verdict now,
by founder decision, three times over.

Why these two headings: they are the shortest true thing. `Worth keeping` does
not say well done and `Worth stopping` does not say you keep getting this
wrong. Both are four syllables of the same grammar, so neither is the prize and
neither is the telling off, and the sentence under each theme is where the
actual encouragement and the actual cost live, in that student's own situation.

The two groups carry the same amount of language, the same type sizes and the
same construction: one tint at seven percent, one outline at forty five, one
dot. The only difference between them is hue. A section that got more words or
a heavier frame than the other would be the app leaning.

Clay for the costly group rather than red or violet. Red is not in this palette
and a traffic light is a grade. Clay is the colour of every primary button in
the app, so it reads as the app talking rather than as an alarm. Violet was the
old heavier colour and it was chosen precisely because it carried no weight,
which is the wrong choice now that the group is a claim.

The proportion bars are gone. They were the right idea when every row was a
count of something the student had said, and a long clay bar beside a theme the
app has just called costly is a score. Nothing on this screen is a total or a
ranking, and the count survives in words, where it reads as one fact among
three rather than as a measurement.

Rows are separated by a hairline in the group's own colour, because each row is
three lines deep now and without it two themes read as one paragraph.

A row whose sentence did not arrive is not shown at all, in either group. The
sentence is the whole of what the app is saying: a theme sitting under Worth
stopping with a blank under it would be the verdict without the reason, which
is the one thing this screen is not allowed to be.


Reverses if: a student reads the second group as being told off. The fix is the
sentence the server writes, then the heading, and the colour last.

---

### 142. Every judged row says who decided, and an unknown source falls to the model
Aug 2026, Claude

Decision: the muted line under each sentence is three clauses, how many times,
when the last one was, and where the verdict came from. `from how you said it
went` for a theme the student's own outcomes settled, `from what you have
written` for one the model read. Anything in `source` that is not exactly
`outcomes` is taken as the model.

Why the third clause: the app is asserting something about a student now, and
their own recorded outcomes beating ours is the rule this whole feature rests
on. A student is owed the difference between their verdict handed back to them
and our reading of their entries, and one short clause is the cheapest place to
put it. It stays inside the same muted line rather than becoming a fourth
element in the row, because the sentence is what they are meant to read.

Why the fallback goes to the model: the two are not symmetric. Claiming the
student's own voice for a string we did not recognise would put words in their
mouth. Claiming ours for one costs nothing but a shade of credit.

Whole days for when, unchanged from 098, and a timestamp that will not parse
drops that clause and leaves the other two.

Reverses if: the server starts writing the whole line, which it should, since
it already knows the student's timezone and this is the second screen guessing
with the device one.

---

### 160. The card schema checks the shape of a yes or no question, and only the shape
Aug 2026, Claude

Decision: `services/cards/schema.ts` drops `options` and puts five checks on
`question`. It has to end in a question mark, it can hold only one question
mark, it cannot open with what, how, why, which, who, when or where, it cannot
contain the word or, and it cannot carry a second comma.

Why: the card now has a yes button and a no button, so a question the student
cannot answer with either word is a card with nowhere to tap. What was asked
for was the wh openers and the list. Who, when and where went in with the other
four because they fail in exactly the same way: they ask for a fact back rather
than for a yes. The question mark checks are what stop a statement or two
questions being stored as one card.

The word or is the list check that does the work. A list does not have to end
in commas to be a list, and "will you tell Priya or start the poster" is three
answers behind two buttons. One comma is left alone, because a question can put
the day in a clause and still be one question. The second comma is what says
the clause has become a list.

What is not checked here is whether no is a real answer, which is the half that
decides whether the card should exist at all. That test is a sentence about the
student and it lives in the prompt, where it can be read as one. No regular
expression can tell "will you tell your mum before Tuesday" from "will you
finally start the coursework", and a check here that pretended to would refuse
good cards and pass the bad one.

A failing card still fails the whole reply, because the gateway validates the
answer as one thing and falls through to the next provider. That was already
true of the three option rule and no card remains an acceptable answer, so this
leans the same way it always did.

Reverses if: real runs show good cards refused by the or check, in which case
the thing to narrow is the or, not the openers.

---

### 161. The options column stays, empty, on every card written from now on
Aug 2026, Claude

Decision: `options` loses its not null constraint and nothing writes to it.
`chosen_index` stays for the same reason and is written by nothing. A new
`answered_yes` boolean holds the answer and `detail` keeps holding whatever the
student wrote in the box. Migration 0008.

Why: twenty two rows in this database were written when a card offered three
things, and those rows are the record of what a student was actually asked.
Dropping the columns would rewrite that history into three blanks, and a card
from July whose student picked option two would become a card nobody can
explain. Keeping a column nobody writes to costs a line in the schema comment.

`answered_yes` rather than reading the answer back off `decision_id`. A yes
writes a decision and a no writes nothing, so the decision would be a proxy for
the answer, and a proxy is wrong the first time a decision write fails or a
decision is deleted. The answer the student gave is a fact about them and it is
stored as one.

Nullable rather than not null with a default, because a card that has not been
answered has no answer, and false is an answer. Unanswered, yes and no are
three states and the column holds three.

Reverses if: the old rows are ever migrated or expired, at which point both
columns can go in one migration with nothing lost.

---

### 180. The patterns screen judges, and it says whose judgement it is
Aug 2026, Adnan, built by Claude

Decision: `GET /patterns` returns `reflections`, `good`, `bad` and `forming`.
`lighter`, `heavier` and `confirmed` are gone from the payload. A row in `good`
or `bad` carries the theme, how many times it has come round, when the last one
was, one sentence the student reads, and `source`, which is `outcomes` when the
student's own check back answers decided it and `model` when we did. A theme
with neither is in neither section.

Why: the founder decided, three times, that a product which notices a student
is repeating something and refuses to say whether it is helping them is not
worth having. Decisions 096 and 097 built the opposite: two sections deliberately
shaped so that neither could be read as a result, with a note in 096 saying
nothing downstream may turn the heavier list into a warning. That is overruled.
The heavier list is now the bad section, it does say so maybe stop, and it says
it in a sentence rather than by implication.

`confirmed` goes because a confirmed pattern is a theme like any other and now
appears in whichever section its verdict puts it in, with a line under it. The
rows are untouched and the confirm and reject endpoints are untouched. Nothing
is proposed as a pattern without the student, and this only decides what to say
about a theme that already keeps returning.

`forming` drops any candidate whose theme is in a section. A theme cannot be
under not enough to say yet on the same screen as a sentence telling the student
to stop it, and of the two the sentence is the one the app now stands behind.
The candidate row survives and is still confirmed or rejected wherever
candidates are surfaced.

Rejected: keeping `lighter` and `heavier` beside `good` and `bad`. Two pairs of
sections drawn from the same outcomes, one hedged and one not, is the old
behaviour surviving under a new name, and a screen that says both would be
saying neither.

Reverses if: task 7 shows a student reading the bad section as being told off.
The fix is then the line, which is where the whole feature lives, and not the
section.

---

### 181. The verdict comes from the student first and from the model second
Aug 2026, Claude

Decision: the verdict on a theme is `outcomes.felt` where the student has
answered a check back about it, and a model call where they have not. A theme
they answered lighter is good, worse is bad, and where they answered both ways
it is whichever they said more often, with the more recent one winning a tie.
The model is told the verdict when the student has set one and writes only the
sentence, so it cannot return a verdict that contradicts them. `source` on the
wire says which of the two it was.

Why: their reading of their own life beats ours and the wire has to say so, or
the student cannot tell the difference between being quoted and being judged.
Telling the model the answer rather than asking it and then discarding the
reply is what makes the guarantee structural: there is no path where a good
line ends up under a bad heading because the two disagreed.

The tie break supersedes decision 097, which let a theme sit in both lists on
the grounds that picking a winner would mean deciding which of two things the
student said is the truer one. That was right for a record and is impossible
for a verdict: keep this and stop this cannot both be printed under one theme.
Count first because it is the most of what they said, recency second because
it is the latest of what they said.

Reverses if: outcomes gain a second signal the student sets themselves, at which
point the verdict is over both and not over `felt` alone.

---

### 182. Verdicts are appended, and a stale one is held back rather than shown
Aug 2026, Claude

Decision: `pattern_verdicts` holds one row per judgement, never updated, with
the verdict, the source, the line, how many entries were behind the theme at the
time, and the prompt and model versions. The newest row for a theme is the live
one. The read compares that row's verdict against what the student's outcomes
say now, and where they disagree the theme is shown in neither section until the
next verdict run writes a new row.

Why: a line is written for one verdict. If the student answers a check back
tomorrow and turns a bad theme good, the stored sentence says the opposite of
the heading it would sit under, and putting worth stopping over a sentence about
what something does for them is the one failure on this screen that would be
unforgivable. Holding it back costs a day. Showing it costs trust.

The versions are on the row and not only on the `generations` row for the same
reason the cue card carries them: the line outlives the day it was written and
the first question about a bad one is which prompt wrote it. Appending rather
than updating keeps the one before it, which is how a verdict that turned over
gets read back later.

`supporting` is what says a line is out of date. A theme that has grown since it
was judged is judged again, because the sentence was written without the entries
that arrived after it.

Reverses if: holding a theme back for a day reads as the app losing track of
something the student just told it, at which point the answer is to run the
verdict job when an outcome is recorded rather than to print the stale line.

---

### 183. The verdict job runs on the back of the nightly sweep, one theme at a time
Aug 2026, Claude

Decision: a `pattern_verdicts` job, booked by the runner at the end of every
`pattern_sweep` and run by the same runner. It reads every student's themes in
one query, judges up to two hundred of them, one model call at a time, and
writes a row for each. Themes with no verdict at all go first. A theme needs two
entries above `MIN_TAG_CONFIDENCE`, not the three on three days the sweep needs
before it proposes a pattern.

Why: the sweep already runs nightly, already reschedules itself, and has just
finished reading the tags the verdicts are about, so booking off the back of it
means the only thing that has to be running is the runner. Nothing else changed
about scheduling and no cron entry was added.

Two rather than three because these are different claims. Three entries on three
days is the bar for proposing a pattern to a student and asking them to own it.
This is a sentence under a theme that is already on their screen, and below two
there is nothing repeating to have a verdict about.

One at a time and capped at two hundred because every theme is a model call on
the slowest configuration we have and it runs unattended in the night. A tagger
change that renamed every theme at once would otherwise be one call for every
theme in the database, all at the same moment. What does not fit waits for
tomorrow.

Rejected: running it when an outcome is recorded. That is the right trigger and
it belongs in the outcome path, which is another agent's file this week. The
nightly run covers it within a day and decision 182 covers the gap.

Reverses if: a student's verdicts are a day behind often enough to notice, at
which point the outcome path books this job for that one student.

---

### 184. What `times` counts now, and why it changed
Aug 2026, Claude

Decision: `times` on a `good` or `bad` row is the number of entries behind the
theme, and `lastAt` is the most recent of them. It used to be the number of
outcomes behind the row.

Why: the two sections used to be filled only from outcomes, so counting outcomes
was the only thing they could count. They are now filled from two sources, and a
number that meant answered check backs on one row and nothing comparable on the
row under it is a screen that lies quietly. Entries behind the theme means the
same thing whichever decided the verdict, and it is what a student reads the
word times as: how many times this has come round.

Reverses if: the screen ever shows both numbers, in which case they need two
words and not one.

---

### 185. Storage for the verdict was added to the shared schema, deliberately
Aug 2026, Claude

Decision: `pattern_verdicts`, the `theme_verdict` and `verdict_source` enums,
the `pattern_verdict` value on `generation_purpose`, migrations
`0009_lucky_stardust` and `0010_quiet_shooting_star`, and two names appended to
the arrays in `db/sql/rls.sql`.
None of these files were in the list this task was scoped to.

Why: the feature stores a verdict with its prompt version and model version, and
there was no table to put it in. Every change here is an addition. Nothing
existing was edited except the two array literals in the row level security file
and the one enum in the schema, so a concurrent change elsewhere in those files
survives it. The migration was renumbered from 0008 to 0009 mid task because
another agent claimed 0008 while this was being written.

`pattern_verdicts` is in the student scope policy list, so the read runs under
row level security as every other read does.

Reverses if: nothing. It is the storage the feature needs. It is logged because
it went outside the file list it was given and that should be visible rather
than discovered.

---

### 186. Unsettled is written down, and it is the answer that stops us asking again
Aug 2026, Claude

Decision: the verdict prompt may return `unsettled`, and `theme_verdict` carries
it as a third value. An unsettled row is stored with an empty line and is never
shown in either section. The theme is only asked about again when it gains an
entry or when the student answers a check back about it.

Why: the first version returned unsettled and wrote nothing, which meant the
theme came back to the front of the queue every night until some run happened to
say something. That is a model call per student per unsettled theme per night
for as long as the theme exists, and it is worse than the cost: a refusal that
is retried until it stops being a refusal is not a refusal. The demo student's
`too much at once` was unsettled on one run and bad on the next, from the same
two entries at temperature zero, which is exactly the failure. Writing the
answer down makes it stick until something changes that could actually change
it.

An empty line rather than a nullable column, because the line is not optional
for anything that is shown, and a null there would invite a reader to wonder
whether a good row could have one too.

The read refuses unsettled twice: the row cannot head a section, and it cannot
be the sentence under a theme whose outcomes have since given it a verdict. The
second is the same hold back as decision 182 and for the same reason.

Reverses if: unsettled turns out to be most themes, in which case the bar in
the prompt is too high and the prompt is what to change.

---

### 187. The public site lives in `www`, and every screenshot on it is a real one
Aug 2026, Adnan, built by Claude

Decision: the site at soulspacehealth.com is a folder in this repository called
`www`, next to `app`, `api` and `db`. One file, `index.html`, with its styles
and its script inline and no build step. `screens` holds photographs of the
running app and `brand` holds the favicon, the share card and Apple's badge.

Why `www` and not `site` or `landing`: every other top level folder here is
named for what it is, and `app` is already taken by the Flutter client. A
folder called `site` sitting next to a folder called `app` invites somebody to
guess wrong about which one a phone runs. `www` is the web root and cannot be
read as anything else.

Why the screenshots are photographs of the running app rather than drawings of
it: an earlier version of this page rebuilt the Returning screen by hand in
HTML, which meant the marketing and the product could drift apart silently and
the page could show a screen that has never existed. They are now captured off
a booted simulator running this repository against a seeded database, and the
sentences under the themes came from the pattern verdict job rather than from
somebody writing what it might say. The file names match the tabs they were
taken from so the next person knows what to retake.

Why no framework and no build step: the page is one document. A bundler would
add a dependency, a lockfile and a build to a thing that a browser already
opens, and this repository has a standing rule about both.

The verdict sweep was run once against the local database to produce the
screenshots, because the demo student had no verdicts and the page would
otherwise have shown a Returning tab with nothing in either section. That wrote
four rows to `pattern_verdicts` for `student_demo` and touched nothing else.

Two things on that page are Apple's rather than ours. Both badges in `brand` are
their artwork, unmodified. Their guidelines forbid recolouring it, so the theme
picks between the black lockup and the white one rather than tinting either.

An earlier version of this page carried only the black lockup and sat it on a
light plate on the dark theme, because the asset path under developer.apple.com
serves only that one. It read as a patch and the founder said so. Both lockups
come from Apple's Marketing Tools API instead, which serves either colour with
no sign in:

    toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/black/en-us
    toolbox.marketingtools.apple.com/api/v2/badges/download-on-the-app-store/white/en-us

Reverses if: the site grows past one page, at which point it needs routing and a
real static generator, and `www` becomes a project rather than a folder.

---

### 188. Three write paths took an id from the request without the student
Aug 2026, found and fixed by Claude

Decision: `generate/mirror.ts`, `services/patterns/answer.ts` and
`services/decisions/recordOutcome.ts` now scope every read and every write by
`session.studentId` as well as by the id. `recordIgnored`, which nothing calls
yet, takes a session so that whatever calls it later has to resolve a student
first. A new test, `api/src/tenancy.test.ts`, holds all of it.

Why it was wrong: decision 072 put the read side inside `asStudent`, where row
level security scopes the query and a missing where clause cannot leak. The
write side was never moved. It runs on the pooled handle as the owning role,
where the policies do not apply, so on those three paths the where clause was
the only guard and it was not there.

What that allowed. Any signed in student could post another student's entry id
to `/entries/:id/mirror` and have that entry read back to them through the
model. They could answer somebody else's pattern candidate, which copied that
student's theme and supporting entry ids into their own `confirmed_patterns`.
They could close somebody else's decision, which ends a check back that student
was waiting on and changes what their patterns screen later says.

The test is the part worth keeping. Removing the scoping from the Mirror and
running it again does not produce a tidy failure: the request reaches the model
gateway carrying the other student's entry text, and only stops because the
test environment has no provider keys. That is what the hole actually was.

Not found rather than forbidden, on all three. Forbidden confirms to somebody
guessing that the id they guessed is real, which is the same reasoning
decision 130 used for cue cards.

What this does not do: the write path still runs outside `asStudent`. Scoping
three queries fixes the three that were wrong. Moving writes inside the student
role would make the whole class impossible rather than these three instances,
and it is the better fix. It is also a change to every write in the service and
it is not this change.

Reverses if: nothing.

---

### 189. The roster identifier is no longer a bearer token by default
Aug 2026, found and fixed by Claude

Decision: `resolveSession` accepts a roster identifier only when
`SOUL_ROSTER_TOKENS` is exactly the word `allow`. Anything else, including the
variable being absent, refuses. The flag is in `.env.example` and is set in
local development.

Why: a rostering identifier is minted by a district and shared with their own
systems. It is an identifier, not a credential, and it was accepted as a bearer
token in every environment including production. Anybody holding a roster list
held a working key to every student on it.

Why a flag that has to be turned on rather than a check for production: an
environment that has not thought about this refuses. `NODE_ENV` is not set by
`tsx`, so keying off it would have meant the insecure path was the default
everywhere it was not explicitly overridden, which is the failure this is meant
to remove. Same reasoning as decision 031, where a classifier that cannot
answer is treated as high risk rather than as a pass.

Reverses if: sign in becomes the only path into the product, at which point the
flag and the roster branch both go.

---

### 190. The old website's people are kept, and the product cannot read them
Aug 2026, Adnan, built by Claude

Decision: two tables, `legacy_feedback` and `legacy_users`, holding 135 survey
answers and 50 accounts exported from the previous Soul Space website. Forced
row level security with no policy and no grant for `soul_student`, so no request
path can reach either one.

Why keep them at all: they answered questions about this product, the ratings
are the only outside opinion of it that exists, and some of them may recognise
the name later. Deleting that to keep the schema tidy would be throwing away the
only evidence we have that is not our own.

Why they are quarantined: they are not students. They have no district, no
school, and no consent recorded in this system. Every other table here is scoped
to a student because a student agreed to be here. These people did not, so the
safe shape is a table the product cannot see, that a human queries deliberately.
Revoking the grants as well as leaving the policy list empty means the denial
does not quietly depend on nobody adding a policy later.

Why `raw` alongside parsed columns: the parsed columns are a guess at what
matters. The raw record is what actually arrived. A guess that turns out wrong
should cost a query and not a reimport.

Why the files are not committed: they hold names, email addresses and phone
numbers. The import script takes paths and is idempotent by source, so the data
lives in the database and the files stay wherever they were downloaded.

What is still open: nobody has decided how long these are kept or what happens
if one of these people asks to be removed. There is no retention rule on either
table and there should be one before anything is ever sent to these addresses.

Reverses if: a lawyer says holding them without a basis is not defensible, in
which case they go, and the ratings can be kept as counts without the people.

---

### 191. The queue can be drained over HTTP, so the worker is not tied to a machine that stays up
Aug 2026, Adnan asked where this actually runs, built by Claude

Decision: `POST /jobs/drain` runs the same `tick()` the worker loop runs, up to
twenty five jobs, stopping early when the queue is empty. It carries a shared
secret in `SOUL_JOBS_SECRET` rather than a session, and it is the only route
excluded from the student middleware. With no secret set it answers 503 to
everybody. A root `Dockerfile` builds the service for any container host.

Why: the API and the job runner only existed on a laptop. That is fine for
development and it is not a deployment. When the machine sleeps the queue stops,
and the queue is where the product's slow mechanics live: a check back fires on
the day a student named it, the sweep books its own next night, and tags feed
every pattern downstream. None of it recovers on its own, and none of it is
visible when it fails.

Why an endpoint rather than only the loop: `loop()` is right on a host that
stays up and wrong on one that sleeps or bills by the hour. `tick()` was already
exported separately, so both shapes are the same code and neither is a fork.
Supabase can drive it: `pg_cron` and `pg_net` are available on the project and
`pg_cron` runs to the minute, which matters because most free platform crons run
once a day and a queue drained daily makes a student wait a day for their tags.

Why it fails closed: it is a machine to machine route with no student behind it.
Unset meaning open would have made every deployment that had not yet thought
about scheduling into an open job runner. Same reasoning as decisions 031 and
189.

Why the secret is compared in constant time: it is three lines and the
alternative leaks length and prefix information to anybody willing to measure.

What this does not settle: where the API runs. Supabase holds the data and can
hold the clock, but its only compute is Edge Functions, which are Deno, and this
is a Node service with npm workspaces and Node imports whose longest model calls
allow a hundred and twenty seconds. Porting the safety path to a different
runtime for hosting convenience is the wrong trade. A host still has to be
chosen, and the Dockerfile is deliberately neutral about which.

Also moved `tsx` from devDependencies to dependencies. It is how the service
starts in every environment, so `npm ci --omit=dev` in the image was about to
remove the thing that runs it.

Reverses if: the service is compiled to JavaScript ahead of time, at which point
`tsx` leaves the runtime and the image runs `node` directly.

---

### 192. The service stays on a laptop until the app is published, then it goes to Render
Aug 2026, Adnan

Decision: the database is on Supabase. The API and the job runner keep running
locally until the app is actually published, at which point both move to Render,
a web service for the API and a background worker for the queue.

Why not now: nothing can ship. There is no Apple developer team, task 7 has not
been done, and whether an account is created by a district or by a person
downloading it is undecided. There is no user to be offline for, so hosting
would be paying to keep an empty service warm.

Why Render rather than AWS. Fargate needs a load balancer, which is about
sixteen dollars a month before a container starts, at zero traffic, and the
hundred dollars of credit on the account expires. App Runner is the cheaper AWS
shape but it enforces a hard hundred and twenty second request timeout that
covers reading the request through writing the response, and `mirror` is
configured at exactly a hundred and twenty seconds, so a slow Mirror would have
the connection cut at the same instant our own timeout fires and the student
would get a dead socket instead of a handled error. Going that way means
lowering the Mirror first. Render's background worker runs `loop()` as written,
which is the shape the runner already has.

Not the free tier for the web service when that day comes. Render spins a free
instance down after fifteen minutes and it takes about a minute to wake. Beat
one is built around three seconds.

What this costs in the meantime: the queue only drains while a machine is awake.
A check back booked for a day the laptop is closed fires late rather than on the
day the student named, which is the one part of the product that cannot be
caught up convincingly.

Reverses if: anybody outside the team installs the app, at which point this is
no longer a tradeoff, it is an outage.

---

### 193. ElevenLabs Scribe replaces Deepgram
Sep 2026, Adnan, Claude writing it up

Decision: transcription runs through ElevenLabs Scribe. Deepgram is gone from
the code, the configuration, the policies, and the stack table. The key is
`ELEVENLABS_API_KEY` and nothing else changed shape: same one function, same
consent check before audio leaves, same immediate deletion.

Why: the founder asked for it. Decision 017 was a credit decision and said so,
which is exactly the kind of choice that should be easy to reverse, and 018 was
made so that reversing it is a config change. It was: the provider file, one
line in env.ts, and the two places students are told who hears their voice.

What is different about the call: Scribe wants multipart, one part named file,
rather than a raw body. Audio event tags and speaker labels are turned off so
the transcript holds the student's words and nothing about the room. Deepgram
had a per request opt out from provider training and ElevenLabs does not
expose one on the request. Its terms say API inputs are not used for training,
and zero retention is an account setting rather than a parameter. The district
data agreement has to name ElevenLabs as the sub processor now, and that
setting has to be confirmed on the account before a school is onboarded. That
is a contract task, not a code one, and it is open.

Task 0b still has not been run. It now compares Scribe against Whisper on real
student audio, and the caveat on 017 carries over unchanged: this is a
preference until it is measured.

Rejected: keeping Deepgram behind a second provider value. Two providers is two
sub processors in every data agreement for no benefit.

Reverses if: measured meaning change rate on real student audio favours another
provider, or a district objects to the vendor.

---

### 194. A spoken entry is judged for how it sounded, and that is stored
Sep 2026, Adnan, against the assistant's advice, Claude writing it up

Decision: every spoken entry, the introduction in first run and every entry
from the plus button alike, is heard once by an audio model and described:
an emotion from a fixed list of twelve, an intent from a fixed list of eight,
one sentence about the voice, an intensity and a confidence. Alongside it the
transcriber's word timings are measured into words a minute, long pauses,
hesitations, audio events such as a laugh or a sigh, and the language
detected. All of it is a `voice_tones` row. Beat one, the Mirror and the
tagger are told it. The founder's reason: tone determines intent and emotion,
and the words alone miss both.

The advice against it, recorded so it can be weighed: the voice rules say do
not name their feeling for them, everything the app holds was until now words
the student chose to send, and a description derived from a child's voice is
a new category of data that every district agreement has to name. The founder
heard that and asked for it anyway. This entry is the record that it was a
choice.

What holds it inside the rules that did not move:

The transcript the student confirms is still only their words. Audio events
are stripped out of the text and kept as a list on the tone row.

Nothing from the tone is shown to the student, and the prompts are told to
use it for register and never to say it back. "You sound" is banned in all
three. When the voice and the words disagree, the words win.

The audio still goes nowhere. The same bytes go to two places at once, the
transcriber and the audio model, in the only moment they exist, and the row
that comes back is words and numbers. Both places check consent themselves.

The tone call is allowed to fail. A student who spoke gets their transcript
whether or not anything managed to listen to it, so the call is started in
parallel and its absence costs nothing but a null.

The row exists before the entry does, because the audio is gone before the
student has decided to send. So it is written with a null `entry_id`, linked
in `submit()` scoped to the student and to unlinked rows, deleted through
`DELETE /transcribe/:toneId` on discard, and any orphan is swept the next
time the same student records. An id lifted from another device links
nothing.

The fixed vocabularies are deliberate. A free label cannot be counted across
months, and counting is the only thing that would make this more than a note
on one entry. The one free field describes the recording, not the person, and
the prompt is built the same way the tagger's is: situations, never traits.

ElevenLabs was read first. Scribe has no emotion or tone field; it gives per
word log probabilities, timings and audio event tags, and its own page says
emotion is an audio event, not a score. So the measured half comes from
ElevenLabs and the judged half from an OpenAI audio model, which keeps the
vendor count where it was. OpenRouter is not in the order for that call
because audio input there depends on the model behind it.

Invariant one is read as before: the tone call is a classification, not a
generation, and nothing a student reads is written until `classify()` has
passed on the words. Invariant nine is amended in FLOW.md to say what a
recording leaves behind.

The privacy policy and the in app policy now say the recording is described
for how it sounded and name OpenAI for it. The district data agreement has to
say the same before a school is onboarded, and nothing in this entry does
that.

Rejected: reading tone from the words alone, which the tagger already does
and which the founder said was not enough. Turning the ElevenLabs audio event
tags into the emotion, which would have made a sigh into a verdict. Showing
the tone to the student, which is a separate decision nobody has taken.

Reverses if: the clinical review for under 13 says a voice derived label
should not be held about a child, a district refuses the sub processing, or
task 7 shows the lines got no better for it.

---

### 195. A Render blueprint, so hosting is one click when the account exists
Sep 2026, Claude

Decision: `render.yaml` at the repository root describes the web service and
the worker that decision 192 chose. Every secret is marked to be asked for in
the dashboard, never read from the file.

Why: the founder asked for a first TestFlight build. A device build has to
point at an API that is not a laptop, and the thing standing between the code
and a host was a form. The blueprint fills the form. Nothing in it changes the
Dockerfile, which stays host neutral.

Two things it leaves to a person. The Apple Developer Program membership,
because this Mac has no signing identity and Xcode has no team, and the keys
themselves. The README now has the order, under shipping the first TestFlight
build.

`SOUL_ROSTER_TOKENS` is deliberately absent from the blueprint. A roster
identifier is not a secret, and the flag exists so that an environment which
forgets to think about it refuses. An internal test with no district sign in
sets it by hand and removes it before the app leaves the team.

Reverses if: the host changes, in which case the file goes with it and the
Dockerfile stays.

---

### 196. Anybody can use it. A phone gets an account on first launch, and sign in attaches an identity
Sep 2026, Adnan, Claude writing it up

Decision: the product is for anybody, not only for rostered students. A phone
that has never been seen asks for an account the moment the app opens and is
given one, with a session, before a single question. Sign in with Apple, or a
six digit code sent by email through Resend, attaches an identity to that
account so it can be found again from another phone. The roster reference
path still exists behind its flag for development and is no longer needed
for a device build.

Why: the founder ruled out shipping a build that depends on a development
flag being set on the server and remembered to be removed. The alternative
was a real sign in path that works with no district. Doing that properly
meant answering the question decision 192 left open, whether an account is
made by a district or by a person, and the answer is both.

Why the account comes first rather than sign in. First run writes the
profile, the baseline and the spoken introduction before the screen that
asks anyone to agree to anything, and the order was chosen so that a person
signs in to keep something that already exists. Making the account silently
on first launch keeps that order. What it costs is a row for every phone that
opens the app, including ones that never come back.

Consent. A self made account has none until the person ticks the agreement
on the sign in screen, so the introduction is stored held with nothing sent
out, the same as a rostered student without consent. Recording the agreement
books a job that lets held entries through, classifier first and tagger
after, and writes nothing back. Nothing bypasses the classifier.

The email address is held. It is the first piece of directly identifying
information in the students table and the policy, the terms and this entry
all say so. It is held for one purpose, getting back in, and the only thing
ever sent to it is a code. Resend is a new sub processor for that one
message, over plain fetch, no SDK.

Where self made accounts live: one district and one school both named Self
signup, made on first use, so every row still has a school and a district
and row level security is unchanged.

Rejected: a server flag that accepts roster references and is removed
later, which is what the founder objected to. Making the introduction wait
for sign in, which reverses the order first run was designed around.

Reverses if: districts require that only rostered students can hold
accounts, in which case self signup is switched off for their region rather
than removed.

---

### 197. Student becomes user in the app, and the database keeps its names for now
Sep 2026, Adnan

Decision: every identifier and comment in the Flutter app says user rather
than student, and the API's one refusal message says unknown user. The
database tables, columns and role names still say student.

Why: the product is for anybody, per decision 196, and the client is what
people read and what the team edits daily. Renaming the schema on the live
Supabase project touches every table, the row level security functions and
every query in the API, and it is a migration that deserves to be its own
change with its own test run rather than a side effect of a copy edit.

Reverses if: never for the app. The schema rename is a separate decision
still to be taken.

---

### 198. The Xcode project is named Soul, and the source folder keeps the name Flutter writes to
Sep 2026, Adnan

Decision: the project, workspace, target, test target, scheme, entitlements
and bridging header are all named Soul. The one thing still called Runner is
the folder on disk under `ios`, and in Xcode it is shown as Soul.

Why: the founder wants nothing a person can see called Runner. Flutter's
tooling in this version finds the project and the workspace by extension and
accepts any scheme name as a flavor, so those could go. It still writes
`GeneratedPluginRegistrant` into `ios/Runner` on every build and reads
`Info.plist` from there, so that folder name is load bearing and the group is
renamed instead of the directory.

What it costs: every Flutter command that touches iOS needs `--flavor soul`,
because that is how Flutter is told which scheme to use. `app/release.sh`
and the README carry it. Flutter prints a notice that no Release-Soul build
configuration exists, which is only a notice: the plain Release
configuration is used.

Reverses if: Flutter stops hard coding the folder, at which point the
directory is renamed too.

---

### 199. A release build points at Render by default, so an archive from the Xcode window works
Sep 2026, Adnan

Decision: without a SOUL_API define, a debug build talks to the laptop and a
release build talks to the API on Render. The define still overrides both.
The app also declares that it uses no non exempt encryption, so App Store
Connect stops asking the export compliance question on every build.

Why: the founder ships from the Xcode window, Product then Archive, and Xcode
passes no Dart defines. The old default of localhost for every build was a
guard against a release pointing somewhere by accident, and it now had the
opposite effect: an archive from Xcode pointed at nothing. Now that there is
one real host, the release default is that host.

Reverses if: there is more than one environment worth pointing a release at,
in which case the define comes back as the only way and the guard with it.

---

### 200. The agreement comes before the first word, and the app reports what it did
Sep 2026, Adnan and Claude

Decision: the terms and privacy agreement is the second screen of first run,
before the profile, the baseline and the spoken introduction. The sign in
screen at the end only signs in. The app posts small events to the service
about what it did, and the service logs how every recording and every entry
ended.

Why: the first TestFlight build failed on the very first recording. The
introduction was spoken before anybody had agreed to anything, an account a
person makes for themselves has no consent until they agree, and the server
correctly refused to let the audio leave. The gate worked. The order of the
screens was wrong, and the app said nothing more useful than that it did not
go through.

Why events and not an SDK: the client rule in CLAUDE.md, no analytics or
crash reporting SDKs, is a COPPA rule, and it stands. Apple's kids category
guidance says such apps may not send device information to third parties,
and the FTC has said an SDK's collection is the app's collection. Sentry's
mobile SDK avoids advertising identifiers but is still a third party with a
name in every data agreement. A first party events table gives the same
answer to the question that matters, what happened on this phone, with no
new sub processor. Events carry names and numbers, never words.

The failure copy in the capture screen now says which thing failed, by
status: not agreed, not signed in, nothing heard, the service, or no
connection.

Reverses if: the service grows to where a hosted error tracker on the server
side earns its place. That would be a server dependency, not a client one,
and a separate decision.

---

### 201. Using the app is the agreement
Sep 2026, Adnan

Decision: an account a person makes for themselves is recorded as agreed the
moment it is created. There is no agreement screen in first run and no check
on launch. The terms and the privacy policy stay linked from the sign in
screen and the website, and the gate in the code stays as it is, always
passing for these accounts.

Why: the founder's call. The product is for anybody, not for children, and a
functional app comes first. Decision 200 moved the checkbox earlier; this
removes it. Accounts made before this were marked agreed in the same change.

Reverses if: a district rosters students, whose consent is recorded by the
district as before and is untouched by this.

---

### 202. Sentry, in the app and in the service
Sep 2026, Adnan

Decision: Sentry reports crashes and errors from the app and from the API
and the worker, into one organisation. It is on only when a DSN is set, in
the app at build time and in the service through the environment. The
events the app already posts become breadcrumbs, so a crash carries the
trail of what the app did before it, and any event ending in failed is
raised as a warning.

Why: the founder asked for one tool that shows every failure, and Sentry
has first class SDKs for both Flutter and Node so the phone and the server
land in the same place. The free plan covers a TestFlight app many times
over. Crashlytics would have brought Firebase with it, and the rest are no
better for this stack.

What it does not carry: no personal data by default, and the only
identifier attached is our own account id.

Reverses if: the free plan is outgrown and the paid one is not worth it, in
which case the events table and the logs remain and the SDKs come out.

---

### 203. Words appear while the person is speaking, in the same box they would type in
Sep 2026, Adnan

Decision: the mic streams audio straight from the phone to ElevenLabs over a
live connection, and the words come back into the typing box as they are
said. There is no separate transcript screen and no confirm step. Send is
the same button either way. The waves are the loudness of the microphone,
not an animation. How it sounded is judged once from the audio the phone
held in memory, after stop, in the background.

Why: the founder's call, on seeing the first build. A screen that records,
goes quiet, and then shows a page of text felt broken, and the batch
transcriber returned nothing for clips of two seconds. Live words are what a
voice recorder does, the person can fix a wrong word by hand, and there is
nothing to confirm because they watched it arrive.

How the key stays off the phone: the service mints a single use token, good
for one connection and fifteen minutes. The audio does not pass through the
service on the live path. It is sent once afterwards for the tone judgement
and dropped, the same promise as before.

What changed in the rules: decision 019 said no edit step. The box is
editable, because it is the typing box. Invariants ten and eleven, that a
transcript is seen before it is sent and never lands in the typing field,
are replaced by this: the words land in the typing field as they are said,
which is a stronger form of seen.

Reverses if: the live transcriber's accuracy is measured to be worse than
the batch one on real voices, in which case the batch route, which still
exists, takes over after stop.

---

### 204. Location is a place name, and there is a log out
Sep 2026, Adnan

Decision: the profile shows where a person is as a place they would say,
neighbourhood, city, state, resolved on the phone by Apple's geocoder and
stored as text. The region row is gone. The profile tab has a log out, which
forgets the phone's session, and the next launch is the sign in screen
rather than first run. Sign in with Apple works from a phone with no
session, making an account if the Apple account has none.

Why: US West is not an answer to where are you. The geocoder is on the phone
and costs no package and no vendor. A log out is table stakes.

---

### 205. Embeddings come from one model, over the gateway, and each call is a generations row
Sep 2026, Claude

Decision: the gateway gains a second function beside call, embed, which
posts to OpenAI's embeddings endpoint over plain fetch and returns a vector
cut to the 1536 the column holds. Only OpenAI, only text-embedding-3-small,
no provider order. Every embedding call writes a generations row with the
purpose embedding, the model as its model version and the word none as its
prompt version, because it has no prompt. The embed_entry job, queued since
task 8 and never claimed, is handled by the runner and upserts one row in
entry_embeddings. The entries that queued in the meantime run the first time
the runner sees the type.

Why one model with no fallback: a cosine distance between vectors from two
models is a number that means nothing, so a call that fell over to Gemini
would poison every query that touched the row. A failed embedding is a retry
later, which the queue already does. Changing the model means embedding
every row again, so it is a constant on the gateway and stamped on each row rather
than a config entry that looks cheap to change.

Why a generations row anyway: the row is the only record that a student's
words went to a provider, and the list of times that happened should not
have a hole in it because one kind of call returns numbers instead of text.
The purpose enum gains embedding for it. The prompt version has to be
something, since the column refuses null and invariant five wants one on
every generation, and none is at least honest.

Reverses if: a second model is ever needed, in which case the model version
column is how the rows from each are told apart and embedding every row again is planned
rather than accidental.

---

### 206. The shape of a fact
Sep 2026, Claude

Decision: the facts table is as docs/memory.md describes, with these
choices made where it was silent. tier is an integer, 0 for a fact read from
an entry and 1 for one consolidation writes later. The embedding is nullable:
the fact is the record and the vector is one of two ways to find it, so a
fact whose vector could not be had is still written and is still found by
name. retired_at is kept apart from valid_to. A contradicted fact gets
valid_to, because it stopped being so. retired_at is for a fact the system
stopped trusting, which is what deleting the only entry behind it will do,
and that is later work.

A fact said again, same subject, same predicate, same object, compared case
insensitively, is not a second row. The new entry's id joins entry_ids on
the open row. A fact with the same subject and predicate and a different
object closes every open fact with that subject and predicate by setting
valid_to to the new entry's time, and is then inserted with valid_from at
that same time. Nothing is deleted.

Why: the doc's own example is three rows about one person and one teacher
across a week, and a person who says the same thing every Tuesday should
have one fact with many entries behind it rather than many facts with one
each. Keeping valid_to and retired_at as different questions is what lets
the table answer what was so in March and what the system believed in
March, which are not the same question.

Reverses if: consolidation turns out to want a tier that is not an integer,
or the nullable embedding leaves too many facts unfindable by meaning, in
which case a backfill job is the fix rather than a not null constraint.

---

### 207. Facts are extracted in their own job, shown what is already held
Sep 2026, Claude

Decision: the tagger books an extract_facts job after it writes its row, the
same way it books cue cards and people, rather than extracting facts
inside its own run. The job loads the newest forty open facts about the
student and hands them to the model under the entry, so the same thing is
named the same way twice and a change can be seen as a change. The subject
of a fact about the student themselves is the word I. The prompt,
prompts/facts.v1.md, is the tagger's rules again: situations never traits,
their words never a summary, an empty list is the common answer, no dashes.

Why its own job: the tagger is what the rest of the system stands on, and a
fact call that reads forty rows and closes some of them has more ways to
fail than a tag call does. The tagger should not be retried, and its tags
rewritten, because a fact could not be.

Why the held facts go into the prompt: closing a contradicted fact depends
on the new one having the same subject and predicate, and a model that has
never seen the old fact will name it differently by chance. The cost is
that a background call now carries earlier facts about the student as well
as the entry, all of which are the student's own words and all of which
already went to the same provider once.

Why I: the extractor does not know the student's name, and the doc's Adnan
is a stand in. A fact whose subject is I is not matched by name at
retrieval, since I is in nearly every entry, and is found by meaning
instead.

Reverses if: a run of extraction shows the model inventing facts even with
the prompt's examples, in which case the confidence floor moves up and low
confidence facts stop being loaded, the same rule tags follow.

---

### 208. What the Mirror is now told, and in what order
Sep 2026, Claude

Decision: loadContext returns two more things. The nearest twelve earlier
entries by cosine distance to the current entry, from any time, never the
current one and never one of the recent eight, and empty until the entry's
own embedding exists. And the open facts the entry touches, at most twelve,
where touched means the fact's subject or object appears in the entry as a
whole word, or the fact's embedding is among the eight nearest to the
entry's. Name matches come before nearest ones. For each fact, the outcomes
of any decisions on the entries behind it are attached. No distance
threshold on either query: the nearest twelve are the nearest twelve.

The rendered prefix keeps its old order and adds two sections after the
past outcomes: the facts, oldest first, each with its outcomes under it, and
then the entries that read like this one, oldest first. Recent entries stay
last so newest last still runs into what they just said. Everything is
quoted in the student's words.

Only the Mirror reads loadContext. Beat one still builds its own prompt from
the entry and the tone, and nothing in this change touches it.

Why the name match runs in code rather than SQL: a whole word test with
escaping is one small function in TypeScript and a regular expression built
in SQL. The open facts are capped at sixty rows read, which is a small
query, and the function is testable with a string.

Why no threshold: the instruction asked for the nearest twelve, and on a
student with few entries a threshold would make the section appear and
disappear from one entry to the next. The Mirror's prompt already knows
that history is history.

One thing to say plainly: SCHEMA.md used to say entry_embeddings was queried
by background jobs and never on the request path, and FLOW.md had always
listed pgvector neighbours under buildContext, which runs on the Mirror
request. The two disagreed and docs/memory.md settles it on FLOW.md's side.
SCHEMA.md now says what happens. The embedding job itself is still in the
background and nothing that was in the background moved.

Reverses if: the twelve nearest entries turn out to pad the prompt with
unrelated months on a student with a long record, in which case a distance
cap is the fix and it goes here, not in the prompt.

---

### 209. Consolidation is one job for everybody, its last run is a generations row, and a tier 1 fact stands on at least two
Sep 2026, Claude

Decision: consolidate_memory is booked the way the sweep is, one pending row
with no student on it, self booked for the next night at the end of every
run and once when the worker starts. It runs at the sweep's hour rather than
chained behind the verdicts, because the two read different tables and the
runner takes one job at a time. One run finds everybody with an open tier 0
fact learned since their last consolidation and takes them one at a time,
consent checked first, a failure logged and the night going on.

The last consolidation for a person is their newest generations row with
the purpose consolidate. The gateway writes one on every call whether or not
anything was written, so a night that read the facts and settled nothing
still counts as a night that ran, and the same facts are not read again
tomorrow for the same empty answer. No new column and no new table.

The model is shown three lists, the new facts, the older open tier 0 facts
newest forty, and the tier 1 observations already written, with the first
two numbered in one sequence. It answers with numbers. An observation is
written only when it points at two or more facts that were sent and at
least one of them arrived since the last run. Its entry ids are the union
of the entry ids behind those facts and its valid_from is the earliest of
them, so a tier 1 row opens to the same words a tier 0 row does. Said again
at tier 1 joins the open observation. Same subject and predicate with a new
object closes the earlier tier 1 rows with valid_to. Tier 1 never closes
tier 0: an observation across several facts does not get to end what
somebody said.

Why the generations table: it is already the record that a person's words
went to a provider, it already carries the purpose and the student, and the
question asked here is exactly when that last happened. A last_consolidated
column on students would have said the same thing twice.

Why at least two: the doc calls this the episodic to semantic step, and one
fact is already episodic. An observation from one fact is that fact
paraphrased, which is the one rewrite the memory layer promises never to do.

Why the context builder reads tier 1 unchanged: docs/memory.md keeps both
tiers in one table so both are showable, and loadFacts already selects open
facts without a tier test. Nothing was added to make them appear and nothing
was added to hide them.

Reverses if: a run of consolidation shows the model padding three
observations a night out of thin facts, in which case the confidence floor
moves up in code and the ceiling stays. Or if a person's fact count grows
past the forty shown, in which case the held list becomes the nearest by
meaning rather than the newest.

---

### 210. The graph is one route, the person is the root, and a name match is a whole match
Sep 2026, Claude

Decision: GET /graph lives in api/src/routes/graph.ts with its read in the
same file rather than under services/reads, because it is the one read that
is not a screen shape of its own but the memory laid bare, and the doc
comment on that file names who reads it. It runs inside asStudent like the
other reads. The person node's id is the student id, and every other node's
id is its own row id, so ids are unique across types without a prefix.

What is in it: the person, every open fact at either tier with its entry
ids, everybody in the people table, every confirmed pattern not removed,
every decision that is open or closed, and every outcome on those decisions.
Abandoned decisions are left out with their outcomes, because they are what
the person walked away from and are not part of what they did. Nothing on
the node says good or bad, and nothing on it is a verdict.

Edges are pairs of ids and carry no label. The person has one to every other
node, a decision has one to each of its outcomes, and a fact has one to a
named person when its subject or its object equals that person's name, case
insensitively, as a whole. Not a substring: the extractor writes the name
the person used as the whole subject or object, the people job writes the
same name, and Sam inside Samira is not Sam.

Rejected: a labelled edge type. The two ends already say what the edge is,
and a label is one more thing for two clients to keep in step. A person node
with counts on it, for the same reason the fact node does not carry a count:
the screen can count what it is given.

Reverses if: the map tab needs a fact to reach a person it merely mentions
inside the object, in which case the whole word test from buildContext is
the right tool and it goes here, not in the extractor.

---

### 211. First run is one sequence, in the shape of Nouvel's onboarding
Sep 2026, Claude, on Adnan's instruction

Decision: first run is one widget, `FirstRun` in
`app/lib/features/onboarding/first_run.dart`, that walks nineteen screens in
a line and owns what they share: a capsule per question along the top, a
back chevron, and a slide from each step to the next that reverses for back.
Each screen is only its own question, built from `onboarding_kit.dart`: an
uppercase eyebrow saying which part of first run this is, the question in
the serif, a quieter helper line, the options in a scroll, and one pinned
continue that is dim until there is an answer. The shape, the reveal on the
how it works screen, the option rows that fill with the accent and fade the
others, the chips for one word answers and the landing before sign in are
taken from the v2 onboarding in the Nouvel repository, which Adnan asked to
be used here. The colours, the type and every word are Soul's.

Two screens are new. How it works reveals the four things that happen every
time, one a second, and carries the what this is not inset that used to sit
on the intro, so the welcome says what reflection is and the next screen
says what the app does with it. A tap shows all of it at once and reduce
motion renders it complete, because a timed reveal that cannot be hurried
reads slower than the reader. The landing after the introduction hands back
what was given as it was given, a name, a band, a place, and says nothing is
scored. It has no back, since the introduction has already been sent.

Every question now has a continue rather than moving on the moment an option
is tapped. Two reasons. A mis tap is one tap to fix instead of a back and a
retap, and the dim continue is the visible form of the rule that every
question is answered: there is no skip, and a button that does nothing until
something is chosen says so without a word. The where question no longer
moves on by itself when the phone answers either; the place lands as a
chosen row and the person continues, because a fix can take ten seconds and
a screen that leaves under a finger is worse than one more tap. A picked
region replaces the phone's coordinates on the client, so the two are never
sent together.

Found on the way: FLOW.md said at the top of flow 0 that every question can
be skipped and at the bottom that every question is mandatory on the
founder's call, and pointed at decision 063, which is about sessions.
CLAUDE.md and README.md said skippable. The code has had no skip on any list
question since the founder's call, so the documents now say mandatory and
this entry is what they point at. If the call was the other way, the fix is
one line: the continue reads Skip when nothing is chosen and stays live.

Also on the way: `baseline_answering.dart` and `baseline_more.dart` are now
dead. The ten answering controls in them had been unused since the baseline
went to plain rows, and `ListChoices`, the last thing read from them, is
replaced by `OptionRow`. They are left in place for a separate decision.

Rejected: an animation package for the step transition. It is one controller
and a stack of two, and every package is a name in a district data
agreement. Auto advancing on tap, kept from before: see above. A progress bar
over the narrative screens: they are not work to get through and a bar over
them would say they were.

Reverses if: the founder wants the questions skippable again, or fourteen
extra taps prove to be what stops a student finishing first run, in which
case single choice questions go back to advancing on the tap and the
continue stays only on the name and the where.

---

### 212. The baseline is answered by movement, in the shape of Nouvel's first onboarding
Sep 2026, Claude, on Adnan's instruction

Decision: each of the ten baseline questions is a scene in
`app/lib/features/onboarding/baseline_scenes.dart`, no two alike, and there
is no continue on any of them. A scene responds under the finger, settles
once chosen, reports the option index, and the next question follows on its
own. The mechanics are the ones Nouvel's first onboarding used before it
went to rows on 25 August 2026, which Adnan asked for after seeing the rows
from decision 211: a light dragged to a corner, answers drifting on a dark
pond that sink with a ripple, four low walls one of which is pushed over, a
ball on a seesaw, an orb on a vertical track that dims the room as it drops,
a deck of cards swiped to pass or to choose, a sun dragged up that warms the
sky, endings drifting near a blank sentence, an ember slid along a line, and
four seeds one of which grows and opens. The questions, the options and the
answers array are unchanged. Every scene is handed the answer already given
so coming back shows it settled, and each one settles the same way under
reduce motion, without the drift and the bob.

The mapping is by the `Answering` value each question already carried, so
the pairing of question to control is the one the set was written with and
no question was moved. The one scale question takes the sun, since up is
more. The sentence question takes the blank. The single word question takes
the seeds, in the four colours, so the set ends lighter than it ran.

Why no continue here when the profile questions have one: a button after a
movement makes it a form again, and Nouvel's first flow had none. The
profile questions keep theirs because a name is typed and a region is one
of sixteen, and neither is a movement. A tap that lands during the slide
from the last question is ignored for the length of the slide, so a finger
still moving cannot answer the next one by accident.

This reverses "First run speaks one language" from 3 September, which took
the ten earlier controls out for rows. It does not restore them:
`baseline_answering.dart` and `baseline_more.dart` are still dead and still
left for a separate decision. The scenes here are drawn from Nouvel's
mechanics, not those.

Rejected: keeping a continue under each scene, for the reason above. One
mechanic reused across several questions, because ten of the same movement
reads as a gimmick where ten different ones read as attention. Haptics from
a package: the standard `HapticFeedback` is enough for a click on each stop
and an impact on a commit.

Reverses if: real students answer these slower or less often than the rows,
which the `baseline` post timestamps against the `account_created` event
will show, or the founder wants the rows back.

---

### 213. The age band is a wheel, and the wheel starts on an adult
Sep 2026, Claude, on Adnan's instruction

Decision: the age question is a wheel on `ListWheelScrollView` with fixed
extent physics, the engine behind the system date and time wheel, laid
flatter than the system default because that cylinder shrinks and thins the
outer rows until a six row wheel cannot be read end to end. It is in the
serif with a clay outline as the selection band, since the band is drawn
over the rows and a filled one hid the very value it marked. It replaces the
six rows from decision 211, as Nouvel's first onboarding had it, and it sits
in the middle of the space rather than under the question. The wheel starts
on 18 to 24 when nothing has been chosen, Adnan's call, and the value
recorded from the first frame is read off the wheel itself, so what the
wheel shows is what continue sends. The name step also lost its helper line
the same day, on Adnan's instruction.

Why the wheel: six short ordered bands are what a wheel is for, and the
system engine brings inertia and snap that a hand built wheel does not. Why
it starts on an adult: a wheel always shows a value, and the one it shows to
somebody who scrolls past without reading must not be a minor's band, since
that would record a child from a thumb that never stopped. Nouvel reasoned
the same way for the same control.

Rejected: starting the wheel on the first band, for the reason above. A
wheel with no value until turned, because the engine has no such state and
faking one with a blank row reads as a broken picker.

Reverses if: real students turn out to leave it on 18 to 24 more often than
the rows were left unanswered, which the profile rows against the age bands
in `app_events` will show.

---

### 214. Three gender options, not four
Sep 2026, Adnan

Decision: the gender question offers Male, Female and Rather not say. The
nonbinary option is removed from the client list in `profile_fields.dart`.
The database enum is untouched, so any row that already holds nonbinary
keeps it; the profile tab shows such a row with no label, because the
lookup finds no match, and the person can set it to one of the three.

Why: the founder's call, given on seeing the screen on 4 September 2026.

Reverses if: the founder wants it back, which is one line in the list and
nothing in the database.

---

### 215. The where question is a world map, and the sixteen regions are what it stores
Sep 2026, Claude, on Adnan's instruction

Decision: the where question is Nouvel's first region step, rebuilt. The
whole world first, divided into continents; a tap on any country zooms to
its continent, a second tap picks the country. Under the map, a line that
asks the phone, and a smaller one for somebody who would rather not say.
The coastlines are Natural Earth's 177 countries as longitude latitude
rings, in `app/assets/world_map.json`, read once from the bundle; the
projection, the continent split and the fourteen point tap tolerance are
in `world_map.dart`, ported from Nouvel's `WorldMapGeometry`.

After the country, the card from the bottom: the country's states, then
the state's cities, each with a search, and a city can be typed when the
list does not have it. Adnan asked for this after seeing the zone pick, on
4 September. The names are Nouvel's dataset, 250 countries, 5329 states
and 154 thousand cities, in `app/assets/locations.json`, parsed once off
the main thread. A country the dataset does not know, and there are a few
small ones on the map it lacks, answers the question directly as its own
name.

What the server stores is unchanged. The country and the state decide the
region from `regions.ts`: the United Kingdom, Ireland, New Zealand, India,
Singapore, the Emirates and South Africa each map to their own key; a state
of the United States, Canada or Australia maps to the zone most of it keeps,
in `regionFor` in profile_fields.dart, which is rough at the edges the way
the server's own nearest point match is; and every other country stores as
elsewhere. The city, state and country are held as words in `place`, the
text field the phone's answer already used for a place name, at most a
hundred and twenty characters, so no column was added and no quiz was owed.
Nouvel stored country, state and city as three fields; Soul holds one line
of words and one region, and the profile tab shows both.

Two things the first flow did that decision 211 had undone are back,
because Adnan asked for it exactly. The phone's answer moves the question
on by itself, and prefer not to say moves on too. Prefer not to say stores
elsewhere, which is the list's own catch all and carries no timezone, so
the scheduler treats it as it treats any unknown zone; nothing is invented
about where the person is.

Once the phone has said no, the line under the map opens the phone's own
settings for this app, or the phone wide location switch when that is what
is off, and the phone is asked again the moment the app comes back. Adnan's
call on 4 September: a line that says turn it on in Settings and does not
go there is a dead end. `openLocationSettings` in device_location.dart is
the door, through the geolocator package already in use, so no new
dependency.

Known gap: Singapore is smaller than the map's resolution and has no
shape, so it cannot be tapped. The phone finds it, and the server derives
the region from the coordinates.

Rejected: three new columns for country, state and city, since the place
field already holds the same words and a schema change is a quiz. A search
box over the map, which Nouvel had hidden in favour of the zoom, for the
same reason it hid it; the search lives inside the picker instead.

Reverses if: the district agreements want a finer place than a region, at
which point the columns come first and the dataset after.

---

### 216. The cards are dealt face up, not swiped away
Sep 2026, Adnan

Decision: the deck question shows all four options at once, four cards lying
on a table, and a tap picks one. Swiping is gone.

Why: the founder said the cards made no sense, and the interaction was
answering a different question from the one asked. The question picks one of
four. The deck showed one card at a time and asked swipe right if it is you,
left if it is not, so a person judged the first card with nothing to compare
it against, and rejecting a card only moved it to the back of the pile. Four
rejections returned to the first card. There was no state in which the deck
ended without a choice, and no point at which all four had been seen
together.

Dealing them face up keeps the cards, which are the reason this question does
not look like the other nine, and makes the choice a comparison. The chosen
card straightens and lifts, the other three stay lying where they fell and
fade back.

Reverses if: a question arrives that really is a yes or no on each of several
things, which is what the swipe was built for and is not what any of the ten
ask.

---

### 217. The sky has no words down its edge, and it says it can be dragged
Sep 2026, Adnan

Decision: the sunrise question loses the two words that ran down the left of
the sky, and gains one quiet line under it that says the sun can be dragged.
The `ends` field is gone from the question shape with them, since nothing
else used it.

Why: the words named a scale the options do not run on. The sky read every
time at the top and not at all at the bottom while the four options read
strongly agree down to disagree, so the eye was given one scale and the hand
chose from another. The options already say what each height means.

And nothing on the sky said it could be touched. A person who does not try
will tap a row and never learn the sun was theirs to move, so one muted line
says so and fades the moment anything is chosen.

Reverses if: a question needs poles that the options do not already name, in
which case they come back as part of that question rather than as a field
every question carries.

---

### 218. The last screen of first run is written from the answers
Sep 2026, Adnan

Decision: the paragraph on the ready screen is written by a model from the
fifteen answers just given, in the person's own wording, rather than being
the same three sentences for everybody. The request goes out the moment the
baseline ends, so the spoken introduction stands between asking and reading
and there is nothing to wait for.

Why: the founder asked for it. The screen exists so that fifteen questions
land somewhere, and the same paragraph for everybody was not a landing.

What holds it inside the voice: the prompt is told situations never traits,
no praise, no advice, no feeling named for them, and nothing scored, ranked
or totalled. It says back two or three of their own choices and then what
happens from here. The doc comment on the screen said nothing on it is a
result, and that is still true: it is their answers repeated, not a reading
of them.

The questions live in the app and are sent with the answers, rather than
kept a second time on the server where the two copies would drift.

It is allowed to fail. The screen holds room for three lines from the start
and shows the heading, the chips and the button either way, so a failure
costs a paragraph and nothing else.

---

### 219. Sign in shows one way in, and the second appears when the first does not work
Sep 2026, Adnan

Decision: the sign in screen shows the lock, one line, the terms and the
Apple button. The email field appears only after Apple has been tried and
failed. The code is asked for on a screen of its own.

Why: the founder gave the reference and said to match it. One way in is less
to read, and the second arriving at the moment it is the answer to something
is better than two offered at once. The code being on its own screen means
the one thing being asked for is the only thing on that screen.

The terms sit above the button as a sentence with two links rather than as a
tick to give. Using the app is the agreement, per decision 201, so nothing
here stands between somebody and their account.

---

### 220. Every build talks to the service unless told otherwise
Sep 2026, Adnan

Decision: the client points at the API on Render whatever the build mode.
Working against a local API means saying so with the define. This narrows
decision 199, which had a debug build default to localhost.

Why: the simulator went quiet and looked like a broken app when nothing was
running on this machine. Every call failed the same silent way, so the last
screen of first run came up with an empty space where its line goes and
nothing said why. The default that fails when a person forgets to start
something is the wrong default.

What it costs: a build run against a laptop needs one more flag, which is
the person who is changing the API and knows they are.

Reverses if: there is more than one service worth pointing at, in which case
the define is the only way and there is no default worth having.

---

### 221. The line thinks with the answers rather than reading them back
Sep 2026, Adnan

Decision: the line on the last screen says something about the kind of
moment the app will be useful for, given what was answered. It does not
quote the options and does not begin with You said. The sentence about what
happens from here is ours, written into the screen, not the model's.

Why: reading the options back produced sentences that broke in the middle,
because an option is a fragment with a capital letter on it and it does not
fit inside somebody else's sentence. It also said nothing the person did not
just say themselves. The founder asked for something meaningful instead.

What holds it inside the voice: it is still situations never traits, still
no praise, no advice, no feeling named for them, nothing scored. It is
written to them and never as if it were them, and the prompt names the
metaphors it may not reach for, because the first draft of it wrote about
knots beneath surfaces.

The closing sentence is ours because it is the same for everybody and has to
be there whatever the model did, including when the model did nothing.

Reverses if: the observation reads as a claim about a person rather than
about how a kind of decision goes, in which case it goes back to being one
fixed sentence for everybody.

---

### 222. The terms are ticked before signing in, and the way out belongs to one path only
Sep 2026, Adnan

Decision: the sign in screen carries an agreement tick again, and the Apple
button and the email path are both dim until it is given. Pressing the
button without it outlines the box rather than doing nothing. The close
button is gone from the end of first run and stays only on the screen
reached from the intro.

Why: the founder asked for all three. Decision 219 had said the terms would
sit there as a sentence rather than a tick, because using the app is already
the agreement per decision 201. That reasoning stands for the account, which
is made and consented on first launch, and this tick does not change it: it
is an explicit agreement to the terms at the moment an identity is attached,
and the server does not read it. What it changes is that somebody has said
so.

The close button was on both paths. At the end of first run there is nothing
behind that screen to close back to, so it was a way out of a room with no
other door. On the path from the intro there is, and it keeps it.

The heading was centred inside its own width rather than on the screen,
because the column lays its children out from the left and a text takes only
the room it needs. It is given the full width now.

---

### 223. The profile has one edit control, not one per row
Sep 2026, Adnan

Decision: an Edit at the top right of the profile opens the whole card. While
it is open a row is tappable and shows a chevron, and the line under the
heading says so. Done closes it. The four pencils are gone.

Why: the founder asked for it. Four pencils on a card that is read far more
often than it is changed is four invitations to change something nobody came
to change. Decision 217's reasoning for putting a pencil there in the first
place was that a row which opens an editor on any touch makes reading the
profile a minefield, and that still holds: the row only listens while the top
of the screen says the card is being changed.

---

### 224. The week holds what the baseline said until it has something of its own
Sep 2026, Adnan

Decision: the line written from the fifteen baseline answers is kept on the
student and shown inside the week card while there is nothing to divide.
Their own week replaces it the moment a tag names something, and it is never
shown alongside real themes.

Why: home on day one was a blank ring, an empty row of days and a link to a
patterns screen with nothing on it. Somebody had just answered fifteen
questions and the first screen after them knew nothing. The answers are the
one thing the app does know about a person who has only just arrived, so the
week says that until it can say something better.

It is not a result and it does not accumulate. It is the same sentence they
read at the end of first run, kept rather than thrown away, and it goes as
soon as their own entries can fill the ring.

Reverses if: the ring learns to divide by something an untagged week already
has, in which case there is no empty state left to fill.

