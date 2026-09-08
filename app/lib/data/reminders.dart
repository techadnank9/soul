import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api/client.dart';
import '../api/models.dart';

/// The notifications somebody asked for by saying a time out loud.
///
/// Every one of these exists because a person said "tomorrow at two I am
/// meeting my brother". Nothing here is a streak, a nudge, a come back and
/// write something, or anything else an app decides on its own that somebody
/// needs. If they did not name a time, their phone stays quiet.
///
/// **The phone rings itself.** The server holds what was said and when, and
/// this reads that list and books a local notification for each one. No push,
/// no device token, no notification service told who anybody is or what they
/// are about to do. A phone that is off simply rings when it is next on.
///
/// Permission is asked for the first time there is actually something to
/// ring about, never at launch. An app asking to send notifications before it
/// has anything to say is asking for a habit rather than for permission.
class Reminders {
  Reminders(this._api);

  final SoulApi _api;
  final _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// The rows this phone has already booked, so a second sync in the same
  /// session does not cancel and rebook everything under the person.
  final _booked = <String, DateTime>{};

  Future<void> _prepare() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final here = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(here.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          // Asked for separately, at the moment there is something to ring
          // about, rather than on the first frame of the app.
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Read what is due and make sure the phone knows about all of it.
  ///
  /// Called when the app opens and when it comes back to the front, because
  /// a reminder written on one phone has to reach the other one, and because
  /// iOS drops what it has scheduled when an app is reinstalled.
  ///
  /// Quiet about everything. A person who said no to notifications gets no
  /// second ask and no complaint, and a list that will not load leaves what
  /// is already booked exactly where it is.
  Future<void> sync() async {
    try {
      final due = await _api.reminders();
      if (due.isEmpty) return;

      await _prepare();
      if (!await _allowed()) return;

      for (final r in due) {
        if (_booked[r.id] == r.dueAt) continue;
        await _book(r);
        _booked[r.id] = r.dueAt;
      }
    } catch (error) {
      _api.event('reminders_sync_failed', {
        'error': error.runtimeType.toString(),
      });
    }
  }

  /// The permission, asked for once, at the moment it is worth something.
  Future<bool> _allowed() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, sound: true);
      _api.event('reminders_permission', {'granted': granted ?? false});
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    _api.event('reminders_permission', {'granted': granted ?? false});
    return granted ?? false;
  }

  Future<void> _book(Reminder r) async {
    final when = tz.TZDateTime.from(r.dueAt, tz.local);
    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      // The uuid is not an int and iOS wants one. The same id always maps to
      // the same number, so rebooking replaces rather than duplicates.
      id: r.id.hashCode & 0x7fffffff,
      // No title. The one sentence is the whole notification, and a title
      // above it would be the app announcing itself over what they said.
      body: r.said,
      scheduledDate: when,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        android: AndroidNotificationDetails(
          'reminders',
          'What you said you would do',
          channelDescription:
              'Rings at a time you named yourself, saying what you said.',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    if (kDebugMode) debugPrint('reminder booked for $when: ${r.said}');
  }
}
