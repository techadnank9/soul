import 'package:flutter/services.dart';
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
/// Where the phone is right now, but only if it has already been allowed to
/// say. It never asks.
///
/// The weather card uses this so it is about where somebody is standing
/// rather than where they were when they first opened the app. It is never
/// written anywhere: the position in the profile is the one they gave, and
/// only they change it.
///
/// Null when location is off, when permission was never given, or when the
/// phone takes too long, and the card falls back to the profile.
Future<DeviceLocation?> quietLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final permission = await Geolocator.checkPermission();
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
