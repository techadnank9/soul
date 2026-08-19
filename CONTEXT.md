# Context and mental model

What anyone working on this needs to hold in their head. Read this before
writing product copy, prompts, or anything a student will see.

---

## The mental model in one paragraph

A student has just had something happen. They open the app while still in it and
speak for thirty seconds. The app says one true thing back about what they said,
fast. If they want more, it offers a fuller reflection: the tension it noticed,
what might sit underneath, one question. It asks whether there is something they
might do. Days later it asks how that went. Over months, things that keep
returning are offered back as possible patterns, which the student confirms or
rejects. The app never tells anyone who they are.

## What it is not

Not therapy. Not a diagnosis. Not a coach. Not a friend. Not something you can
talk to indefinitely. If a build decision makes it more like any of those,
it is the wrong decision.

---

## Where the clinical guidance comes from

Dr. Sofia Georgiadou, a licensed clinician with over fifteen years of practice
across outpatient, inpatient and residential settings, reviewed an early version
in December 2025. Her answers are the constraint set this product is built
inside. She has not reviewed the under 13 version, and that gap is open.

### What she said we should do

**Calibrate expectations.** Clients arrive unsure what a tool can and cannot do.
Being explicit about scope early is associated with better engagement.

**Support self monitoring between sessions.** Noticing the cycle from trigger to
thought to feeling to behaviour to consequence is something she walks clients
through by hand. A tool that helps someone track that themselves is genuinely
useful.

**Keep any therapist facing output descriptive, not interpretive.** Client
stated goals, triggers, strengths, preferences, and what they want a therapist
to know. No diagnoses, no treatment prescriptions.

**Frame possible themes as hypotheses.** Something a clinician can verify in
session, not something presented as established fact.

**Privacy by design.** Minimal collection, no unnecessary permissions, no third
party tracking.

**Consent as a process.** Explain in plain language what the tool does, what it
stores, its limits, and how anything might be shared. Not buried in legal terms.

**Human in the loop.** Supported tools outperform unsupported ones and reduce
drop off, particularly for people who are less motivated or struggling most.

**Monitor for harm.** Negative effects happen and require tracking and
correction, not denial. Digital tools carry measurable adverse event risk.

### What she said we must not do

**Do not diagnose, treat, or provide crisis care.** No treatment plans, no
prescriptive directives.

**Do not be directive.** Never tell a user what their therapist should do, what
diagnosis they might have, or what they need. It primes people to adopt
narratives about themselves that may not be true, and it damages the therapeutic
alliance when a clinician then has to undo it.

**Do not offer false reassurance.** Especially in a moment of distress.

**Do not let structure increase rumination.** Reflection without coping tools or
human containment can amplify symptom focus rather than reduce it.

**Do not substitute for clinical assessment.** Screening without follow through,
or self diagnosis output presented as fact.

### On young people specifically

This part was written about ages sixteen to eighteen. Treat it as directional
for younger students and get it reviewed properly.

Confidentiality shapes everything. How a young person perceives what stays
private strongly determines what they are willing to say. A clear framework
stated at the start, in simple language, covering what is private, what must be
shared for safety, and how adults are updated.

Autonomy helps. Meaningful choices about pace and what adults know improve buy
in, especially when an adult initiated the involvement.

Surveillance and coercion harm. Anything resembling "we will see what you said"
predictably reduces disclosure and damages trust.

Triangulation harms. A tool used by an adult to prove a young person wrong
increases defensiveness.

Over processing before support harms. Extensive confrontation in advance can
escalate conflict.

---

## The voice

Everything a student reads is written in the same voice. It is closer to a
thoughtful adult who knows them than to an assistant.

### Rules

**No hyphens, no dashes.** Not in product copy, not in prompts, not in anything
we write. Rewrite the sentence instead.

**Use their words.** The best line the app can say is one that quotes something
specific the student just said. If a sentence could be pasted into a different
person's entry unchanged, it has failed.

**Reflect, do not reassure.** "You wrote the email and you didn't send it" is
right. "That sounds really hard" is not.

**Do not name their feeling for them.** "It sounds like you're feeling
frustrated" tells them what they feel. Describe what happened and let them
supply the label.

**Hedge observations so they can be rejected.** "This may have landed as being
erased. Does that fit?" Never "you feel erased."

**Short.** One or two sentences for the first response. Four or five lines for
the Mirror. Nobody in distress reads a paragraph.

**No question mark on the first response.** A question demands something. The
first line should lower pressure, not add to it.

**No advice.** No "have you considered", no "you should", no next steps we
invented.

**Situations, never traits.** "Going quiet when you are not credited", not
"conflict avoidant".

**No jargon.** No burnout, no anxiety, no trauma, no processing, no holding
space. Plain words a twelve year old uses.

**No exclamation marks, no emoji, no encouragement.** No "great job noticing
that."

### Examples that work

> You wrote the email and you didn't send it. That gap is worth a minute.

> You noticed it right after. That's not nothing.

> Three weeks is long enough to start writing a story about it.

> There's a lot here, and the money keeps coming up last.

### Examples that fail, and why

> It sounds like you're feeling frustrated at work.
Generic, and labels the emotion for them.

> Have you considered talking to your teacher about it?
Advice. Makes it an assistant.

> That must have been so difficult.
Sympathy with no content. Could be said to anyone.

> Your anxiety is stemming from a fear of letting your team down.
Asserts a cause with certainty, and uses clinical language.

> You're doing better than you think.
Reassurance we have no grounds for.

---

## On transcription

The student speaks, the audio is transcribed by a provider, and the audio is
deleted immediately. It is never stored.

There is no edit step, so the transcript is the permanent record and the text a
safety classifier reads. That is why the student sees it and chooses send or
discard before anything is submitted.

Recognition on children's voices is materially worse than on adults, worse again
in noisy rooms, and worst for students from non English speaking homes. Typing is
an equal path on the same screen for that reason, not a fallback.

## The compliance shape, briefly

Selling to schools with students under 13 means school consent under the
educational purpose exception, per district data agreements, COPPA obligations
including a written retention policy and information security program, and a
published crisis protocol required by California and New York law. The crisis
protocol is not optional and not a design preference.

None of that changes the product. It changes what has to be true about the
product before anyone uses it.

---

## The open questions

**Accessibility.** Nobody has asked a district what their review involves. If
conformance testing with VoiceOver and TalkBack is a hard gate, the client
framework decision reopens.

**Under 13 clinical review.** Sofia's guidance was written for older teenagers.
A ten year old is a different developmental stage with a different consent
framework.

**Escalation.** What gets reported to the school, to whom, how fast, and how the
student is told about it before they write anything. There is no written answer
yet, and it is the decision that determines whether students trust this at all.

**What a counsellor sees.** A flag and a timestamp, or the student's actual
words. Every capability given to an adult makes the promise to the student
smaller.

**A student with no consent on file is never classified.** The consent gate
sits in front of every outbound call, and the safety classifier is an outbound
call, so an entry from a student whose consent is missing is stored and never
read by anything. No flag exists, so nothing surfaces to anyone. This affects
new, unrostered and transferring students, who are not obviously the safest
group to leave unread. Found by running the submit path, see decision 042.
There is no answer yet and it needs one before any student uses this.
