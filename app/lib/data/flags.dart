import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics.dart';

/// The switches that turn a piece of this app off without a release.
///
/// The app ships through TestFlight, which means a build with a broken
/// feature in it is live until Apple has processed the next one. That is
/// hours at best. Every one of these wraps something that talks to a model
/// or to somebody else's service, which is where an outage comes from, and
/// turning one off is a click rather than a build.
///
/// Everything is on unless PostHog says otherwise. A phone with no network,
/// a build with no key, a flag nobody has created: all of them read as on,
/// because a switch that fails to the off position is a switch that breaks
/// the app the first time the flag service is down.
class Flag {
  /// The card at the top of home, and the whole weather path behind it.
  static const weatherCard = 'weather_card';

  /// Speaking at all. There is one voice path and it is the live one, so
  /// this is the switch for the transcriber being down: off takes the mic
  /// off the screen and leaves the box, rather than letting somebody speak
  /// for thirty seconds into a service that is not going to answer.
  static const voiceCapture = 'voice_capture';

  /// Judging how a spoken entry sounded. It is one model call per entry and
  /// nothing on screen depends on it.
  static const toneCapture = 'tone_capture';

  /// Looking closer at an entry. The most expensive call in the product.
  static const mirror = 'mirror';

  static const all = [weatherCard, voiceCapture, toneCapture, mirror];
}

final Map<String, bool> _held = {};

/// Reads the switches once, at launch, after analytics has started.
///
/// A flag PostHog has never heard of comes back null, and null is on. That
/// is what makes it safe to write `if (isOn(Flag.mirror))` around something
/// before the flag exists.
Future<void> loadFlags() async {
  if (!analyticsOn) return;
  try {
    await Posthog().reloadFeatureFlags();
    for (final name in Flag.all) {
      final value = await Posthog().getFeatureFlag(name);
      if (value != null) _held[name] = value == true;
    }
  } catch (_) {
    // Everything stays on, which is where it was a moment ago.
  }
}

bool isOn(String flag) => _held[flag] ?? true;
