import { themesNeedingVerdict } from './themes.js'
import { judgeTheme } from './judge.js'

/**
 * The verdict sweep. Every theme that needs one, judged, one at a time.
 *
 * It runs from the job runner straight after the nightly pattern sweep, on the
 * same chain, so the one thing that has to be running for verdicts to keep
 * being written is the runner. Nothing here is on a request path and nothing a
 * student does waits for it.
 *
 * One theme at a time rather than in parallel. This is the slowest call in the
 * system after cue cards, it runs when nobody is waiting, and a night that
 * takes an hour costs nothing while a burst of two hundred calls at once costs
 * a rate limit and a night with no verdicts at all.
 *
 * A theme that fails is left alone. It has no row, so it is in neither
 * section, and the next run picks it up again. One student's failure is not
 * allowed to end the run for everybody else, which is why the loop catches
 * rather than throws.
 */
export async function sweepVerdicts(): Promise<{ judged: number; skipped: number }> {
  const themes = await themesNeedingVerdict()
  let judged = 0
  let skipped = 0

  for (const theme of themes) {
    try {
      if (await judgeTheme(theme)) judged += 1
      else skipped += 1
    } catch (error) {
      skipped += 1
      console.error(`verdict failed for ${theme.theme}: ${(error as Error).message}`)
    }
  }

  return { judged, skipped }
}

if (process.argv[1]?.endsWith('sweep.ts')) {
  sweepVerdicts()
    .then(({ judged, skipped }) => {
      console.log(`${judged} verdicts written, ${skipped} left without one`)
      process.exit(0)
    })
    .catch((error) => {
      console.error(error)
      process.exit(1)
    })
}
