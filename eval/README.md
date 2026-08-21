# Eval

Empty on purpose, and it is the most important empty directory in this
repository.

Task 7 in BUILD_PLAN.md says to collect twenty real entries, write beat one
candidates for each, and judge them by hand against one rule: could this line be
pasted into a different person's entry unchanged. Those twenty entries with
their verdicts become the fixture set every future prompt change is measured
against, and they belong here.

It has not been done. The loop runs, real students have not used it, and the
prompt in prompts/beat_one.v1.md has never been measured against anything. The
first line a student reads is still the thing the plan says decides whether the
product works.

The evidence that this matters is already in the repository. An entry reading
"I would like to play football" came back as "You said you would like to play
football", which is a restatement rather than a reflection and would pass no
test written here.

What lands in this directory when the task is done:

  entries.json     twenty real entries, anonymised
  verdicts.md      the hand written judgement on each candidate line
  run.ts           replays the fixture set against the active prompt
