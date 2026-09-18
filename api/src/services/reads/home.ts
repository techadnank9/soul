import { asStudent, type Session } from '../../session.js'
import { ISO_INSTANT, studentZone } from './rules.js'
import { BASELINE_SET, SECTION_TITLES_PLAIN, answeredBySection, sectionLine, type BaselineSection } from './baseline_set.js'

/**
 * Home. Everything below the question card, in one read. Decision 279.
 *
 * The screen used to read the week, which carried a ring of themes that was
 * empty for nearly everyone. It now reads this: what the person said about
 * how they decide, filled in by what they have written; the people and
 * things around them; what is waiting for an answer; what is coming; what
 * they decided; and the week's three sentences. Every card is absent when
 * empty, so nothing on the screen is a promise the app cannot keep.
 *
 * The wire shape is the type below. The Dart mirror is HomeView in
 * app/lib/api/models.dart, changed in the same commit.
 */
export type HomeTile = {
  section: BaselineSection
  /** What the pair is about, in plain words: under pressure, what you wait for. */
  title: string
  /** The two answers as one or two plain sentences in the second person. */
  line: string
  answers: string[]
  seen: number
  entryIds: string[]
  /** The day of the newest entry behind it, YYYY-MM-DD in their zone. */
  lastOn: string | null
}

export type HomeNode = {
  id: string
  kind: 'person' | 'thing'
  name: string
  weight: number
}

export type HomeView = {
  moments: number
  opening: string | null
  tiles: HomeTile[]
  map: { nodes: HomeNode[]; edges: { from: string; to: string }[] }
  leftOff:
    | { kind: 'decision'; id: string; text: string; since: string }
    | { kind: 'card'; id: string; text: string; since: string }
    | null
  coming: { on: string; said: string; kind: 'reminder' | 'decision' }[]
  people: { id: string; name: string; times: number }[]
  decisions: { id: string; chose: string; on: string; felt: 'lighter' | 'same' | 'worse' | null }[]
  week: { from: string; moments: number; lines: string[] } | null
}

export async function home(session: Session): Promise<HomeView> {
  return asStudent(session, async (tx) => {
    const zone = await studentZone(tx, session)

    const [countRow] = await tx<{ moments: number }[]>`
      select count(*)::int as moments
      from entries
      where student_id = ${session.studentId}
        and (created_at at time zone ${zone})::date > (now() at time zone ${zone})::date - 7`

    const [student] = await tx<{ opening: string | null }[]>`
      select opening from students where id = ${session.studentId}`

    // The tiles: what they said at first run, and how many of their own
    // entries have shown it since.
    const answers = await tx<{ questionIndex: number; choiceIndex: number }[]>`
      select question_index as "questionIndex", choice_index as "choiceIndex"
      from baseline_answers
      where student_id = ${session.studentId} and set_version = ${BASELINE_SET}
      order by question_index`
    const sightings = await tx<{ section: string; entryId: string; on: string }[]>`
      select ss.section, ss.entry_id as "entryId",
             to_char(e.created_at at time zone ${zone}, 'YYYY-MM-DD') as "on"
      from section_sightings ss
      join entries e on e.id = ss.entry_id
      where ss.student_id = ${session.studentId}
      order by e.created_at desc`
    const tiles: HomeTile[] = answeredBySection(answers).map((s) => {
      const mine = sightings.filter((row) => row.section === s.section)
      return {
        section: s.section,
        title: SECTION_TITLES_PLAIN[s.section],
        line: sectionLine(s.section, s.fragments),
        answers: s.shorts,
        seen: mine.length,
        entryIds: mine.map((row) => row.entryId).slice(0, 20),
        lastOn: mine[0]?.on ?? null,
      }
    })

    // The map: people by how often they have come up lately, and the
    // subjects of the open observations the nightly consolidation wrote.
    const people = await tx<{ id: string; name: string; weight: number; times: number }[]>`
      select p.id, p.name,
             count(ep.id) filter (where ep.created_at > now() - interval '14 day')::int as weight,
             count(ep.id) filter (where ep.created_at > now() - interval '7 day')::int as times
      from people p
      left join entry_people ep on ep.person_id = p.id and ep.student_id = ${session.studentId}
      where p.student_id = ${session.studentId}
      group by p.id, p.name
      order by weight desc, p.last_seen_at desc nulls last
      limit 8`
    const things = await tx<{ id: string; name: string; subject: string; object: string }[]>`
      select id, subject as name, subject, object
      from facts
      where student_id = ${session.studentId}
        and valid_to is null and retired_at is null and tier >= 1
      order by valid_from desc
      limit 4`
    const byName = new Map(people.map((p) => [p.name.trim().toLowerCase(), p.id]))
    // A fact about the person themselves has them as its subject, and "I"
    // is not a thing on the map. Only a named thing earns a node.
    const self = new Set(['i', 'me', 'my', 'myself', 'we', 'you', 'they', 'it'])
    const nodes: HomeNode[] = [
      ...people.map((p) => ({ id: p.id, kind: 'person' as const, name: p.name, weight: p.weight })),
      ...things
        .filter((t) => !byName.has(t.subject.trim().toLowerCase()))
        .filter((t) => !self.has(t.subject.trim().toLowerCase()) && t.subject.trim().length > 2)
        .map((t) => ({ id: t.id, kind: 'thing' as const, name: t.name, weight: 1 })),
    ].slice(0, 9)
    const edges: { from: string; to: string }[] = []
    for (const t of things) {
      for (const word of [t.subject, t.object]) {
        const id = byName.get(word.trim().toLowerCase())
        if (id && nodes.some((n) => n.id === t.id)) edges.push({ from: t.id, to: id })
      }
    }

    // What is waiting for an answer: the oldest decision past its day with
    // no outcome (the check back), else the oldest cue card whose time has
    // come.
    const [holding] = await tx<{ id: string; text: string; since: string }[]>`
      select d.id, d.chosen_text as text, to_char(d.horizon at time zone 'UTC', ${ISO_INSTANT}) as since
      from decisions d
      where d.student_id = ${session.studentId} and d.status = 'open' and d.horizon <= now()
        and not exists (select 1 from outcomes o where o.decision_id = d.id)
      order by d.horizon limit 1`
    const [card] = holding
      ? []
      : await tx<{ id: string; text: string; since: string }[]>`
        select id, question as text, to_char(created_at at time zone 'UTC', ${ISO_INSTANT}) as since
        from cue_cards
        where student_id = ${session.studentId} and answered_at is null
          and (deferred_until is null or deferred_until <= now())
        order by created_at limit 1`
    const leftOff = holding
      ? { kind: 'decision' as const, ...holding }
      : card
        ? { kind: 'card' as const, ...card }
        : null

    const coming = await tx<{ on: string; said: string; kind: 'reminder' | 'decision' }[]>`
      select * from (
        select to_char(due_at at time zone ${zone}, 'YYYY-MM-DD') as "on", said, 'reminder' as kind, due_at as at
        from reminders
        where student_id = ${session.studentId} and cancelled_at is null
          and due_at > now() and due_at < now() + interval '14 day'
        union all
        select to_char(horizon at time zone ${zone}, 'YYYY-MM-DD'), chosen_text, 'decision', horizon
        from decisions
        where student_id = ${session.studentId} and status = 'open'
          and horizon > now() and horizon < now() + interval '14 day'
      ) ahead
      order by at
      limit 4`

    const decisions = await tx<{ id: string; chose: string; on: string; felt: 'lighter' | 'same' | 'worse' | null }[]>`
      select d.id, d.chosen_text as chose,
             to_char(d.created_at at time zone ${zone}, 'YYYY-MM-DD') as "on",
             (select o.felt::text from outcomes o where o.decision_id = d.id and o.felt is not null
              order by coalesce(o.responded_at, o.created_at) desc limit 1) as felt
      from decisions d
      where d.student_id = ${session.studentId} and d.status in ('open', 'closed')
      order by d.created_at desc
      limit 3`

    const [week] = await tx<{ from: string; moments: number; lines: string[] }[]>`
      select to_char(week_start, 'YYYY-MM-DD') as "from", moments, lines
      from week_notes
      where student_id = ${session.studentId}
      order by week_start desc
      limit 1`

    return {
      moments: countRow?.moments ?? 0,
      opening: student?.opening ?? null,
      tiles,
      map: { nodes, edges: edges.map(({ from, to }) => ({ from, to })) },
      leftOff,
      coming: coming.map(({ on, said, kind }) => ({ on, said, kind })),
      people: people
        .filter((p) => p.times > 0)
        .slice(0, 6)
        .map((p) => ({ id: p.id, name: p.name, times: p.times })),
      decisions,
      week: week ?? null,
    }
  })
}
