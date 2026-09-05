/**
 * Where a student is, and the timezone that follows from it.
 *
 * The client shows the labels and sends the key. The timezone is derived here
 * rather than sent, because a timezone that arrived from a device is a string
 * we would have to trust, and everything scheduled for a student is scheduled
 * against it.
 *
 * The same list, in the same order, is in
 * app/lib/features/onboarding/profile_fields.dart.
 * Change both together.
 *
 * elsewhere carries no timezone on purpose. An unknown zone recorded as null
 * is a thing the scheduler can notice and fall back on. An unknown zone
 * recorded as a guess is not.
 */
export const regions = {
  uk: 'Europe/London',
  ireland: 'Europe/Dublin',
  us_east: 'America/New_York',
  us_central: 'America/Chicago',
  us_mountain: 'America/Denver',
  us_west: 'America/Los_Angeles',
  canada_east: 'America/Toronto',
  canada_west: 'America/Vancouver',
  australia_east: 'Australia/Sydney',
  australia_west: 'Australia/Perth',
  new_zealand: 'Pacific/Auckland',
  india: 'Asia/Kolkata',
  singapore: 'Asia/Singapore',
  uae: 'Asia/Dubai',
  south_africa: 'Africa/Johannesburg',
  elsewhere: null,
} as const

export type Region = keyof typeof regions

export const regionKeys = Object.keys(regions) as [Region, ...Region[]]

export function timezoneFor(region: Region): string | null {
  return regions[region]
}

/**
 * A point for each region, and the nearest one to a pair of coordinates.
 *
 * When a student shares their location the region is derived here rather than
 * chosen, so a picked region and a measured one end up as the same value and
 * everything downstream stays identical.
 *
 * This is a nearest point match on sixteen coarse regions, not geocoding. It
 * answers which broad part of the world, and it is wrong at the edges between
 * neighbouring zones. It never leaves the server and it needs no third party.
 */
const centres: Record<Exclude<Region, 'elsewhere'>, [number, number]> = {
  uk: [54.0, -2.5],
  ireland: [53.4, -8.0],
  us_east: [40.0, -76.0],
  us_central: [41.5, -93.0],
  us_mountain: [39.5, -105.5],
  us_west: [37.5, -120.5],
  canada_east: [45.5, -75.0],
  canada_west: [51.0, -120.0],
  australia_east: [-33.0, 151.0],
  australia_west: [-31.9, 115.9],
  new_zealand: [-41.0, 174.0],
  india: [21.0, 78.0],
  singapore: [1.35, 103.8],
  uae: [24.4, 54.4],
  south_africa: [-29.0, 24.5],
}

/**
 * The middle of a region, for when somebody picked one and never shared a
 * position. Coarse on purpose: it answers which part of the world, which is
 * enough to say what the sky is doing.
 */
export function centreOf(region: Region): [number, number] | null {
  if (region === 'elsewhere') return null
  return centres[region] ?? null
}

/** Rough great circle distance in kilometres. Good enough to pick a region. */
function apart(a: [number, number], b: [number, number]): number {
  const toRad = Math.PI / 180
  const meanLat = ((a[0] + b[0]) / 2) * toRad
  const dLat = (a[0] - b[0]) * 111
  const dLon = (a[1] - b[1]) * 111 * Math.cos(meanLat)
  return Math.sqrt(dLat * dLat + dLon * dLon)
}

/**
 * The closest region, or elsewhere when nothing is within range.
 *
 * Two thousand kilometres is wide enough that a student anywhere inside one of
 * these countries lands on it, and narrow enough that somewhere we do not
 * cover comes back as elsewhere rather than as a confident wrong answer.
 */
const TOO_FAR_KM = 2000

export function nearestRegion(latitude: number, longitude: number): Region {
  let closest: Region = 'elsewhere'
  let best = Infinity

  for (const [region, centre] of Object.entries(centres)) {
    const distance = apart([latitude, longitude], centre)
    if (distance < best) {
      best = distance
      closest = region as Region
    }
  }

  return best <= TOO_FAR_KM ? closest : 'elsewhere'
}
