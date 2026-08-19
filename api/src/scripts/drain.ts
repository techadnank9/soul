import { tick } from '../jobs/runner.js'

/**
 * Runs the queue until it is empty and exits. The runner itself loops forever,
 * which is right in production and useless in a test.
 */
let worked = true
let count = 0
while (worked) {
  worked = await tick()
  if (worked) count++
}
console.log(`drained ${count} jobs`)
process.exit(0)
