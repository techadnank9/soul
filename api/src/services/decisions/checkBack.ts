import { eq } from 'drizzle-orm'
import { db, decisions } from '../../db.js'
import type { Session } from '../../session.js'

/**
 * The check back, days later.
 *
 * Neutral wording. It asks what happened, it does not ask whether they
 * succeeded. A check back that reads as a test turns the product into
 * something that keeps score.
 *
 * Delivery is a notification once notifications exist. Until then the open
 * decision is shown on home when the student next opens the app, which is why
 * this only has to mark the decision as due.
 */
export async function checkBack(decisionId: string, _session: Session): Promise<void> {
  const rows = await db
    .select({ status: decisions.status })
    .from(decisions)
    .where(eq(decisions.id, decisionId))
    .limit(1)

  const decision = rows[0]
  if (!decision || decision.status !== 'open') return

  // Left open on purpose. Home surfaces every open decision past its horizon,
  // and an unanswered one is written as ignored rather than quietly dropped.
}
