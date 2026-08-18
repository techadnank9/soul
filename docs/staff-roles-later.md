# Staff roles: district admin and counsellor

Deferred scope. Not being built now. Written down so the student app does not
accidentally close the door on it.

## District admin

Never sees a single student reflection. This is the rule the whole role is
built around, and it should be enforced in the database, not the interface.

What they can do:

- Manage the district and school hierarchy, and staff accounts within it
- Record and evidence the school consent that COPPA's educational purpose
  exception relies on, per student, with dates and scope
- Set the retention period, and trigger deletion for a student, a class, or
  the whole district
- Export the data a district is entitled to under FERPA inspection rights
- Read the audit log: who viewed what, when
- Configure the escalation policy: who gets notified, in what order, how fast
- See adoption numbers only in aggregate, never per student

What they cannot do:

- Read reflections, Mirror responses, patterns, or decisions
- See which individual students have been flagged
- Grant themselves any of the above

## Counsellor console

The narrower the better. Every capability here makes the promise to the
student smaller, and students disclose based on what they believe stays
private.

What they can do:

- See the students who have been flagged by the safety classifier, and nobody
  else
- See the flag, when it happened, and its severity band
- Mark a flag as reviewed, acted on, or closed, with a note they write
  themselves
- Trigger the guardian notification step where policy requires it

What they cannot do:

- Browse students who have not been flagged
- Read reflections in full (open question, see below)
- See patterns, decisions, or outcomes
- Export anything

Every read is written to the audit log, and the log is visible to the district
admin.

## Open questions to settle with Sofia before building this

1. Does the counsellor see the student's actual words, or only a flag and a
   timestamp? A flag alone protects disclosure but gives the counsellor no
   context to act on. Full text gives context and changes what the product is.
   This is the single biggest decision in the staff surface.

2. What is the escalation threshold, and who defines it, us or the district?

3. Guardian notification: always, or only above a severity line? What happens
   when the guardian is part of what the student is struggling with?

4. How and when is the student told all of this? It has to be before they
   write anything, in language a child understands, and it has to be true.

## What this means for the student app now

Three things to build in from the start, because they are expensive to add
later:

- Every row carries student, school, and district identifiers, with row level
  security in the database
- An audit log table exists and is written to from day one, even while nobody
  is reading
- Safety flags are stored as their own records with a status field, not as a
  boolean on an entry

Nothing else about the staff surfaces needs to exist yet.
