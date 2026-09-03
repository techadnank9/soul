import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The session token, in the keychain.
///
/// This is the only place in the client that touches secure storage. The token
/// is the whole of what the app knows about being signed in: it is the bearer
/// on every call after sign in, and the fact that one exists at all is what
/// says first run already happened.
///
/// Nothing here throws at the caller. A keychain that will not open reads as
/// no token, which walks a user through first run a second time. That is a
/// bad morning, not a broken app.
///
/// The accessibility is Apple's default, which is unlocked. Everything this
/// app does happens with a user looking at it, so there is no reason to
/// hold the token open while the phone is in a pocket.
const _keychain = FlutterSecureStorage();

const _key = 'session_token';

/// Read once, then remembered. Every API call asks for this, and the only
/// writes go through the two functions below, so the copy in memory cannot
/// drift from the keychain.
String? _cached;
bool _read = false;

/// The stored token, or nothing.
Future<String?> sessionToken() async {
  if (_read) return _cached;
  try {
    _cached = await _keychain.read(key: _key);
  } catch (_) {
    _cached = null;
  }
  _read = true;
  return _cached;
}

/// What sign in returns. Kept in memory whatever the keychain does, so a
/// failed write costs a user first run next launch rather than the rest of
/// this one.
Future<void> storeSessionToken(String token) async {
  _cached = token;
  _read = true;
  try {
    await _keychain.write(key: _key, value: token);
  } catch (_) {
    // Nothing to tell the user. They are signed in either way.
  }
}

/// Forgets the account on this device, which is also the way back to first
/// run once a user has signed in.
Future<void> clearSessionToken() async {
  _cached = null;
  _read = true;
  try {
    await _keychain.delete(key: _key);
  } catch (_) {
    // The token is gone from memory, so nothing sends it again this launch.
  }
}

/// Whether first run has been walked to the end on this device.
///
/// The token used to be the only record of that, and it cannot be any more:
/// a phone gets its session on first launch, before a single question, so a
/// token on its own means a phone that has been here, not a person who has
/// finished. This flag is what home is gated on.
const _firstRunKey = 'first_run_done';

Future<bool> firstRunDone() async {
  try {
    return await _keychain.read(key: _firstRunKey) == 'yes';
  } catch (_) {
    return false;
  }
}

Future<void> markFirstRunDone() async {
  try {
    await _keychain.write(key: _firstRunKey, value: 'yes');
  } catch (_) {
    // Next launch walks first run again. A bad morning, not a broken app.
  }
}
