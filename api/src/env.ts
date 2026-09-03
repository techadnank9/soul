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

  /**
   * The audience every Apple identity token has to name. A token minted for
   * another app is a real token signed by Apple, so this is the check that
   * makes it ours. Read late and required, because verifying against a missing
   * bundle identifier is worse than refusing to verify at all.
   */
  appleBundleId: () => required('APPLE_BUNDLE_ID'),

  /**
   * Whether the roster identifier is accepted as a bearer token.
   *
   * A rostering identifier is shared with a district's own systems and is not
   * a secret, so treating it as one is a way in. It is how the product has been
   * driven from a laptop since the first day, which is worth keeping, so it is
   * a flag that has to be turned on rather than a default that has to be
   * remembered. Off unless SOUL_ROSTER_TOKENS is exactly the word allow.
   */
  allowRosterTokens: (): boolean => process.env.SOUL_ROSTER_TOKENS === 'allow',

  /**
   * The shared secret a scheduler presents to drain the job queue. Unset means
   * the drain endpoint refuses everybody, which is the right default for a
   * machine to machine route.
   */
  jobsSecret: (): string | undefined => optional('SOUL_JOBS_SECRET'),

  /**
   * Sign in codes go out through Resend. The from address has to be on a
   * domain verified in Resend, and the default is Resend's own test sender,
   * which only delivers to the account that owns the key. Fine for a first
   * device build, wrong for anybody else.
   */
  resendFrom: (): string => optional('RESEND_FROM') ?? 'Soul <onboarding@resend.dev>',

  providers: {
    openaiKey: optional('OPENAI_API_KEY'),
    resendKey: optional('RESEND_API_KEY'),
    geminiKey: optional('GEMINI_API_KEY'),
    openrouterKey: optional('OPENROUTER_API_KEY'),
    elevenlabsKey: optional('ELEVENLABS_API_KEY'),
  },
}
