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
   * The one address Apple's reviewer signs in with, and the code that works
   * for it.
   *
   * App review has to get into the app, first run cannot be skipped, and a
   * reviewer cannot receive a six digit code sent to an address they do not
   * own. So this address, and only this address, takes a fixed code instead
   * of a sent one.
   *
   * It is a way in, stated plainly. What keeps it honest: it is off unless
   * both variables are set, so it does not exist on any host that has not
   * asked for it; it is one address compared exactly, not a pattern; the code
   * is set per environment and can be changed without a release; nothing else
   * about the account is special, so what a reviewer sees is what the product
   * does. Unset both after a review to close it. Decision 261.
   */
  reviewEmail: (): string | undefined => optional('SOUL_REVIEW_EMAIL')?.trim().toLowerCase(),
  reviewCode: (): string | undefined => optional('SOUL_REVIEW_CODE'),

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

  /**
   * Where errors are reported. Unset means they are only logged, which is
   * what a laptop wants and what the service falls back to.
   */
  sentryDsn: (): string | undefined => optional('SENTRY_DSN'),

  providers: {
    openaiKey: optional('OPENAI_API_KEY'),
    resendKey: optional('RESEND_API_KEY'),
    geminiKey: optional('GEMINI_API_KEY'),
    openrouterKey: optional('OPENROUTER_API_KEY'),
    elevenlabsKey: optional('ELEVENLABS_API_KEY'),

    /**
     * AWS End User Messaging, for sign in codes by text. Unset anywhere
     * these are missing, and the phone path says it is not available the
     * same way the email one does without Resend.
     *
     * The origination identity is the number the message comes from: a toll
     * free number while this is small, because toll free verification is
     * free and the ten digit long code registration is a month of carrier
     * paperwork.
     */
    awsRegion: optional('AWS_REGION'),
    awsAccessKeyId: optional('AWS_ACCESS_KEY_ID'),
    awsSecretAccessKey: optional('AWS_SECRET_ACCESS_KEY'),
    smsOriginationIdentity: optional('SMS_ORIGINATION_IDENTITY'),

    /**
     * Notify, which is AWS leasing the number and holding the carrier
     * registrations instead of us. Set this and nothing else is needed:
     * no toll free number, no verification form, no weeks of waiting.
     *
     * It costs four and a half cents a message on top of the message,
     * which is the price of not doing the paperwork. Set the origination
     * identity above instead once the volume makes that worth a fortnight
     * of forms, and this file needs no other change.
     */
    smsNotifyConfigurationId: optional('SMS_NOTIFY_CONFIGURATION_ID'),
    smsNotifyTemplateId: optional('SMS_NOTIFY_TEMPLATE_ID'),
  },
}
