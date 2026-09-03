import type { Tone } from './store.js'

/**
 * How a tone reads inside a prompt.
 *
 * Plain words, and a shape the prompts can be told to use for register and
 * never to quote. The numbers stay numbers: a model told "fast" invents what
 * fast means, a model told the words a minute does not.
 */

const INTENT: Record<string, string> = {
  venting: 'getting something out',
  deciding: 'working out what to do',
  asking: 'asking for something',
  reporting: 'telling what happened',
  rehearsing: 'going over what they might say',
  celebrating: 'sharing something good',
  checking_in: 'checking in, nothing pressing',
  unsure: 'hard to say what the speaking was for',
}

function strength(intensity: number): string {
  if (intensity < 0.25) return 'faintly'
  if (intensity < 0.5) return 'somewhat'
  if (intensity < 0.75) return 'clearly'
  return 'strongly'
}

export function renderTone(tone: Tone): string {
  const lines = [
    `  ${strength(tone.intensity)} ${tone.emotion}. ${tone.sounded}`,
    `  seemed to be ${INTENT[tone.intent] ?? tone.intent}`,
  ]

  const measured: string[] = []
  if (tone.wordsPerMinute) measured.push(`${tone.wordsPerMinute} words a minute`)
  if (tone.pauses) measured.push(`${tone.pauses} long ${tone.pauses === 1 ? 'pause' : 'pauses'}`)
  if (tone.hesitations) measured.push(`hesitated ${tone.hesitations} ${tone.hesitations === 1 ? 'time' : 'times'}`)
  if (tone.audioEvents.length) measured.push(tone.audioEvents.join(', '))
  if (measured.length) lines.push(`  ${measured.join(', ')}`)

  lines.push(`  confidence ${tone.confidence.toFixed(1)}`)
  return lines.join('\n')
}

/** One clause, for a line of history. */
export function renderToneBrief(tone: Tone): string {
  return `sounded ${tone.emotion}, ${INTENT[tone.intent] ?? tone.intent}`
}
