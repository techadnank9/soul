/// The two policy documents, shown from the sign in screen.
///
/// Written to match how this app actually works, and not reviewed by a lawyer.
/// Anything here that stops being true is a defect, not a wording preference:
/// this is the text a district will read before they let a child use it.
///
/// Both are drafts. The named third parties, the retention window and the
/// escalation wording all have to be checked against the signed district
/// agreement before any user sees this.
library;

const policyUpdated = 'Draft, not yet reviewed';

const termsOfService = '''
$policyUpdated

These are the terms for using Soul, a reflection app. By using the
app you agree to them. This is a first draft written to match how the app works
today, and it has not been reviewed by a lawyer.

WHAT SOUL IS

Soul is a place to say what just happened and get one short line back. It can
look closer if you ask it to, and days later it asks how something went. It is
a reflection tool. It is not therapy, not a medical device, not a diagnosis,
and not a replacement for anyone you would talk to.

SOUL IS NOT A CRISIS SERVICE

If what you write looks like a crisis, the app stops and shows you a screen
with people you can reach. That screen is produced automatically. Nobody reads
your entry before you see it.

If you are in danger or thinking about harming yourself, contact emergency
services or a crisis line where you are, straight away. In the United States
you can call or text 988. Soul cannot see your entries as you write them,
cannot contact anyone for you, and cannot respond to an emergency.

NO ADVICE

Nothing in the app is medical, psychological or therapeutic advice. It does not
diagnose anything, and it does not tell you what to do. Talk to a qualified
person about anything serious.

YOUR ACCOUNT

Your school or district sets up your account. Signing in with Apple links that
account to your device so what you write follows you if you change phones.

WHAT YOU WRITE

What you write is yours. To answer you, the app sends what you wrote to the
model providers named in the Privacy Policy. Your words are never used to train
anybody's model, and they are never sold. You can delete any entry, and you can
ask for everything to be deleted.

WHAT THE APP ASKS YOU

Every question in the app can be answered or left. Nothing in the app scores
you, ranks you, or reports how you answered to your school as a result of
answering.

CHANGES

If these terms change in a way that matters, you will be asked again rather
than told afterwards.
''';

const privacyPolicy = '''
$policyUpdated

This Privacy Policy describes what Soul holds about you, what leaves the app,
and what you can delete.

WHAT WE HOLD

What you write. Your entries, the lines the app wrote back, the decisions you
chose to hold, and how they turned out.

What you told us at the start. A first name, an age band, a gender and where
you are. If you shared your location, that is your exact position, and you can
remove it at any time from the profile tab.

Nothing else about you. No surname. No birthdate. No address. No contacts, no
photos, no browsing, and no advertising identifiers.

AUDIO IS NEVER KEPT

If you speak instead of typing, the recording is sent to be turned into text
and to be described in a few words for how it sounded, and then it is gone. It
is never saved, never backed up, and never listened to by us. The transcript
and that short description are what is kept, which is why you are shown the
transcript and asked whether to send it. Discard it and the description goes
too.

WHO ELSE SEES IT

To turn speech into text: ElevenLabs.
To describe how you sounded when you spoke: OpenAI.
To deliver a sign in code, if you sign in with your email: Resend.
To write a line back and to describe your entries in a few words: OpenAI.

They process what is sent and nothing more. Your words are not used to train
their models. If your school has not agreed to this processing, nothing leaves
the app at all and your entries are simply stored.

NO TRACKING

There is no analytics package in this app, no crash reporting package, and no
advertising. Nobody is watching which screens you open.

YOUR SCHOOL AND YOUR DISTRICT

Your account belongs to a school inside a district. A district can ask what is
held about a user and when consent was recorded. What you write is not sent
to your teachers as a report.

If something you write suggests you are at risk, the app records that it
happened. What is done about it is set by your district's escalation policy,
which is written down and which you can ask to see.

DELETING

You can delete an entry. You can ask for your whole account and everything in
it to be deleted, and it is then removed rather than hidden.

CHANGES

If this policy changes in a way that matters, you will be asked again rather
than told afterwards.
''';
