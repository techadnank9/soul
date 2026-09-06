import {
  PinpointSMSVoiceV2Client,
  SendTextMessageCommand,
} from '@aws-sdk/client-pinpoint-sms-voice-v2'
import { env } from '../env.js'

/**
 * One text message, through AWS End User Messaging.
 *
 * AWS rather than Twilio because a verification product charges five cents
 * a time to do what this file does, and the message itself is under a
 * penny. Amazon Pinpoint's console is switched off in October 2026 and the
 * SMS API is not: it lives on as End User Messaging under the same
 * namespace, which is what this client speaks.
 *
 * This is the only SDK in the API. Resend gets a fetch call because it is
 * one POST with a bearer token. This one is signed requests against a
 * regional endpoint, and hand rolling AWS signature version four to save a
 * dependency would be the wrong kind of thrift.
 */
export class SmsUnavailable extends Error {}

let client: PinpointSMSVoiceV2Client | null = null

function sender(): PinpointSMSVoiceV2Client {
  const region = env.providers.awsRegion
  const key = env.providers.awsAccessKeyId
  const secret = env.providers.awsSecretAccessKey
  if (!region || !key || !secret) throw new SmsUnavailable('AWS credentials are not set')

  return (client ??= new PinpointSMSVoiceV2Client({
    region,
    credentials: { accessKeyId: key, secretAccessKey: secret },
  }))
}

export async function sendSignInCodeBySms(to: string, code: string): Promise<void> {
  const from = env.providers.smsOriginationIdentity
  if (!from) throw new SmsUnavailable('SMS_ORIGINATION_IDENTITY is not set')

  // The body says what it is and nothing else. A code arriving with a
  // sentence of marketing in it is a code the carrier is entitled to block,
  // and it is also a promise broken on the first message.
  await sender().send(
    new SendTextMessageCommand({
      DestinationPhoneNumber: to,
      OriginationIdentity: from,
      MessageBody: `${code} is your Soul code. It works for ten minutes.`,
      // Transactional buys the higher delivery priority. This message is
      // somebody standing there waiting for it.
      MessageType: 'TRANSACTIONAL',
    }),
  )
}
