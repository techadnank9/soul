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

export type BaselineQuestion = {
  section: BaselineSection
  text: string
  options: { text: string; short: string }[]
}

export const BASELINE: BaselineQuestion[] = [
  {
    section: 'timing',
    text: 'When I feel pressure to decide, I tend to',
    options: [
      { text: 'Act quickly to get relief', short: 'acts quickly for relief' },
      { text: 'Delay it as long as possible', short: 'delays it as long as possible' },
      { text: 'Ask others what they think', short: 'asks others first' },
      { text: 'Pause and think it through', short: 'pauses and thinks it through' },
    ],
  },
  {
    section: 'timing',
    text: 'I usually feel most comfortable making decisions',
    options: [
      { text: 'Under urgency', short: 'under urgency' },
      { text: 'When everything feels calm', short: 'when everything feels calm' },
      { text: 'When someone reassures me', short: 'when someone reassures' },
      { text: 'After time to reflect', short: 'after time to reflect' },
    ],
  },
  {
    section: 'agency',
    text: 'When facing an important decision, I often wait for',
    options: [
      { text: 'More certainty', short: 'waits for more certainty' },
      { text: 'External validation', short: 'waits for someone to back it' },
      { text: 'Circumstances to change', short: 'waits for things to change' },
      { text: 'My own clarity to increase', short: 'waits for own clarity' },
    ],
  },
  {
    section: 'agency',
    text: 'I generally believe good decisions come from',
    options: [
      { text: 'Feeling confident', short: 'feeling confident' },
      { text: 'Thinking carefully', short: 'thinking carefully' },
      { text: 'Avoiding mistakes', short: 'avoiding mistakes' },
      { text: 'Taking responsibility even without certainty', short: 'owning it without certainty' },
    ],
  },
  {
    section: 'emotion',
    text: 'Strong emotions usually',
    options: [
      { text: 'Push me to act quickly', short: 'feelings push to act fast' },
      { text: 'Make me avoid deciding', short: 'feelings make me avoid deciding' },
      { text: 'Prompt me to seek reassurance', short: 'feelings send me for reassurance' },
      { text: 'Help me notice what matters', short: 'feelings show what matters' },
    ],
  },
  {
    section: 'emotion',
    text: 'After deciding under emotional pressure, I often',
    options: [
      { text: 'Feel relieved but unsure', short: 'relieved but unsure after' },
      { text: 'Feel confident', short: 'confident after' },
      { text: 'Question myself', short: 'question myself after' },
      { text: 'Avoid thinking about it', short: 'avoid thinking about it after' },
    ],
  },
  {
    section: 'repetition',
    text: 'I have faced similar decisions before',
    options: [
      { text: 'Strongly agree', short: 'similar decisions before, often' },
      { text: 'Somewhat agree', short: 'similar decisions before, sometimes' },
      { text: 'Not sure', short: 'not sure it has come up before' },
      { text: 'Disagree', short: 'this kind is new' },
    ],
  },
  {
    section: 'repetition',
    text: 'Looking back at past decisions, I notice that',
    options: [
      { text: 'I repeat similar patterns', short: 'the same thing repeats' },
      { text: 'I tend to change my approach', short: 'the approach changes each time' },
      { text: 'Outcomes surprise me', short: 'how it turns out surprises me' },
      { text: 'I avoid reflecting on them', short: 'rarely looks back at them' },
    ],
  },
  {
    section: 'readiness',
    text: 'Right now, I feel most ready to',
    options: [
      { text: 'Pause and reflect', short: 'ready to pause and reflect' },
      { text: 'Take a small next step', short: 'ready for a small next step' },
      { text: 'Gather more information', short: 'ready to find out more' },
      { text: 'Wait before deciding', short: 'ready to wait before deciding' },
    ],
  },
  {
    section: 'readiness',
    text: 'What I want most right now is',
    options: [
      { text: 'Calm', short: 'wants calm' },
      { text: 'Direction', short: 'wants direction' },
      { text: 'Confidence', short: 'wants confidence' },
      { text: 'Understanding my pattern', short: 'wants to understand the pattern' },
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
): { section: BaselineSection; shorts: string[]; said: { question: string; answer: string }[] }[] {
  const out = new Map<BaselineSection, { shorts: string[]; said: { question: string; answer: string }[] }>()
  for (const a of answers) {
    const q = BASELINE[a.questionIndex]
    const o = q?.options[a.choiceIndex]
    if (!q || !o) continue
    const held = out.get(q.section) ?? { shorts: [], said: [] }
    held.shorts.push(o.short)
    held.said.push({ question: q.text, answer: o.text })
    out.set(q.section, held)
  }
  return SECTIONS.filter((s) => out.has(s)).map((s) => ({ section: s, ...out.get(s)! }))
}
