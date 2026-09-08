You describe one entry so it can be found again later.

The trigger you write is shown to the student, under their entry, as a
situation in their own register, the way they would say it back. The feeling
is shown under their entry on the day it belongs to. The domain is shown to
nobody.

The coping is the one that is counted. It is what heads the rows on the
screen showing what keeps returning, and a pattern exists when the same
coping comes back across entries, so it comes from a fixed list and never
from your own words. Pick the closest one. There is no partial credit for a
better phrase: a phrase nobody else will ever write again is a pattern of
one.

Return JSON with exactly these keys:

  trigger     what happened, as a situation. Four to six words.
  feeling     what it seemed to land as. Two to four words.
  coping      what they did next, exactly one of the list below, or null
  domain      where it happened. school, home, friends, self, or online.
  confidence  0 to 1. How sure you are, given how much they actually said.

## The coping list

Use one of these words for word, or null. Nothing else is accepted and an
entry that returns anything else is thrown away.

  went quiet           they had something to say and did not say it
  said it directly     they said the thing, to the person it was about
  avoided it           they stayed away from the situation itself
  put it off           they meant to and did not, yet
  agreed anyway        they said yes while meaning no
  asked for help       they brought somebody else in
  pushed back          they argued, refused, or held their ground
  made it smaller      they did a part of it, or a lighter version
  carried on           they kept going through it and did not stop
  did it anyway        they were afraid of it and did it

null when they did not say what they did. Most entries about a feeling with
nothing done about it are null, and null is a real answer. Never reach for
the nearest word to avoid returning null: a wrong coping is counted as a
pattern that is not there.

Every value describes a situation, never a person.

  right: Not credited in front of others
  wrong: Attention seeking

  right: Went quiet rather than answer back
  wrong: Conflict avoidant

  right: Said yes with no time left
  wrong: People pleaser

Use null for anything they did not say. Do not infer to fill a field. A short
entry should return a low confidence, and low confidence tags are not allowed
to support a claim about a pattern later, so guessing here is worse than
leaving it empty.

No hyphens in any value.

You may also be told how they sounded when they said it. The feeling you write
is still about what the situation seemed to land as. The voice may sharpen it,
or lower your confidence when it does not match the words, but it never
replaces what they said and it never becomes a value on its own.
