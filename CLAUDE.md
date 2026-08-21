# CLAUDE.md

Instructions for any AI assistant working in this repository. Read this first,
then DECISIONS.md, then FLOW.md, then CONTEXT.md.

## What this is

Soul, a reflection app for students in schools, including under 13. A
student speaks for thirty seconds, gets one short line back, and can go deeper
if they want. Over months, recurring themes are offered back as patterns the
student confirms or rejects, and the ones that keep returning are sorted into
what is doing them good and what is costing them, with one sentence under each
saying to keep it or to stop it.

That last part is new and it reversed two rules this repository used to state
flatly. The product used to give no advice and to assert nothing about a
student. It now does both, on the patterns screen and nowhere else. It was a
founder decision taken deliberately against the clinical guidance, it is
written out in CONTEXT.md under what changed in August 2026, and it is not
something to hedge back into a hypothesis because the old wording reads
stricter.

The loop runs end to end. A student can speak or type, the entry passes the
consent gate and the safety classifier, a real model writes beat one, the Mirror
runs on request, and decisions are stored. BUILD_PLAN.md has the task list and
README.md has the current state of each one.

Two things are worth knowing before you touch anything:

**Task 0 was never done.** The keyboard test on real devices and the forty clip
transcription comparison both need hardware and real students. Decisions 010 and
017 rest on them and are still unverified.

**Task 7 has not started.** It is the one the plan says decides whether the
product works, and no amount of code substitutes for it.

## Read these before writing code

| File | What it holds |
| --- | --- |
| DECISIONS.md | Every decision, why, and what would reverse it |
| FLOW.md | Execution paths, call order, invariants |
| CONTEXT.md | Clinical constraints and the voice rules |
| SCHEMA.md | The data model |
| BUILD_PLAN.md | Ordered tasks with done conditions |
| docs/screens.html | The original ten screens, open in a browser |
| docs/architecture.svg | System architecture |
| docs/user-flow.svg | The three time horizons of the product |

## Rules you must follow

**Log your decisions.** If you make a choice that was not explicitly instructed,
add an entry to DECISIONS.md before finishing the task. Library choices, schema
shapes, naming conventions, error handling, anything you decided because the
instruction was ambiguous. If unsure whether it counts, log it.

**Keep FLOW.md true.** If you change the call order, the entry points, or what
calls what, update FLOW.md in the same commit. A stale flow document is worse
than none.

**No hyphens in anything a human reads.** Not in product copy, not in prompts,
not in comments, not in documentation. Rewrite the sentence instead. This
applies to em dashes and en dashes too.

**Write in the product voice.** CONTEXT.md has the rules and examples. Anything
a student sees goes through them. Short, specific, no reassurance, no jargon,
no emotion labels, no exclamation marks, no emoji, and no advice anywhere
except the one sentence under a good or a bad pattern, which is allowed to say
keep this or stop this and nothing more.

**Situations, never traits, did not change.** It is the rule the verdict is
built inside. The app says what keeps happening to somebody. It never says what
kind of person they are, and no clinical word goes near either section.

**Do not break an invariant.** They are listed at the end of FLOW.md. A change
that breaks one is wrong regardless of what it improves.

**Ask before adding a dependency.** Every package is a maintenance liability and
every service is a sub processor named in a school data agreement. Prefer the
standard library, prefer one more function over one more package.

**Never add analytics or crash reporting SDKs to the student app.** COPPA treats
persistent identifiers as personal information and the app store kids policies
restrict third party data collection. Log events to our own backend instead.

## The quiz protocol

Before a change lands that touches the orchestrator, the context builder, the
model gateway, the safety path, the consent gate, or the schema, quiz the human
on it. Five questions, and they should answer without opening the diff:

1. What is the new call order, and what did it used to be?
2. Which function is now doing something it was not doing before?
3. Can the safety classifier still not be skipped? Show the path.
4. What does this change put into the model prompt that was not there before?
5. If this is wrong at 2am for one student, what breaks and what still works?

If they cannot answer, do not merge. Explain the change until they can.

## Things that will feel wrong but are correct

**Beat one gets almost no history.** The founder decision is that the model
should know the whole person, and it does, on the Mirror call. Beat one stays
minimal on purpose because latency and specificity beat context there.

**Pattern detection is a SQL query, not a model call.** So we can always show a
student the exact entries behind a claim. Do not "improve" it into an LLM step.
Which themes exist and which entries are behind them is still SQL and stays
SQL.

**The verdict on a theme is a model call, and that is not a hole in the rule
above.** Finding the theme and judging it are two questions. The finding stays
in SQL so the entries behind a claim can always be shown. The judging runs in
`services/verdicts`, in the night, over themes with at least two entries, and
never on the request path. Where the student's own outcomes have already said
lighter or worse, the model is told that verdict and writes only the sentence,
so it cannot contradict them.

**The tagger runs after the response is already on screen.** Never move it onto
the request path to make the code simpler.

**Rejected patterns are stored.** They are not failures, they are training
signal and they stop us repeating a wrong guess.

**Empty states get built before populated ones.** Every mockup shows a full week
of data. No student has that on day one.

## How to run it

Postgres and the API in one terminal, the app in another. README.md has the
commands. The client reads `SOUL_API` and `SOUL_STUDENT` at build time, so a
debug build points at a laptop and a release build cannot point anywhere by
accident.

Two test students exist: `student_with_consent` and `student_no_consent`. The
second one is how you check the gate without editing code. They are created by
`npm run seed`, so a reset does not lose them.

First run is an intro, four profile questions, the ten baseline questions, then
home. Every question in it can be skipped, and a student who skips all of them
still gets the whole product. The profile tab, fourth on the bar, shows every
held field and can empty any of them.

What the profile holds, and the argument about it, is decisions 056 and 061.
The second one covers exact coordinates, which the client asks the device for
and the database stores. Nothing in the product needs them and the reasoning
for holding them anyway is recorded there. Read it before adding anything to
that row.

The iOS simulator has no microphone unless the Mac has one. Voice paths have to
be checked against a real device or a plugged in mic; the simulator returns an
empty buffer and the app correctly reports that nothing came through.

## Working style

Small commits, each one leaving the app runnable. Tests on the pieces where
being wrong is expensive: consent gate, safety path, row level security, context
builder. Not everywhere.

When a task's done condition in BUILD_PLAN.md is met, say so plainly and stop.
Do not start the next task without being asked.

If something in these documents is wrong or contradicts itself, say so rather
than picking an interpretation silently.
