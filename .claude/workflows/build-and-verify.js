export const meta = {
  name: 'build-and-verify',
  description: 'Build a feature in disjoint parts in parallel, then have independent agents try to break each part',
  whenToUse:
    'A change big enough to split across files that do not overlap: a backend half and a client half, or three platform pieces. Not for a single file edit.',
  phases: [
    { title: 'Build', detail: 'one agent per part, file sets that do not overlap' },
    { title: 'Verify', detail: 'a different agent per part, told to break it' },
  ],
}

/**
 * The shape that worked twice on this repository, kept so it can be run again.
 *
 * What makes it work is not the parallelism. It is that the verifier is a
 * different agent from the builder, is told to break the thing rather than
 * confirm it, and has to produce a repro. On the Apple sign in run the builders
 * reported success on every part and the verifiers still found ten real
 * defects, including a forged token returning 500 and a token cache that could
 * be used to hammer Apple once per request.
 *
 * Two rules that are load bearing:
 *   file sets must not overlap, or two agents write the same file and one wins
 *   the contract is written down before the split, or the halves disagree
 *
 * args: {
 *   contract: string,          what the parts must agree on, verbatim in every prompt
 *   rules: string,             the repository rules, they will not read them otherwise
 *   parts:  [{ key, prompt }], one per disjoint file set
 *   checks: [{ key, prompt }], one per part, adversarial
 * }
 */
const DONE = {
  type: 'object',
  properties: {
    summary: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    unfinished: { type: 'array', items: { type: 'string' } },
  },
  required: ['summary', 'files'],
}

const VERDICT = {
  type: 'object',
  properties: {
    works: { type: 'boolean' },
    problems: { type: 'array', items: { type: 'string' } },
  },
  required: ['works', 'problems'],
}

const input = args ?? {}
const rules = input.rules ?? ''
const contract = input.contract ?? ''
const parts = input.parts ?? []
const checks = input.checks ?? []

if (parts.length === 0) throw new Error('build-and-verify needs at least one part')

phase('Build')

const built = await parallel(
  parts.map((part) => () =>
    agent(`${rules}\n${contract}\n\n${part.prompt}`, {
      label: `build:${part.key}`,
      phase: 'Build',
      schema: DONE,
      effort: 'high',
    }),
  ),
)

log(`${built.filter(Boolean).length} parts built, verifying each independently`)

phase('Verify')

const verdicts = await parallel(
  checks.map((check) => () =>
    agent(
      `${contract}\n\n${check.prompt}\n\nYou are checking work another agent just did. Try to break it. Prove every problem with a repro rather than an opinion, and say works=false if any check fails.`,
      { label: `verify:${check.key}`, phase: 'Verify', schema: VERDICT, effort: 'high' },
    ),
  ),
)

return { built: built.filter(Boolean), verified: verdicts.filter(Boolean) }
