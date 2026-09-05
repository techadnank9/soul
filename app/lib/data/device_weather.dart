import 'package:flutter/services.dart';

/// The weather where somebody is, from Apple, read on this device.
///
/// WeatherKit rather than a weather service on the internet: the Apple
/// Developer Program membership already covers it, it is licensed for a
/// product people pay for, and the position never leaves the phone. Our own
/// service is told where to look and never told what the answer was.
///
/// Apple asks for attribution wherever this is shown, which the card carries.
class DeviceWeather {
  const DeviceWeather({
    required this.words,
    required this.question,
    required this.degrees,
    required this.condition,
    required this.daylight,
  });

  /// What the sky is doing, in the words somebody would use looking out of a
  /// window.
  final String words;

  /// One question that fits that kind of day. It asks and never tells. None
  /// of them names a feeling, suggests one, or implies the weather ought to
  /// have done something to anybody.
  final String question;

  final int degrees;

  /// What the sky is doing, as Apple named it, for the service to write a
  /// question from.
  final String condition;
  final bool daylight;

  /// The plain question, used when the written one does not arrive. It says
  /// the weather and asks, in the same shape the written one does.
  String plainIn(String? place) {
    final where = place == null || place.isEmpty ? '' : ' in $place';
    return '$words$where, $degrees degrees. $question';
  }
}

const _channel = MethodChannel('soul/weather');

/// Turns a reading into words. Apple's condition names on a device, and the
/// same vocabulary from the service in a development build.
DeviceWeather readingToWeather({
  required String condition,
  required double celsius,
  required bool daylight,
  required bool fahrenheit,
}) {
  final sky = _skyFor(condition, night: !daylight);
  return DeviceWeather(
    words: sky.$1,
    question: sky.$2,
    degrees: (fahrenheit ? celsius * 9 / 5 + 32 : celsius).round(),
    condition: condition,
    daylight: daylight,
  );
}

/// Null on anything at all: no entitlement yet, no network, an older phone,
/// or Apple saying no. Home reads null as no card.
Future<DeviceWeather?> weatherAt({
  required double latitude,
  required double longitude,
  required bool fahrenheit,
}) async {
  try {
    final answer = await _channel.invokeMapMethod<String, dynamic>('now', {
      'latitude': latitude,
      'longitude': longitude,
    }).timeout(const Duration(seconds: 8));
    if (answer == null) return null;

    final condition = answer['condition'] as String?;
    final celsius = (answer['celsius'] as num?)?.toDouble();
    final daylight = answer['daylight'] as bool? ?? true;
    if (condition == null || celsius == null) return null;

    return readingToWeather(
      condition: condition,
      celsius: celsius,
      daylight: daylight,
      fahrenheit: fahrenheit,
    );
  } catch (_) {
    return null;
  }
}

/// Apple's own names for a sky, in the words somebody would use for it.
///
/// There are more than thirty of them and they group into a handful of days
/// somebody would recognise, so they are matched on what the name contains
/// rather than listed one by one. Anything unrecognised falls through to the
/// plainest question there is.
(String, String) _skyFor(String condition, {required bool night}) {
  const going = 'How is today going so far?';
  const inThat = 'How is it going in that?';

  bool has(String part) => condition.contains(part);

  if (has('thunder')) return ('Thunderstorms', inThat);
  if (has('hurricane') || has('tropicalstorm')) return ('A storm', inThat);
  if (has('blizzard')) return ('A blizzard', inThat);
  if (has('hail')) return ('Hail', inThat);
  if (has('sleet') || has('wintrymix') || has('freezing')) return ('Sleet', inThat);
  if (has('flurries') || has('snow') || has('blowingsnow')) return ('Snow', inThat);
  if (has('drizzle')) return ('Drizzle', inThat);
  if (has('rain') || has('sunshowers')) return ('Rain', inThat);
  if (has('fog') || has('haze') || has('smoky')) return ('Fog', 'What is today like so far?');
  if (has('wind') || has('breezy') || has('blustery')) return ('Windy', going);
  if (has('cloudy')) {
    return has('mostlyclear') || has('partly')
        ? ('Partly cloudy', going)
        : ('Overcast', going);
  }
  if (has('clear') || has('sunny') || has('hot')) {
    return night ? ('Clear tonight', 'How has today ended up?') : ('Clear', going);
  }
  return night ? ('Tonight', 'How has today ended up?') : ('Today', going);
}

/// Apple's legal page for the weather they provide, which they ask to be
/// reachable wherever it is shown. Opened by the phone rather than by a
/// package, because one method on a channel that already exists is smaller
/// than another dependency.
Future<void> launchWeatherAttribution() async {
  try {
    await _channel.invokeMethod<void>('attribution');
  } catch (_) {
    // Nothing to say. The label is still on the screen.
  }
}

