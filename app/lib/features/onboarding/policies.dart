/// The two policy documents, shown from the sign in screen.
///
/// Written to match how this app actually works, and not reviewed by a lawyer.
/// Anything here that stops being true is a defect, not a wording preference:
/// this is the text Apple's reviewer and every person signing in reads.
///
/// Both are drafts and they mirror www/terms.html and www/privacy.html. When
/// one changes the other changes in the same commit. Decision 282.
library;

const policyUpdated = 'Last updated 18 September 2026. Draft, not yet reviewed by a lawyer.';

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

Soul does not watch for emergencies and cannot respond to one. Every entry is
read automatically for signs of risk and a record is kept of that reading, but
nobody reads your entry and nothing on your screen changes because of it.

If you are in danger or thinking about harming yourself, contact emergency
services or a crisis line where you are, straight away. In the United States
you can call or text 988. Soul cannot see your entries as you write them,
cannot contact anyone for you, and cannot respond to an emergency.

NO ADVICE

Nothing in the app is medical, psychological or therapeutic advice. It does not
diagnose anything. On the patterns screen, and nowhere else, it will say that
something you keep doing is worth keeping or worth stopping. That is one
sentence about a situation you can see the entries for. It is never a statement
about what kind of person you are. Talk to a qualified person about anything
serious.

YOUR ACCOUNT

Your phone is given an account the first time the app opens, before you are
asked anything. You can then sign in with Apple, or with a code sent to your
email. If you sign in with your email, the address is held so you can get back
in. Signing in links the account to you so that what you write follows you if
you change phones.

WHAT YOU WRITE

What you write is yours. To answer you, the app sends what you wrote to the
model providers named in the Privacy Policy. Your words are never used to train
anybody's model, and they are never sold. You can delete your whole account and
everything in it from your profile, at any time.

WHAT THE APP ASKS YOU

Every question in the app can be answered or left. Nothing in the app scores
you or ranks you.

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

To turn speech into text: a speech recognition provider.
To write a line back, to describe your entries in a few words, and to describe
how you sounded when you spoke: an AI model provider.
To deliver a sign in code, if you sign in with your email: an email delivery
service.

They process what is sent and nothing more, under agreements that say so. Your
words are not used to train their models. The current list of providers is sent
to anybody who asks at founder@soulspacehealth.com.

WHAT WE MEASURE

Two services help us find faults and see how the app is used. An error
reporting service receives error reports and a recording of the screens around
an error, with text and images masked, so it shows where somebody tapped and
not what they wrote. A product analytics service receives the names of screens
and actions, how many moments you have
written, and, once you sign in, your email address and first name, so that a
reply to feedback can reach you. Neither is ever sent anything you wrote or
said. There is no advertising, and nothing is sold.

IF SOMETHING LOOKS SERIOUS

Every entry is read automatically for signs of risk, and the app records what
that reading was. Nothing on your screen changes because of it, and nothing is
sent to anybody on your behalf. Soul is not a crisis service. If you are in
danger, contact emergency services or a crisis line where you are. In the
United States you can call or text 988.

DELETING

You can delete your whole account and everything in it from your profile:
Delete my account is at the bottom. It is removed rather than hidden, straight
away, and it cannot be brought back.

CHANGES

If this policy changes in a way that matters, you will be asked again rather
than told afterwards.
''';
