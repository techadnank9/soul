import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Product analytics: how the app is used, not what is said in it.
///
/// This is the only place in the client that touches PostHog. Everything
/// goes through `SoulApi.event`, which posts to our own `app_events` table
/// and hands the same name here, so the two never drift and the table stays
/// the record.
///
/// What goes out is a fixed event name and small counts or status codes. No
/// entry text, no transcript, no name, no email, no coordinates. The rule
/// that governs `app_events` governs this, and there is nothing to strip
/// because nothing of the sort is ever passed in.
///
/// Off unless a key is given at build time. release.sh passes it and a
/// build made by hand does not, so a simulator is only ever in the numbers
/// when somebody deliberately put the key on the command line. When it is,
/// every event carries environment development, so the funnels can be read
/// without the work being done on them.
const _key = String.fromEnvironment('POSTHOG_KEY');
const _host = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://us.i.posthog.com',
);

bool _on = false;

Future<void> startAnalytics() async {
  if (_key.isEmpty) return;
  try {
    final config = PostHogConfig(_key)
      ..host = _host
      // Screens are named by the navigator observer, which is the only
      // automatic collection turned on. No autocapture of taps: a tap on an
      // unnamed widget is noise, and the events this app sends by hand say
      // what actually happened.
      ..captureApplicationLifecycleEvents = true
      ..sessionReplay = false;
    await Posthog().setup(config);
    _on = true;
  } catch (_) {
    // Analytics that will not start is not a reason for an app not to.
  }
}

void capture(String name, [Map<String, Object?> properties = const {}]) {
  if (!_on) return;
  try {
    Posthog().capture(
      eventName: name,
      properties: {
        for (final entry in properties.entries)
          if (entry.value != null) entry.key: entry.value!,
        'environment': kReleaseMode ? 'production' : 'development',
      },
    );
  } catch (_) {
    // Fire and forget, the same as the event it came from.
  }
}

/// Ties what this phone does to the account it is signed in as, so the same
/// person on a second phone is one person in a funnel. The account id and
/// nothing else: no name, no address.
Future<void> identify(String accountId) async {
  if (!_on) return;
  try {
    await Posthog().identify(userId: accountId);
  } catch (_) {}
}

/// Log out. The next person on this phone is not the last one.
Future<void> forgetWhoTheyAre() async {
  if (!_on) return;
  try {
    await Posthog().reset();
  } catch (_) {}
}

/// The navigator observer, for screen names. Null when analytics is off, so
/// nothing is added to the tree that does nothing.
PosthogObserver? screenObserver() => _on ? PosthogObserver() : null;
