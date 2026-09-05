import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';

/// The device's own position, when the user allows it.
///
/// This is the only place in the client that touches location. It returns a
/// pair of numbers or nothing at all, and it never throws at the caller,
/// because every reason it can fail leads to the same place: the user picks
/// their region from the list instead.
///
/// Nothing is cached and nothing is written to the device. The coordinates go
/// straight to the profile call and are held only where the user can see
/// them and delete them.
class DeviceLocation {
  const DeviceLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Asks, once. A user who says no is not asked again by this function, and
/// a user who has said never is not shown a prompt that cannot appear.
Future<DeviceLocation?> currentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      // Ten seconds, because a user waiting on a satellite fix in a
      // building is a user who has stopped believing the app works.
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    return DeviceLocation(position.latitude, position.longitude);
  } catch (_) {
    // Off, refused, timed out, unsupported. All of it means the same thing
    // here, and the list is still on the screen.
    return null;
  }
}

/// Opens the phone's own settings for this app, where location can be
/// turned back on. When location is off for the whole phone it opens that
/// switch instead. Nothing is read or written; it is a door.
/// Where the phone is right now, for the card at the top of home.
///
/// It asks the first time, so the card is about where somebody is standing
/// rather than where they were when they first opened the app. iOS asks
/// once and remembers the answer, so this is one dialog in the life of the
/// app and never a dialog on every open. Somebody who has said no is not
/// asked again.
///
/// It is never written anywhere. The position in the profile is the one
/// they gave, and only they change it.
///
/// Null when location is off, when it was refused, or when the phone takes
/// too long, and the card falls back to what the service holds.
Future<DeviceLocation?> locationNow() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    // Denied on iOS is also what never asked looks like. Refused for good
    // is its own answer and is not asked again.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        // Coarse is enough for what the sky is doing, and it is quicker and
        // cheaper on the battery than asking for a precise fix.
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    return DeviceLocation(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

Future<void> openLocationSettings() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  } catch (_) {
    // The door did not open. The map is still on the screen.
  }
}

/// The place those coordinates are, as a person would say it, from the
/// phone's own geocoder: neighbourhood, city, state. Null when the phone
/// cannot say, which is what an offline phone answers.
const _place = MethodChannel('soul/place');

Future<String?> placeName(double latitude, double longitude) async {
  try {
    return await _place
        .invokeMethod<String>('name', {'latitude': latitude, 'longitude': longitude})
        .timeout(const Duration(seconds: 8));
  } catch (_) {
    return null;
  }
}

/// The last few positions this phone reported, newest first, kept on the
/// device and nowhere else.
///
/// The card at the top of home is about where somebody is. A phone that
/// cannot answer right now, because it is indoors, or in a lift, or has
/// been told not to answer this launch, used to mean the card fell all the
/// way back to the region picked during first run, which can be a thousand
/// miles from where they are standing. Yesterday's fix is a far better
/// guess than that.
///
/// It is written to the keychain rather than a preferences file, because
/// where somebody has been is the most sensitive thing this app holds. It
/// never leaves the phone, it is never sent with an entry, and it never
/// touches the position in the profile, which is theirs and only they
/// change it.
const _fixes = FlutterSecureStorage();
const _fixesKey = 'recent_positions';
const _fixesKept = 3;

Future<void> _remember(DeviceLocation at) async {
  try {
    final held = await _held();
    final line = [
      '${at.latitude},${at.longitude}',
      for (final old in held)
        if (!(old.latitude == at.latitude && old.longitude == at.longitude))
          '${old.latitude},${old.longitude}',
    ].take(_fixesKept).join(';');
    await _fixes.write(key: _fixesKey, value: line);
  } catch (_) {
    // A keychain that will not open costs the next launch a better guess.
  }
}

Future<List<DeviceLocation>> _held() async {
  try {
    final line = await _fixes.read(key: _fixesKey);
    if (line == null || line.isEmpty) return const [];
    final out = <DeviceLocation>[];
    for (final pair in line.split(';')) {
      final parts = pair.split(',');
      if (parts.length != 2) continue;
      final latitude = double.tryParse(parts[0]);
      final longitude = double.tryParse(parts[1]);
      if (latitude != null && longitude != null) {
        out.add(DeviceLocation(latitude, longitude));
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Erases the trail. Called when a user empties their location from the
/// profile, so clearing it there clears it everywhere.
Future<void> forgetRecentPositions() async {
  try {
    await _fixes.delete(key: _fixesKey);
  } catch (_) {
    // Nothing more to do about it here.
  }
}

/// Where to put on the card, in the order of how well it answers the
/// question: where the phone is now, then where the phone was last, then
/// the ones before that, and then nothing, which sends the caller to the
/// position in the profile.
///
/// Every one of these is a place this person has actually been, which is
/// the whole point. The card is shown either way.
Future<DeviceLocation?> locationForCard() async {
  final now = await locationNow();
  if (now != null) {
    await _remember(now);
    return now;
  }

  // The phone's own last fix, which any app on it may have caused. Free,
  // instant, and usually minutes old rather than hours.
  try {
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      final at = DeviceLocation(last.latitude, last.longitude);
      await _remember(at);
      return at;
    }
  } catch (_) {
    // Refused or unavailable. The ones we kept are still here.
  }

  final held = await _held();
  return held.isEmpty ? null : held.first;
}
