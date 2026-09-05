import { Hono } from 'hono'
import { weatherWhere } from '../services/weather/now.js'
import { reading } from '../services/weather/reading.js'
import { weatherQuestionFor } from '../services/weather/question.js'
import * as contracts from '../contracts.js'
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
  const latitude = Number(c.req.query('latitude'))
  const longitude = Number(c.req.query('longitude'))
  const at =
    Number.isFinite(latitude) && Number.isFinite(longitude)
      ? { latitude, longitude }
      : undefined

  return c.json(await reading(c.get('session'), at))
})

/**
 * One question for the card, written from what the phone found. Null when
 * it could not be written, and the app asks its own plain question instead
 * rather than showing nothing.
 */
weather.post('/weather/question', async (c) => {
  const parsed = contracts.weatherAsk.safeParse(await c.req.json().catch(() => null))
  if (!parsed.success) return c.json({ error: 'invalid weather' }, 400)

  const question = await weatherQuestionFor(c.get('session'), parsed.data)
  return c.json({ question })
})
