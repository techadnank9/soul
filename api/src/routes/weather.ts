import { Hono } from 'hono'
import { weatherWhere } from '../services/weather/now.js'
import { reading } from '../services/weather/reading.js'
import type { Session } from '../session.js'

/**
 * Where to ask about the weather, and whether today has been answered.
 *
 * The weather is read on the phone through WeatherKit, so nothing here
 * leaves the building. Null when there is no position and no region, and
 * home reads that as no card.
 */
type Vars = { Variables: { session: Session } }

export const weather = new Hono<Vars>()

weather.get('/weather', async (c) => {
  return c.json(await weatherWhere(c.get('session')))
})

/**
 * A reading of the sky, for development builds only. A release build reads
 * the weather from Apple on the device and never asks for this. See the
 * service for why it exists at all.
 */
weather.get('/weather/reading', async (c) => {
  return c.json(await reading(c.get('session')))
})
