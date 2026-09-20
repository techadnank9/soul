import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api/client.dart';
import 'session_store.dart';

/// The one question in the evening.
///
/// This is the app ringing a phone nobody asked it to ring, which is the
/// thing `reminders.dart` says it never does. That rule has not gone soft
/// everywhere else: a reminder still only exists because somebody named a
/// time out loud. This is one deliberate exception, written up as decision
/// 288, and it is held to four things.
///
/// It says nothing about the person. Every line comes from a written list on
/// the server and not one of them is read from an entry, a fact, a name or a
/// pattern. A notification is read on a locked screen by whoever is near it.
///
/// It is quiet on a day they already wrote. The evening is cancelled the
/// moment an entry lands, so nobody is asked about a day they have already
/// talked about.
///
/// It is not asked for until there is something to ask about. Permission is
/// requested after the first entry, never at launch, for the same reason the
/// reminders do it that way: an app asking on the first frame is asking for
/// a habit, not for permission.
///
/// It rings on the phone. Same as the reminders: no push, no device token,
/// nothing told to a notification service about anybody.
class Nudges {
  Nudges(this._api);

  final SoulApi _api;
  final _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Where these sit in the notification id space, clear of the reminders,
  /// which take theirs from a uuid hash.
  static const _base = 770000;

  Future<void> _prepare() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    final here = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(here.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Books the next fortnight of evenings, and rebooks them every time the
  /// app is opened so the run never empties.
  ///
  /// Does nothing at all until the person has written something. Quiet about
  /// every failure: a list that will not load leaves what is booked where it
  /// is, and somebody who said no to notifications is never asked twice.
  Future<void> sync() async {
    try {
      if (!await hasWritten()) return;

      final plan = await _api.nudges();
      if (plan.lines.isEmpty) return;

      await _prepare();
      if (!await _allowed()) return;

      final now = tz.TZDateTime.now(tz.local);
      var day = 0;
      for (final line in plan.lines) {
        final on = now.add(Duration(days: day));
        final at = tz.TZDateTime(
          tz.local,
          on.year,
          on.month,
          on.day,
          plan.hour,
        );
        day += 1;
        // This evening has already gone by, so the run starts tomorrow.
        if (at.isBefore(now)) continue;
        await _book(at, line);
      }
    } catch (error) {
      _api.event('nudges_sync_failed', {
        'error': error.runtimeType.toString(),
        'status': error is SoulApiException ? error.status : null,
      });
    }
  }

  /// Tonight is off. Called the moment an entry lands, because somebody who
  /// has already said something about today does not get asked about it.
  Future<void> answeredToday() async {
    try {
      await markHasWritten();
      await _prepare();
      await _plugin.cancel(id: _idFor(tz.TZDateTime.now(tz.local)));
    } catch (_) {
      // A notification that fails to cancel is one question too many, which
      // is not worth showing anybody an error about.
    }
  }

  Future<bool> _allowed() async {
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, sound: true);
      _api.event('nudges_permission', {'granted': granted ?? false});
      return granted ?? false;
    }

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    _api.event('nudges_permission', {'granted': granted ?? false});
    return granted ?? false;
  }

  /// One id per calendar day, so booking the same evening twice replaces it
  /// and cancelling today finds the right one without anything stored.
  int _idFor(tz.TZDateTime at) =>
      _base + (at.difference(DateTime.utc(2020)).inDays % 64);

  Future<void> _book(tz.TZDateTime at, String line) async {
    await _plugin.zonedSchedule(
      id: _idFor(at),
      // No title, the same as a reminder. The question is the whole of it.
      body: line,
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        android: AndroidNotificationDetails(
          'evening',
          'The evening question',
          channelDescription:
              'One question in the evening, on a day you have not written.',
          importance: Importance.defaultImportance,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    if (kDebugMode) debugPrint('evening booked for $at: $line');
  }
}
