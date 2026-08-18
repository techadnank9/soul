/**
 * Configuration. Every provider key is read here and nowhere else, so the list
 * of third parties this service can reach is one file long. That list is the
 * same list a district data agreement names.
 */
function required(name: string): string {
  const value = process.env[name]
  if (!value) throw new Error(`${name} is not set`)
  return value
}

function optional(name: string): string | undefined {
  return process.env[name] || undefined
}

export const env = {
  port: Number(process.env.PORT ?? 8080),
  databaseUrl: () => required('DATABASE_URL'),

  providers: {
    openaiKey: optional('OPENAI_API_KEY'),
    geminiKey: optional('GEMINI_API_KEY'),
    openrouterKey: optional('OPENROUTER_API_KEY'),
    deepgramKey: optional('DEEPGRAM_API_KEY'),
  },
}
