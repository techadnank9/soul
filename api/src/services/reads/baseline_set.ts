/**
 * The baseline set, set-b-v1, as the app asks it. Copied here so the tiles
 * on home can be built on the server from the stored answers, and so the
 * tagger can be told what somebody said about how they decide.
 *
 * `short` is the answer as the tile prints it: in their voice, a few words,
 * no capital, no full stop. The question and option texts must stay word
 * for word what app/lib/features/onboarding/baseline.dart shows, since the
 * stored answer is an index into them. Decision 279.
 */
export const BASELINE_SET = 'set-b-v1'

export type BaselineSection = 'timing' | 'agency' | 'emotion' | 'repetition' | 'readiness'

export const SECTIONS: BaselineSection[] = ['timing', 'agency', 'emotion', 'repetition', 'readiness']

/** The section's name as the app shows it, and as the tagger is told it. */
export const SECTION_TITLES: Record<BaselineSection, string> = {
  timing: 'Decision timing',
  agency: 'Responsibility and agency',
  emotion: 'Emotion and action',
  repetition: 'Patterns and repetition',
  readiness: 'Readiness',
}

/**
 * What each pair of answers is about, in the words a person would use, for
 * the tile on home. The section keys stay as they are for the tagger and
 * the database; only what a person reads changes. Decision 280.
 */
export const SECTION_TITLES_PLAIN: Record<BaselineSection, string> = {
  timing: 'under pressure',
  agency: 'what you wait for',
  emotion: 'when feelings run high',
  repetition: 'what comes back',
  readiness: 'right now',
}

/**
 * The two answers of a section as one plain sentence or two, in the second
 * person, built from the `said` fragment of each chosen option. A section
 * with only one answer gets the one sentence that fits it.
 */
export function sectionLine(section: BaselineSection, said: string[]): string {
  const [a, b] = said
  switch (section) {
    case 'timing':
      return [a && `Under pressure you tend to ${a}.`, b && `You decide most easily ${b}.`]
        .filter(Boolean)
        .join(' ')
    case 'agency':
      return [a && `Before a big decision you usually wait for ${a}.`, b && `You believe good decisions come from ${b}.`]
        .filter(Boolean)
        .join(' ')
    case 'emotion':
      return [a && `Strong feelings ${a}.`, b && `Afterwards you often ${b}.`].filter(Boolean).join(' ')
    case 'repetition':
      return [a, b].filter(Boolean).join(' ')
    case 'readiness':
      return [a && `You feel ready to ${a}.`, b && `What you want most is ${b}.`].filter(Boolean).join(' ')
  }
}

export type BaselineQuestion = {
  section: BaselineSection
  text: string
  /** `said` is the option as a fragment of the sentence in sectionLine. */
  options: { text: string; short: string; said: string }[]
}

export const BASELINE: BaselineQuestion[] = [
  {
    section: 'timing',
    text: 'When I feel pressure to decide, I tend to',
    options: [
      { text: 'Act quickly to get relief', short: 'acts quickly for relief', said: 'act quickly to get it over with' },
      { text: 'Delay it as long as possible', short: 'delays it as long as possible', said: 'delay it as long as you can' },
      { text: 'Ask others what they think', short: 'asks others first', said: 'ask others what they think' },
      { text: 'Pause and think it through', short: 'pauses and thinks it through', said: 'pause and think it through' },
    ],
  },
  {
    section: 'timing',
    text: 'I usually feel most comfortable making decisions',
    options: [
      { text: 'Under urgency', short: 'under urgency', said: 'under urgency' },
      { text: 'When everything feels calm', short: 'when everything feels calm', said: 'when everything feels calm' },
      { text: 'When someone reassures me', short: 'when someone reassures', said: 'when someone reassures you' },
      { text: 'After time to reflect', short: 'after time to reflect', said: 'after time to reflect' },
    ],
  },
  {
    section: 'agency',
    text: 'When facing an important decision, I often wait for',
    options: [
      { text: 'More certainty', short: 'waits for more certainty', said: 'more certainty' },
      { text: 'External validation', short: 'waits for someone to back it', said: 'someone to back you' },
      { text: 'Circumstances to change', short: 'waits for things to change', said: 'things to change on their own' },
      { text: 'My own clarity to increase', short: 'waits for own clarity', said: 'your own clarity' },
    ],
  },
  {
    section: 'agency',
    text: 'I generally believe good decisions come from',
    options: [
      { text: 'Feeling confident', short: 'feeling confident', said: 'feeling confident' },
      { text: 'Thinking carefully', short: 'thinking carefully', said: 'thinking carefully' },
      { text: 'Avoiding mistakes', short: 'avoiding mistakes', said: 'avoiding mistakes' },
      { text: 'Taking responsibility even without certainty', short: 'owning it without certainty', said: 'taking responsibility even without certainty' },
    ],
  },
  {
    section: 'emotion',
    text: 'Strong emotions usually',
    options: [
      { text: 'Push me to act quickly', short: 'feelings push to act fast', said: 'push you to act quickly' },
      { text: 'Make me avoid deciding', short: 'feelings make me avoid deciding', said: 'make you put the decision off' },
      { text: 'Prompt me to seek reassurance', short: 'feelings send me for reassurance', said: 'send you looking for reassurance' },
      { text: 'Help me notice what matters', short: 'feelings show what matters', said: 'help you notice what matters' },
    ],
  },
  {
    section: 'emotion',
    text: 'After deciding under emotional pressure, I often',
    options: [
      { text: 'Feel relieved but unsure', short: 'relieved but unsure after', said: 'feel relieved but unsure' },
      { text: 'Feel confident', short: 'confident after', said: 'feel confident about it' },
      { text: 'Question myself', short: 'question myself after', said: 'question yourself' },
      { text: 'Avoid thinking about it', short: 'avoid thinking about it after', said: 'avoid thinking about it' },
    ],
  },
  {
    section: 'repetition',
    text: 'I have faced similar decisions before',
    options: [
      { text: 'Strongly agree', short: 'similar decisions before, often', said: 'You have faced decisions like this many times.' },
      { text: 'Somewhat agree', short: 'similar decisions before, sometimes', said: 'You have faced decisions like this before.' },
      { text: 'Not sure', short: 'not sure it has come up before', said: 'You are not sure you have faced this kind before.' },
      { text: 'Disagree', short: 'this kind is new', said: 'This kind of decision is new to you.' },
    ],
  },
  {
    section: 'repetition',
    text: 'Looking back at past decisions, I notice that',
    options: [
      { text: 'I repeat similar patterns', short: 'the same thing repeats', said: 'Looking back, the same thing tends to happen each time.' },
      { text: 'I tend to change my approach', short: 'the approach changes each time', said: 'Looking back, you tend to change your approach each time.' },
      { text: 'Outcomes surprise me', short: 'how it turns out surprises me', said: 'Looking back, how things turn out often surprises you.' },
      { text: 'I avoid reflecting on them', short: 'rarely looks back at them', said: 'Looking back is something you tend to avoid.' },
    ],
  },
  {
    section: 'readiness',
    text: 'Right now, I feel most ready to',
    options: [
      { text: 'Pause and reflect', short: 'ready to pause and reflect', said: 'pause and reflect' },
      { text: 'Take a small next step', short: 'ready for a small next step', said: 'take a small next step' },
      { text: 'Gather more information', short: 'ready to find out more', said: 'find out more first' },
      { text: 'Wait before deciding', short: 'ready to wait before deciding', said: 'wait before deciding' },
    ],
  },
  {
    section: 'readiness',
    text: 'What I want most right now is',
    options: [
      { text: 'Calm', short: 'wants calm', said: 'calm' },
      { text: 'Direction', short: 'wants direction', said: 'direction' },
      { text: 'Confidence', short: 'wants confidence', said: 'confidence' },
      { text: 'Understanding my pattern', short: 'wants to understand the pattern', said: 'to understand your own pattern' },
    ],
  },
]

/**
 * What somebody said, grouped by section, from the stored indexes. A section
 * with no answered question is left out, so a person who skipped half the
 * set gets the tiles they answered and no empty ones.
 */
export function answeredBySection(
  answers: { questionIndex: number; choiceIndex: number }[],
): { section: BaselineSection; shorts: string[]; fragments: string[]; said: { question: string; answer: string }[] }[] {
  const out = new Map<BaselineSection, { shorts: string[]; fragments: string[]; said: { question: string; answer: string }[] }>()
  for (const a of [...answers].sort((x, y) => x.questionIndex - y.questionIndex)) {
    const q = BASELINE[a.questionIndex]
    const o = q?.options[a.choiceIndex]
    if (!q || !o) continue
    const held = out.get(q.section) ?? { shorts: [], fragments: [], said: [] }
    held.shorts.push(o.short)
    held.fragments.push(o.said)
    held.said.push({ question: q.text, answer: o.text })
    out.set(q.section, held)
  }
  return SECTIONS.filter((s) => out.has(s)).map((s) => ({ section: s, ...out.get(s)! }))
}
