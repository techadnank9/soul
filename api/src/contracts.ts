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

  /**
   * The spoken introduction at first run. The entry is stored like any
   * other and this marks it as the one the profile points at.
   */
  introduction: z.boolean().optional(),
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
 * two. Held means consent did not cover this student and nothing left the
 * building. There is no third state: the safety classifier records what it
 * reads and never stops a reflection, decision 276.
 */
export const submitResult = z.discriminatedUnion('state', [
  z.object({
    state: z.literal('reflected'),
    entryId: z.string().uuid(),
    line: z.string(),
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
/**
 * What the Mirror must return. The three parts, and the question.
 *
 * happened, meant and next are the founder's own sentence for what this
 * product is: what happened, what it was taken to mean, and what was done
 * about it. Separating them is the whole move. It shows that only the first
 * is a fact, and the second is the sentence somebody did not write
 * themselves, which is the reason to open this instead of a journal.
 *
 * `meant` and `next` are nullable and they are meant to be null often. Most
 * entries say what happened and never say what was concluded or what was
 * done. A fixed three part template forces a model to invent the middle,
 * and an invented claim about somebody's interior is the worst thing this
 * product can produce. Decision 297.
 *
 * `happened` stays short and close to their words. It is scaffolding for
 * the seam, not content: a line that summarises the entry is this product
 * failing at the only thing it is for, and two thirds of this shape is
 * restatement. What earns the screen is the labels and the question.
 */
export const mirrorWritten = z.object({
  happened: z.string().min(1).max(300),
  meant: z.string().max(300).nullable().default(null),
  next: z.string().max(300).nullable().default(null),
  question: z.string().min(1).max(200),
  offered: z.string().max(200).optional(),
})
export type MirrorWritten = z.infer<typeof mirrorWritten>

export const mirrorReflection = z.object({
  /** The three parts. Decision 297. */
  happened: z.string().max(300).optional(),
  meant: z.string().max(300).nullable().optional(),
  next: z.string().max(300).nullable().optional(),
  /**
   * What a build before decision 297 reads. Filled from the three parts on
   * the way out so an app in somebody's pocket today still has a line under
   * its question. Both go when nobody is on such a build.
   */
  tension: z.string().min(1).max(400),
  underneath: z.string().min(1).max(400),
  question: z.string().min(1).max(200),
  offered: z.string().max(200).optional(),
  /**
   * The offer, when one is waiting. Not part of the reflection and never
   * rendered inside it: the breakdown is the whole of what a moment gets
   * back, and this is a separate thing the app asks afterwards.
   *
   * The moments are the student's own words with their dates, so the yes or
   * no is answered against what they actually wrote rather than against a
   * sentence about them. Decision 290.
   */
  patternCandidate: z
    .object({
      candidateId: z.string().uuid(),
      proposal: z.string().min(1).max(400),
      moments: z
        .array(
          z.object({
            entryId: z.string().uuid(),
            at: z.string(),
            said: z.string().min(1).max(200),
          }),
        )
        .max(3)
        .default([]),
    })
    .optional(),
})
export type MirrorReflection = z.infer<typeof mirrorReflection>

/**
 * What the route returns. Reflected carries the model's answer. Fallback is
 * what the student gets when the model could not answer: one plain question,
 * nothing asserted, and the entry stands as it was.
 */
export const mirrorResult = z.discriminatedUnion('state', [
  mirrorReflection.extend({ state: z.literal('reflected') }),
  z.object({ state: z.literal('fallback'), question: z.string().min(1).max(200) }),
])
export type MirrorResult = z.infer<typeof mirrorResult>

export const createDecision = z.object({
  entryId: z.string().uuid(),
  offeredText: z.string().max(200).optional(),
  chosenText: z.string().min(1).max(200),
  horizonDays: z.number().int().min(1).max(30).default(3),
})

export const recordOutcome = z.object({
  decisionId: z.string().uuid(),
  whatHappened: z.string().max(8000).optional(),
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

  /**
   * Moments in the week that are in no theme above: untagged, tagged below
   * the confidence floor, or under a feeling past the fourth. The four
   * counts and this one add up to moments. Zero while the themes come from
   * the baseline answers, which have no entries behind them.
   */
  unsorted: z.number().int().min(0),
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
  // The same room an entry gets. Five hundred characters was a typed
  // answer's worth, and a spoken one fills that in a minute of talking,
  // which is a person being cut off mid sentence by a number nobody chose
  // for a reason.
  detail: z.string().trim().max(8000).optional(),
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

/** Yes, no and not sure, as equals. Decision 275. */
export const answerNoticing = z.object({
  noticingId: z.string().uuid(),
  answer: z.enum(['yes', 'no', 'unsure']),
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
/**
 * What a person says they came for, asked on the two screens between signing
 * in and home.
 *
 * The area is a part of life and the reason is why now. They are stored as
 * keys rather than as the words on the screen, so the wording can be changed
 * without rewriting rows, and the words themselves live in the app beside
 * every other question.
 *
 * Not sure yet and no reason in particular are answers. A question everybody
 * has to answer needs a true way to say nothing, or the answer it collects is
 * whichever row was least wrong.
 */
export const intentAreaKeys = [
  'school_or_work',
  'people_close',
  'sleep_and_food',
  'my_time',
  'avoiding',
  'not_sure',
] as const

export const intentReasonKeys = [
  'keeps_happening',
  'still_in_it',
  'want_to_see',
  'no_reason',
] as const

/**
 * The theme the week ring shows first for each area, in the app's own words
 * rather than the model's.
 *
 * The ring is filled by the themes the welcome call named from the baseline
 * answers, and until somebody has written enough for the tagger to name one
 * of their own this puts what they said they came for at the front of it.
 * Not sure yet adds nothing, because a ring is not the place to say so.
 */
export const intentAreaTheme: Record<string, string | null> = {
  school_or_work: 'School or work',
  people_close: 'People close to me',
  sleep_and_food: 'Sleep and food',
  my_time: 'My time',
  avoiding: 'What I avoid',
  not_sure: null,
}

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

  /**
   * What they came for. Both are emptiable like every other field here.
   */
  intentArea: z.enum(intentAreaKeys).nullable().optional(),
  intentReason: z.enum(intentReasonKeys).nullable().optional(),
})
export type SaveProfile = z.infer<typeof saveProfile>

/**
 * What GET /baseline returns: the answers held for the current set, one per
 * question answered, in question order. A question that was skipped is
 * simply absent.
 */
export const baselineHeld = z.object({
  setVersion: z.string(),
  answers: z.array(
    z.object({
      questionIndex: z.number().int().min(0),
      choiceIndex: z.number().int().min(0),
    }),
  ),
})
export type BaselineHeld = z.infer<typeof baselineHeld>

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

/**
 * Signing in by text. The number is E.164, which is a plus and up to
 * fifteen digits, because that is the only shape a carrier understands and
 * the client has already put it in that shape.
 */
export const phoneStart = z.object({
  phone: z.string().trim().regex(/^\+[1-9]\d{7,14}$/),
})
export const phoneVerify = z.object({
  phone: z.string().trim().regex(/^\+[1-9]\d{7,14}$/),
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
/**
 * What somebody did about it, from a closed list.
 *
 * This is the one field a pattern is counted on, and it is closed for that
 * reason. Free text cannot be counted: three entries that are obviously the
 * same thing to a person came back as "went quiet and said nothing", "said
 * nothing again" and "let it go", which group by exact match into three
 * themes of one entry each and therefore into no pattern at all. Every
 * pattern in this product was waiting on a string collision that real
 * entries never produce. Decision 259.
 *
 * A closed list keeps the counting in SQL, which is the thing decision 004
 * exists to protect: we can always show the exact entries behind a claim
 * because a claim is a group by, not a judgement.
 *
 * The words are what somebody reads at the head of a pattern, so they are
 * written to read that way. They are the demo seed's own vocabulary, which
 * was written as though this list already existed.
 */
export const copingWays = [
  'went quiet',
  'said it directly',
  'avoided it',
  'put it off',
  'agreed anyway',
  'asked for help',
  'pushed back',
  'made it smaller',
  'carried on',
  'did it anyway',
] as const

/**
 * What they took it to mean. The second closed list, and the one the product
 * exists for.
 *
 * `coping` is what they did. This is what they concluded, and it is where a
 * pattern worth showing somebody usually lives: a person who avoids three
 * different things has a habit, and a person who reads three different
 * silences as their own fault has something they could actually change.
 *
 * Closed for the same reason coping is closed, and the reason is written in
 * decision 259: free text never groups. Three entries that plainly said the
 * same thing came back as three phrasings and grouped into three themes of
 * one.
 *
 * Every line is a sentence somebody would say in their own head, in the
 * first person, about one moment. Not a kind of person and not a word from a
 * clinic. There is no word here for a distortion, a bias or a style of
 * thinking, and none is ever to be added: naming the thought is the product,
 * naming the thinker is the thing this product refuses to do.
 */
export const meaningsTaken = [
  'it was my fault',
  'they are angry with me',
  'I am in trouble',
  'they do not want me there',
  'they will find out I cannot do it',
  'nothing I do changes it',
  'it is mine to fix',
  'I could not say no',
  'it is going to go wrong',
  'everyone else is fine',
  'it was not a big deal',
  'it was not fair',
] as const

/**
 * A list from a model, where one bad item costs only itself.
 *
 * Every list a model returns is a list of things that can each be wrong on
 * their own. A schema that fails whole turns one malformed item into a lost
 * reply, and the cost is never the item: it is the entry that is never
 * tagged, the reminder never booked, the six jobs that never run.
 *
 * This has now been the cause four times. A fact whose object was a dash
 * (285), a tagger key the model omitted and a word off a closed list (301),
 * and a reminder with a malformed time (304). Rather than a fifth patch,
 * every list parsed from a model goes through here.
 *
 * It does not soften what an item has to be. The item schema is unchanged,
 * so nothing reaches the database that would not have reached it before.
 * What changes is how far one bad item reaches.
 */
export function forgivingList<T extends z.ZodTypeAny>(item: T, max: number) {
  return z.preprocess(
    (value) =>
      Array.isArray(value) ? value.filter((row) => item.safeParse(row).success) : value,
    z.array(item).max(max),
  )
}

/**
 * What the tagger must return.
 *
 * Every field is nullish rather than nullable: a key the model left out
 * reads as null instead of failing the whole reply. It threw on a real
 * entry with `trigger: expected string, received undefined`, and the cost
 * of that is not the trigger. It is the coping and the meaning too, so the
 * entry is never counted toward a pattern, and the four jobs the tagger
 * books never run. A model that omits a key it had nothing for is being
 * reasonable. Decision 301.
 */
export const taggerResult = z.object({
  trigger: z.string().max(120).nullish().default(null),
  feeling: z.string().max(120).nullish().default(null),
  /**
   * A word off the list reads as null rather than failing the reply.
   *
   * The list stays closed: nothing off it is ever stored, and the counting
   * is unchanged. What changes is the cost of a model reaching for a word
   * that is not there. It used to lose the trigger, the feeling, the meaning
   * and the four jobs the tagger books as well.
   */
  coping: z.enum(copingWays).nullish().catch(null).default(null),
  /** What they took it to mean, one of the closed list, or null. */
  meaning: z.enum(meaningsTaken).nullish().catch(null).default(null),
  domain: z.string().max(120).nullish().default(null),
  confidence: z.number().min(0).max(1).default(0.5),
  /// Which of the five ways of deciding this entry is plainly an instance
  /// of, when the tagger was told them. Empty for most entries. Decision 279.
  shows: z.array(z.string().max(40)).max(5).default([]),
})

/** What the safety classifier must return. */
export const safetyResult = z.object({
  riskLevel: z.enum(['none', 'low', 'medium', 'high']),
  categories: forgivingList(z.string().max(60), 8),
})

/**
 * What the fact extractor must return. Anything else is discarded.
 *
 * Every fact is three parts and a sentence, all in the student's words. The
 * sentence is what the Mirror reads back, so it is the one that carries the
 * register. No dashes, for the same reason as everywhere else a person reads.
 */
const NO_DASH = /^[^-‐-―−]*$/

/**
 * What somebody said they would do, at a time they named.
 *
 * `at` is their own local time with no zone on it, because the model is told
 * what time it is where they are and answers in that. The service turns it
 * into an instant using the zone on their row, so a phone that has since
 * moved country still rings at the hour they meant.
 *
 * Almost every entry returns an empty list, which is the correct answer for
 * somebody describing their day.
 */
export const remindersResult = z.object({
  reminders: forgivingList(
    z.object({
      at: z.string().regex(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$/),
      said: z.string().trim().min(1).max(200),
    }),
    4,
  ),
})
export type RemindersResult = z.infer<typeof remindersResult>

/**
 * The reminders a phone has not scheduled yet. Only what is still ahead:
 * one that has already rung is the notification's job, not this list's.
 */
export const reminderView = z.object({
  id: z.string(),
  dueAt: z.string(),
  said: z.string(),
})
export type ReminderView = z.infer<typeof reminderView>

/**
 * One fact, exactly as it has to arrive to be written.
 *
 * Named on its own so a single bad item can be told apart from a bad reply.
 */
const factItem = z.object({
  subject: z.string().trim().min(1).max(60).regex(NO_DASH),
  predicate: z.string().trim().min(1).max(60).regex(NO_DASH),
  object: z.string().trim().min(1).max(160).regex(NO_DASH),
  sentence: z.string().trim().min(1).max(240).regex(NO_DASH),
  confidence: z.number().min(0).max(1),
})

/**
 * The facts in one entry. An item that does not hold is dropped, and the
 * rest of the list is kept.
 *
 * One bad item used to fail the whole call. The reply that showed it was a
 * fact whose object was a dash, which `undash` turns into an empty string
 * and `min(1)` then refuses, so `parseStructured` threw, every provider was
 * tried and threw the same way, and the job burned its five attempts. The
 * cost of that was never one fact. It was every fact in the entry, and the
 * entries around it waiting behind a job that could not finish.
 *
 * This does not soften what a fact has to be. `factItem` is unchanged, so
 * nothing reaches the table that would not have reached it before, and
 * nothing unvalidated is stored. What changed is how much a single bad item
 * is allowed to take with it. Decision 285.
 */
export const factsResult = z.object({
  facts: forgivingList(factItem, 8),
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
  observations: forgivingList(
    z.object({
      subject: z.string().trim().min(1).max(60).regex(NO_DASH),
      predicate: z.string().trim().min(1).max(60).regex(NO_DASH),
      object: z.string().trim().min(1).max(160).regex(NO_DASH),
      sentence: z.string().trim().min(1).max(240).regex(NO_DASH),
      drawnFrom: z.array(z.number().int().positive()).min(2).max(40),
      confidence: z.number().min(0).max(1),
    }),
    3,
  ),
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
  /// The sky, when the phone could read it. A card is shown either way, so
  /// all four of these are optional and the question is written from the
  /// time, the day and what they last said instead.
  condition: z.string().trim().min(1).max(40).optional(),
  degrees: z.number().int().min(-100).max(150).optional(),
  daylight: z.boolean().optional(),
  place: z.string().trim().max(80).optional(),

  fahrenheit: z.boolean(),

  /// The hour, the weekday and the month on the phone, so when it is is
  /// theirs rather than the server's idea of it. Monday is 1.
  hour: z.number().int().min(0).max(23),
  weekday: z.number().int().min(1).max(7),
  month: z.number().int().min(1).max(12),
})
export type WeatherAsk = z.infer<typeof weatherAsk>

export const weatherQuestion = z.object({
  question: z.string().trim().min(1).max(140),
})

