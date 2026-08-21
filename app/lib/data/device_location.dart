import 'package:geolocator/geolocator.dart';

/// The device's own position, when the student allows it.
///
/// This is the only place in the client that touches location. It returns a
/// pair of numbers or nothing at all, and it never throws at the caller,
/// because every reason it can fail leads to the same place: the student picks
/// their region from the list instead.
///
/// Nothing is cached and nothing is written to the device. The coordinates go
/// straight to the profile call and are held only where the student can see
/// them and delete them.
class DeviceLocation {
  const DeviceLocation(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

/// Asks, once. A student who says no is not asked again by this function, and
/// a student who has said never is not shown a prompt that cannot appear.
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
      // Ten seconds, because a student waiting on a satellite fix in a
      // building is a student who has stopped believing the app works.
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
