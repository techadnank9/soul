import { z } from 'zod'
import { regionKeys } from './profile/regions.js'

/**
 * The wire contract, shared with the client.
 *
 * Validation at the HTTP boundary only. Route handlers parse and then hand
 * plain values to a service. No service reaches for a request object.
 */

export const submitEntry = z.object({
  text: z.string().min(1).max(8000),
  inputMode: z.enum(['voice', 'typed']),
  transcriptConfirmed: z.boolean(),
  durationMs: z.number().int().positive().max(600_000).optional(),
  localHour: z.number().int().min(0).max(23).optional(),
  /**
   * The handle /transcribe returned for how this entry sounded. Only a spoken
   * entry has one. The server checks it belongs to this student before it is
   * linked, so a guessed id links nothing.
   */
  toneId: z.string().uuid().optional(),

  /**
   * Written from the weather card on home. The card stays on the screen
   * every day until something is said to it, so the server has to know
   * when something was.
   */
  fromWeather: z.boolean().optional(),
})
export type SubmitEntry = z.infer<typeof submitEntry>

/**
 * What /transcribe returns. toneId is absent when the entry was heard but not
 * judged, which must never cost a student their transcript.
 */
export const transcribeResult = z.object({
  text: z.string(),
  toneId: z.string().uuid().optional(),
})
export type TranscribeResult = z.infer<typeof transcribeResult>

/**
 * How a recording sounded, from the model that listened to it.
 *
 * Both vocabularies are fixed so they can be counted across months. sounded is
 * the one free field and it describes this recording, never the person.
 */
export const toneEmotions = [
  'calm',
  'flat',
  'tired',
  'tense',
  'upset',
  'angry',
  'sad',
  'excited',
  'glad',
  'unsure',
  'rushed',
  'guarded',
] as const

export const toneIntents = [
  'venting',
  'deciding',
  'asking',
  'reporting',
  'rehearsing',
  'celebrating',
  'checking_in',
  'unsure',
] as const

export const voiceToneResult = z.object({
  emotion: z.enum(toneEmotions),
  intensity: z.number().min(0).max(1),
  intent: z.enum(toneIntents),
  sounded: z.string().min(1).max(160),
  confidence: z.number().min(0).max(1),
})
export type VoiceToneResult = z.infer<typeof voiceToneResult>

/**
 * Three shapes come back from a submission and the client must handle all
 * three. Held means consent did not cover this student and nothing left the
 * building. Help means the safety classifier flagged the entry and no
 * reflection was generated.
 */
export const submitResult = z.discriminatedUnion('state', [
  z.object({
    state: z.literal('reflected'),
    entryId: z.string().uuid(),
    line: z.string(),
  }),
  z.object({
    state: z.literal('help'),
    entryId: z.string().uuid(),
    heading: z.string(),
    body: z.string(),
    contacts: z.array(z.object({ label: z.string(), detail: z.string() })),
  }),
  z.object({
    state: z.literal('held'),
    entryId: z.string().uuid(),
  }),
])
export type SubmitResult = z.infer<typeof submitResult>

/**
 * The Mirror. Structured output, validated before display or storage. Free
 * prose is rejected rather than stored.
 */
export const mirrorResult = z.object({
  tension: z.string().min(1).max(400),
  underneath: z.string().min(1).max(400),
  question: z.string().min(1).max(200),
  offered: z.string().max(200).optional(),
  patternCandidate: z
    .object({
      candidateId: z.string().uuid(),
      proposal: z.string().min(1).max(400),
    })
    .optional(),
})
export type MirrorResult = z.infer<typeof mirrorResult>

export const createDecision = z.object({
  entryId: z.string().uuid(),
  offeredText: z.string().max(200).optional(),
  chosenText: z.string().min(1).max(200),
  horizonDays: z.number().int().min(1).max(30).default(3),
})

export const recordOutcome = z.object({
  decisionId: z.string().uuid(),
  whatHappened: z.string().max(2000).optional(),
  felt: z.enum(['lighter', 'same', 'worse']).optional(),
})

export const answerCandidate = z.object({
  candidateId: z.string().uuid(),
  answer: z.enum(['fits', 'not_the_same', 'later']),
  reason: z.string().max(500).optional(),
})

/**
 * The read side, one shape per screen.
 *
 * Weeks and days are bounded by the student's own timezone, never the
 * server's. Every one of these is scoped to the session student, which is why
 * none of them names a student anywhere.
 */
export const dayDate = z.iso.date()

/**
 * The week. Seven days always, Monday first, whether or not anything was
 * written in them. Themes are at most four, highest first, and a week with no
 * tags yet has none rather than placeholders.
 */
export const weekView = z.object({
  moments: z.number().int().min(0),

  /**
   * The line written from the baseline answers, shown while the week has
   * nothing of its own to divide. Null once there is.
   */
  opening: z.string().nullable(),

  /**
   * Whether the themes below came from the baseline answers rather than from
   * entries. The ring is drawn the same way; what is written under it is
   * not, because these have no entries behind them and no count to give.
   */
  themesFromAnswers: z.boolean(),

  themes: z
    .array(z.object({ name: z.string(), count: z.number().int() }))
    .max(4),
  days: z
    .array(
      z.object({
        date: dayDate,
        weekday: z.string().length(1),
        count: z.number().int().min(0),
      }),
    )
    .length(7),

  /**
   * What the student said they would do, once the day they named has come and
   * gone without an answer. Null on almost every week.
   */
  holding: z
    .object({
      decisionId: z.string().uuid(),
      chose: z.string(),
      horizon: z.string(),
    })
    .nullable(),
})
export type WeekView = z.infer<typeof weekView>

/**
 * A cue card, about something the student themselves said was coming up.
 *
 * about names the thing in the student's own terms. question is one thing they
 * can answer yes or no, drawn from what they wrote, so it is theirs rather
 * than advice, and under it the screen puts a box for anything they want to
 * say about it. A card that nothing in the entries points to is never made,
 * which is why a day usually has none, occasionally one, and rarely more.
 */
export const dayCard = z.object({
  id: z.string().uuid(),
  about: z.string(),
  question: z.string(),
  answered: z.boolean(),
})
export type DayCard = z.infer<typeof dayCard>

/** One day, entries in the order they were written, earliest first. */
export const dayView = z.object({
  date: dayDate,
  entries: z.array(
    z.object({
      id: z.string().uuid(),
      at: z.string(),
      text: z.string(),
      feeling: z.string().nullable(),
      trigger: z.string().nullable(),
    }),
  ),

  /**
   * Unanswered first. A day with none carries an empty array,
   * never null, so the screen has one shape to read rather than two.
   */
  // No cap. The count was never the point: a card exists where there is
  // something worth saying back about, which is usually nothing and
  // occasionally three. A limit here would have refused the third card of a
  // full week while letting through the thin one.
  cards: z.array(dayCard),
})
export type DayView = z.infer<typeof dayView>

export const cardId = z.string().uuid()

/**
 * Answering a cue card. Yes or no, and a box.
 *
 * answer is the whole of it. detail is what they wrote in the box, which is
 * usually nothing and is theirs either way: a yes can carry how they plan to
 * do it and a no can carry why not.
 *
 * horizonDays is the day the check back fires and it only means anything on a
 * yes, because a no books nothing. It is left optional so a client that has
 * nothing to say about when gets the same three days the Mirror path gives.
 */
export const answerCard = z.object({
  answer: z.enum(['yes', 'no']),
  detail: z.string().trim().max(500).optional(),
  horizonDays: z.number().int().min(1).max(30).default(3),
})
export type AnswerCard = z.infer<typeof answerCard>

/**
 * Patterns. Confirmed ones are the student's own words about themselves.
 * Forming ones are candidates the sweep proposed and the student has not
 * answered, and they are named as forming because nothing is a pattern until
 * the student says it is.
 *
 * lighter and heavier are the themes the student has already answered about,
 * split by what they answered. The word comes from outcomes.felt, which only
 * they set, so neither list is the app's reading of anything. A theme with no
 * outcome yet is in neither and stays what it was, a thing that keeps
 * returning.
 *
 * heavier is not a warning and nothing that reads it may turn it into one. It
 * holds what the student said left them heavier, in their theme's words, and a
 * screen that adds so maybe stop has said something the student did not.
 *
 * Every array is present and empty rather than absent, so a screen has one
 * shape to read on the first day and on the hundredth.
 */
const feltTheme = z.object({
  theme: z.string(),
  times: z.number().int(),
  lastAt: z.string(),
})

export const patternsView = z.object({
  reflections: z.number().int().min(0),
  lighter: z.array(feltTheme),
  heavier: z.array(feltTheme),
  confirmed: z.array(
    z.object({
      id: z.string().uuid(),
      theme: z.string(),
      supporting: z.number().int(),
      confirmedAt: z.string(),
    }),
  ),
  forming: z.array(
    z.object({
      id: z.string().uuid(),
      theme: z.string(),
      supporting: z.number().int(),
    }),
  ),
})
export type PatternsView = z.infer<typeof patternsView>

/**
 * The profile, given at first run.
 *
 * Every field is optional and they are sent as they are answered, so a student
 * who stops halfway keeps what they gave. displayName is a first name for the
 * app to use, capped short because anything longer is not one.
 *
 * A field sent as null empties it. That is different from a field left out,
 * which is untouched, and the difference is what lets the profile tab take an
 * answer back without a second endpoint.
 *
 * The timezone is not in this contract. It is derived from the region on the
 * server, never sent by the client.
 */
export const saveProfile = z.object({
  displayName: z.string().trim().min(1).max(40).nullable().optional(),
  place: z.string().trim().min(1).max(120).nullable().optional(),
  ageBand: z
    .enum(['under_13', '13_17', '18_24', '25_34', '35_49', '50_plus'])
    .nullable()
    .optional(),
  gender: z.enum(['male', 'female', 'nonbinary', 'not_said']).nullable().optional(),
  region: z.enum(regionKeys).nullable().optional(),

  /**
   * Exact coordinates, when the student shared their location. Sent together
   * or not at all, and sent as null to forget them.
   *
   * When they arrive the region and the timezone are derived from them and
   * whatever region the client thought it was is ignored, so a measured
   * location and a picked one cannot disagree.
   */
  latitude: z.number().min(-90).max(90).nullable().optional(),
  longitude: z.number().min(-180).max(180).nullable().optional(),
})
export type SaveProfile = z.infer<typeof saveProfile>

/**
 * Signing in with Apple.
 *
 * The bearer on this call is still the roster reference, because that is what
 * says which student the Apple account is about to be attached to. What comes
 * back is the session token every later call uses instead.
 */
export const appleSignIn = z.object({
  identityToken: z.string().min(1).max(8000),
  appleUserId: z.string().min(1).max(200),
})
export type AppleSignIn = z.infer<typeof appleSignIn>

/**
 * Email sign in. The address is lowercased and trimmed at the boundary so the
 * same address typed two ways is one account. The code is six digits.
 */
export const emailStart = z.object({
  email: z.string().trim().toLowerCase().email().max(254),
})
export const emailVerify = z.object({
  email: z.string().trim().toLowerCase().email().max(254),
  code: z.string().trim().regex(/^\d{6}$/),
})

export const appleSession = z.object({
  token: z.string(),
  expiresAt: z.string(),
})
export type AppleSession = z.infer<typeof appleSession>

/**
 * One day with something in it, for the list of days.
 *
 * feelings are the distinct ones on that day's tags, so a day can be told
 * apart before it is opened.
 */
export type DayCount = {
  date: string
  weekday: string
  count: number
  feelings: string[]
}

/** What the tagger must return. Anything else is discarded. */
export const taggerResult = z.object({
  trigger: z.string().max(120).nullable(),
  feeling: z.string().max(120).nullable(),
  coping: z.string().max(120).nullable(),
  domain: z.string().max(120).nullable(),
  confidence: z.number().min(0).max(1),
})

/** What the safety classifier must return. */
export const safetyResult = z.object({
  riskLevel: z.enum(['none', 'low', 'medium', 'high']),
  categories: z.array(z.string().max(60)).max(8),
})

/**
 * What the fact extractor must return. Anything else is discarded.
 *
 * Every fact is three parts and a sentence, all in the student's words. The
 * sentence is what the Mirror reads back, so it is the one that carries the
 * register. No dashes, for the same reason as everywhere else a person reads.
 */
const NO_DASH = /^[^-‐-―−]*$/

export const factsResult = z.object({
  facts: z
    .array(
      z.object({
        subject: z.string().trim().min(1).max(60).regex(NO_DASH),
        predicate: z.string().trim().min(1).max(60).regex(NO_DASH),
        object: z.string().trim().min(1).max(160).regex(NO_DASH),
        sentence: z.string().trim().min(1).max(240).regex(NO_DASH),
        confidence: z.number().min(0).max(1),
      }),
    )
    .max(8),
})
export type FactsResult = z.infer<typeof factsResult>

/**
 * What the nightly consolidation must return. Anything else is discarded.
 *
 * At most three observations, each drawn from two or more of the numbered
 * facts it was shown. The numbers are checked in code against the list that
 * was sent, so an observation that points at a fact that was not there is
 * dropped rather than written with nothing behind it. Same register as a
 * fact: a situation in the person's words, and no dashes.
 */
export const consolidateResult = z.object({
  observations: z
    .array(
      z.object({
        subject: z.string().trim().min(1).max(60).regex(NO_DASH),
        predicate: z.string().trim().min(1).max(60).regex(NO_DASH),
        object: z.string().trim().min(1).max(160).regex(NO_DASH),
        sentence: z.string().trim().min(1).max(240).regex(NO_DASH),
        drawnFrom: z.array(z.number().int().positive()).min(2).max(40),
        confidence: z.number().min(0).max(1),
      }),
    )
    .max(3),
})
export type ConsolidateResult = z.infer<typeof consolidateResult>

/**
 * The graph. One person as rows with ids pointing at other rows, which is
 * the shape docs/memory.md says the memory should have and the reason it
 * lives in our database.
 *
 * Every node has an id and a type, and the rest depends on the type. Edges
 * are pairs of node ids. The person node is the root and has an edge to
 * everything, so a screen can lay it out from one place; the other edges
 * are the ones that carry meaning: a decision to what came of it, a fact to
 * the person it names. Every fact node carries its entry ids so it can be
 * opened to the words behind it, the property the doc names as the reason
 * for holding the memory ourselves.
 */
export const graphNode = z.discriminatedUnion('type', [
  z.object({ id: z.string().uuid(), type: z.literal('person'), name: z.string().nullable() }),
  z.object({
    id: z.string().uuid(),
    type: z.literal('fact'),
    sentence: z.string(),
    tier: z.number().int().min(0),
    validFrom: z.string(),
    entryIds: z.array(z.string().uuid()),
  }),
  z.object({ id: z.string().uuid(), type: z.literal('person_named'), name: z.string() }),
  z.object({ id: z.string().uuid(), type: z.literal('pattern'), theme: z.string() }),
  z.object({
    id: z.string().uuid(),
    type: z.literal('decision'),
    chose: z.string(),
    status: z.enum(['open', 'closed']),
  }),
  z.object({
    id: z.string().uuid(),
    type: z.literal('outcome'),
    felt: z.enum(['lighter', 'same', 'worse']).nullable(),
  }),
])
export type GraphNode = z.infer<typeof graphNode>

export const graphEdge = z.object({ from: z.string().uuid(), to: z.string().uuid() })
export type GraphEdge = z.infer<typeof graphEdge>

export const graphView = z.object({
  nodes: z.array(graphNode),
  edges: z.array(graphEdge),
})
export type GraphView = z.infer<typeof graphView>

/**
 * The answers behind the last screen of first run. The questions live in the
 * app, so they come with the answers rather than being held twice.
 */
export const welcomeAnswers = z.object({
  name: z.string().trim().min(1).max(40).optional(),
  answers: z
    .array(
      z.object({
        question: z.string().trim().min(1).max(200),
        answer: z.string().trim().min(1).max(120),
      }),
    )
    .min(1)
    .max(20),
})
export type WelcomeAnswers = z.infer<typeof welcomeAnswers>

/**
 * Two sentences, and three or four things that look likely to keep coming
 * up. The themes fill the week ring until their own entries can.
 */
export const welcomeResult = z.object({
  line: z.string().trim().min(1).max(320),
  themes: z
    .array(
      z.object({
        name: z.string().trim().min(1).max(28),
        weight: z.number().int().min(1).max(5),
      }),
    )
    .min(1)
    .max(4),
})

/**
 * The card at the top of home. The phone says what the sky is doing and the
 * service answers with one question that uses it.
 */
export const weatherAsk = z.object({
  condition: z.string().trim().min(1).max(40),
  degrees: z.number().int().min(-100).max(150),
  fahrenheit: z.boolean(),
  daylight: z.boolean(),
  place: z.string().trim().max(80).optional(),
})
export type WeatherAsk = z.infer<typeof weatherAsk>

export const weatherQuestion = z.object({
  question: z.string().trim().min(1).max(140),
})

