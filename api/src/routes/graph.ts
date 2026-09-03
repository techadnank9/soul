import { Hono } from 'hono'
import { asStudent, type Session } from '../session.js'
import { ISO_INSTANT } from '../services/reads/rules.js'
import type { GraphEdge, GraphNode, GraphView } from '../contracts.js'

/**
 * The graph. Step six of docs/memory.md.
 *
 * One route that returns the session person as nodes and edges: the person,
 * every open fact, everybody they have named, every confirmed pattern, every
 * open or closed decision, and every outcome. This is what the app's map tab
 * reads, and what a later admin screen will read, so it is the one place the
 * shape is decided. The contract is graphView in contracts.ts.
 *
 * It is a read, and it is shaped like every other read: inside asStudent so
 * row level security is scoping it and not only the where clause, no id on
 * the path, and nothing here is written. Every fact node carries its entry
 * ids so a screen can open it to the words behind it.
 *
 * Edges. The person has an edge to every other node, so a layout can start
 * from one place. A decision has an edge to each of its outcomes. A fact has
 * an edge to a named person when its subject or its object is that person's
 * name, compared case insensitively and as a whole, which is how the
 * extractor writes them.
 */
type Vars = { Variables: { session: Session } }

export const graph = new Hono<Vars>()

graph.get('/graph', async (c) => {
  return c.json(await readGraph(c.get('session')))
})

type PersonRow = { id: string; name: string | null }
type FactRow = { id: string; sentence: string; tier: number; validFrom: string; subject: string; object: string; entryIds: string[] }
type NamedRow = { id: string; name: string }
type PatternRow = { id: string; theme: string }
type DecisionRow = { id: string; chose: string; status: 'open' | 'closed' }
type OutcomeRow = { id: string; decisionId: string; felt: 'lighter' | 'same' | 'worse' | null }

export async function readGraph(session: Session): Promise<GraphView> {
  return asStudent(session, async (tx) => {
    const [person, factRows, named, patterns, decisionRows, outcomeRows] = await Promise.all([
      tx<PersonRow[]>`
        select id, display_name as "name"
        from students
        where id = ${session.studentId}
        limit 1`,

      // Open means valid_to and retired_at are both null, the same test the
      // context builder uses. Both tiers, oldest first.
      tx<FactRow[]>`
        select
          id,
          sentence,
          tier,
          to_char(valid_from at time zone 'UTC', ${ISO_INSTANT}) as "validFrom",
          subject,
          object,
          entry_ids as "entryIds"
        from facts
        where student_id = ${session.studentId}
          and valid_to is null
          and retired_at is null
        order by valid_from, created_at`,

      tx<NamedRow[]>`
        select id, name
        from people
        where student_id = ${session.studentId}
        order by last_seen_at desc nulls last, name`,

      tx<PatternRow[]>`
        select id, theme
        from confirmed_patterns
        where student_id = ${session.studentId}
          and removed_at is null
        order by confirmed_at`,

      // Open and closed. An abandoned decision is one they walked away from
      // and it is not part of the picture of what they did.
      tx<DecisionRow[]>`
        select id, chosen_text as "chose", status::text as "status"
        from decisions
        where student_id = ${session.studentId}
          and status in ('open', 'closed')
        order by created_at`,

      tx<OutcomeRow[]>`
        select o.id, o.decision_id as "decisionId", o.felt::text as "felt"
        from outcomes o
        join decisions d on d.id = o.decision_id
        where o.student_id = ${session.studentId}
          and d.student_id = ${session.studentId}
          and d.status in ('open', 'closed')
        order by o.created_at`,
    ])

    const root = person[0]
    if (!root) return { nodes: [], edges: [] }

    const nodes: GraphNode[] = [{ id: root.id, type: 'person', name: root.name }]
    const edges: GraphEdge[] = []

    const add = (node: GraphNode) => {
      nodes.push(node)
      edges.push({ from: root.id, to: node.id })
    }

    for (const f of factRows) {
      add({
        id: f.id,
        type: 'fact',
        sentence: f.sentence,
        tier: f.tier,
        validFrom: f.validFrom,
        entryIds: f.entryIds,
      })
    }
    for (const p of named) add({ id: p.id, type: 'person_named', name: p.name })
    for (const p of patterns) add({ id: p.id, type: 'pattern', theme: p.theme })
    for (const d of decisionRows) add({ id: d.id, type: 'decision', chose: d.chose, status: d.status })
    for (const o of outcomeRows) add({ id: o.id, type: 'outcome', felt: o.felt })

    for (const o of outcomeRows) edges.push({ from: o.decisionId, to: o.id })

    // A fact to the person it names. The extractor writes the subject or the
    // object as the name the student used, and the people job writes the
    // same name, so a whole match is the right test and a substring is not:
    // Sam inside Samira is not Sam.
    const byName = new Map(named.map((p) => [p.name.trim().toLowerCase(), p.id]))
    for (const f of factRows) {
      const hits = new Set<string>()
      for (const word of [f.subject, f.object]) {
        const id = byName.get(word.trim().toLowerCase())
        if (id) hits.add(id)
      }
      for (const id of hits) edges.push({ from: f.id, to: id })
    }

    return { nodes, edges }
  })
}
