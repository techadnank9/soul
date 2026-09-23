import { sql } from '../db.js'

/**
 * First run followed them to the account they signed in to.
 *
 * The bug this exists for: a phone gets an account on first launch, writes
 * the whole of first run into it, and then signs in. When that Apple id or
 * address already belonged to an account, sign in moved the session to it
 * and left everything first run had just written on the account nobody would
 * ever open again. The person answered ten questions, watched the app write
 * a line about them, signed in, and landed on a home screen that knew none
 * of it, with a profile that said not answered ten times.
 *
 * So what first run wrote comes with them. Only what the account they are
 * joining does not already have: a field that is already filled is theirs
 * and is never overwritten, and a set of baseline answers already recorded
 * is never replaced by an older one.
 *
 * What does not move: entries, and anything read out of them. A moment
 * belongs to the account it was written on, and moving one means moving its
 * tags, its facts, its people and its embedding, with every id and every
 * scope kept straight. That is a bigger piece of work than this, and it is
 * written down as the part still missing rather than half done here.
 *
 * Nothing here runs when the two accounts are the same, and nothing here
 * runs for an account that had already been signed in to: `from` is only
 * ever the device account this phone made for itself.
 *
 * Decision 299.
 */
export async function adoptFirstRun(from: string, to: string): Promise<void> {
  if (from === to) return

  await sql.begin(async (tx) => {
    // One statement, and the values never leave the database.
    //
    // Reading the row into JavaScript and writing it back meant serialising
    // `opening_themes`, which is jsonb, and the driver refused it. Copying
    // column to column keeps every type as it is and is less code besides.
    //
    // The guard is in the where: the account read from must be a device
    // account, one with no credential of its own. An account somebody has
    // signed in to is theirs and its first run is not going anywhere.
    const filled = await tx<{ id: string }[]>`
      update students as t set
        display_name = coalesce(t.display_name, d.display_name),
        age_band = coalesce(t.age_band, d.age_band),
        gender = coalesce(t.gender, d.gender),
        region = coalesce(t.region, d.region),
        timezone = coalesce(t.timezone, d.timezone),
        place = coalesce(t.place, d.place),
        opening = coalesce(t.opening, d.opening),
        opening_themes = coalesce(t.opening_themes, d.opening_themes),
        intent_area = coalesce(t.intent_area, d.intent_area),
        intent_reason = coalesce(t.intent_reason, d.intent_reason),
        profile_recorded_at = coalesce(t.profile_recorded_at, d.profile_recorded_at)
      from students as d
      where t.id = ${to}::uuid
        and d.id = ${from}::uuid
        and d.apple_user_id is null
        and d.email is null
      returning t.id`

    // Nothing was filled, which means the account read from is not a device
    // account. The answers stay where they are too.
    if (!filled[0]) return

    // The ten answers, only when the account they are joining has none of
    // its own. A set already there was answered by them on another device
    // and is not replaced by one from a phone.
    const [held] = await tx<{ n: number }[]>`
      select count(*)::int as n from baseline_answers where student_id = ${to}::uuid`

    if ((held?.n ?? 0) === 0) {
      await tx`
        update baseline_answers set
          student_id = ${to}::uuid,
          school_id = (select school_id from students where id = ${to}::uuid),
          district_id = (select district_id from students where id = ${to}::uuid)
        where student_id = ${from}::uuid`
    }
  })
}
