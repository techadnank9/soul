import 'dart:convert';
import 'dart:io';
import '../data/session_store.dart';
import 'models.dart';

/// The API client.
///
/// dart:io rather than a package. Every call here is JSON over GET or POST and
/// the standard library makes all of them, and every package added here is a
/// maintenance liability and a name in a district data agreement.
class SoulApi {
  SoulApi({required this.baseUrl, required this.token});

  /// Set at build time so a debug build can point at a laptop and a release
  /// build cannot point anywhere by accident.
  factory SoulApi.fromEnvironment() => SoulApi(
        baseUrl: const String.fromEnvironment(
          'SOUL_API',
          defaultValue: 'http://localhost:8080',
        ),
        token: const String.fromEnvironment(
          'SOUL_STUDENT',
          defaultValue: 'student_with_consent',
        ),
      );

  final String baseUrl;

  /// The roster token from the build. It is what the development path runs on
  /// and what a student carries until they sign in.
  final String token;

  /// One client for the whole app.
  ///
  /// Every screen builds its own SoulApi and none of them closed it, so each
  /// pass through the loop left an HttpClient holding keep alive sockets and
  /// timers for three minutes. Shared and static, it is opened once and lives
  /// as long as the process, which is the only lifetime that fits how these
  /// objects are created.
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    // The Mirror thinks for a while. Cutting it off client side would show a
    // student a failure for a response that was on its way.
    ..idleTimeout = const Duration(minutes: 3);

  /// How long a read is allowed to take before it counts as failed.
  ///
  /// A connection that opens and then goes quiet is not covered by the
  /// connection timeout, and the three screens that read are the ones a
  /// student sits in front of. Without a deadline here their loading state has
  /// no end and no way out. Writes are deliberately not given one: the Mirror
  /// thinks for a while and cutting it off would show a failure for a response
  /// that was on its way.
  static const _readDeadline = Duration(seconds: 20);

  /// A stored session token when there is one, the roster token otherwise.
  /// The server takes either, so nothing above this line has to know which of
  /// the two went out.
  /// Development only. Set by the skip button on the first screen so the app
  /// can be looked at as the seeded demo student, who has a week of entries
  /// behind them. It is deliberately not stored anywhere: it lasts as long as
  /// the process and a real launch never sets it.
  static String? demoStudent;

  Future<String> _bearer() async {
    if (demoStudent != null) return demoStudent!;
    return await sessionToken() ?? token;
  }

  Future<List<dynamic>> _getList(String path) async {
    final bearer = await _bearer();
    final request = await _client.getUrl(Uri.parse('$baseUrl$path'));
    request.headers.set('authorization', 'Bearer $bearer');

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      await _forgetDeadToken(response.statusCode);
      throw SoulApiException(response.statusCode, text);
    }
    return jsonDecode(text) as List<dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final bearer = await _bearer();
    final request = await _client.getUrl(Uri.parse('$baseUrl$path'));
    request.headers.set('authorization', 'Bearer $bearer');

    final response = await request.close().timeout(_readDeadline);
    final text =
        await response.transform(utf8.decoder).join().timeout(_readDeadline);

    if (response.statusCode >= 400) {
      await _forgetDeadToken(response.statusCode);
      throw SoulApiException(response.statusCode, text);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// A session that the server no longer accepts is cleared here.
  ///
  /// Tokens expire after six months and can be revoked, so a dead one is an
  /// ordinary state rather than a fault. Without this the app kept sending it
  /// forever: every screen failed, every launch went to home because a token
  /// was stored, and there was no way back to signing in short of deleting the
  /// app.
  Future<void> _forgetDeadToken(int status) async {
    if (status != 401) return;
    if (await sessionToken() == null) return;
    await clearSessionToken();
  }

  /// Posts that are a student waiting on a button, rather than a model
  /// thinking, get the same deadline the reads do.
  ///
  /// Without it a connection that opens and then goes quiet left the cue card
  /// on Holding with no end and no way out. Submitting an entry and asking for
  /// the Mirror are deliberately not in this set: those wait on a model and
  /// cutting them off shows a student a failure for an answer that was on its
  /// way.
  static const _quick = {
    '/auth/apple',
    '/profile',
    '/baseline',
    '/consent',
    '/outcomes',
  };

  bool _isQuick(String path) =>
      _quick.contains(path) || path.startsWith('/cards/');

  Future<Map<String, dynamic>> _send(
    String method,
    String path,
    Object? body,
  ) async {
    final bearer = await _bearer();
    final request = await _client.openUrl(
      method,
      Uri.parse('$baseUrl$path'),
    );
    request.headers.set('content-type', 'application/json');
    request.headers.set('authorization', 'Bearer $bearer');
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close().timeout(_readDeadline);
    final text =
        await response.transform(utf8.decoder).join().timeout(_readDeadline);

    if (response.statusCode >= 400) {
      await _forgetDeadToken(response.statusCode);
      throw SoulApiException(response.statusCode, text);
    }
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patch(String path, Object? body) =>
      _send('PATCH', path, body);

  Future<Map<String, dynamic>> _delete(String path) =>
      _send('DELETE', path, null);

  Future<Map<String, dynamic>> _post(String path, Object? body) async {
    final bearer = await _bearer();
    final request = await _client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.set('content-type', 'application/json');
    request.headers.set('authorization', 'Bearer $bearer');
    if (body != null) request.write(jsonEncode(body));

    final quick = _isQuick(path);
    final response = quick
        ? await request.close().timeout(_readDeadline)
        : await request.close();
    final joined = response.transform(utf8.decoder).join();
    final text = quick ? await joined.timeout(_readDeadline) : await joined;

    if (response.statusCode >= 400) {
      await _forgetDeadToken(response.statusCode);
      throw SoulApiException(response.statusCode, text);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// Audio in, text out. The bytes are sent and forgotten; the server deletes
  /// them the moment the provider returns a transcript. The same bytes are
  /// listened to for how they sounded, and the handle for that rides back
  /// with the words.
  Future<Transcript> transcribe(List<int> audio, String contentType) async {
    final bearer = await _bearer();
    final request = await _client.postUrl(Uri.parse('$baseUrl/transcribe'));
    request.headers.set('content-type', contentType);
    request.headers.set('authorization', 'Bearer $bearer');
    request.add(audio);

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      await _forgetDeadToken(response.statusCode);
      throw SoulApiException(response.statusCode, text);
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    return Transcript(
      text: json['text'] as String,
      toneId: json['toneId'] as String?,
    );
  }

  /// A discarded transcript takes how it sounded with it.
  Future<void> discardTone(String toneId) async {
    await _delete('/transcribe/$toneId');
  }

  /// Sign in with Apple, traded for a session token.
  ///
  /// The bearer on this one call is still the roster token, because this is
  /// what links an Apple account to the student the district already rostered.
  /// Two strings go out and nothing else: no scopes were asked for, so there
  /// is no name and no email to send.
  ///
  /// The reply also carries an expiry. It is not kept, because the only thing
  /// the client can do with an expired token is be told so by the server.
  Future<String> signInWithApple({
    required String identityToken,
    required String appleUserId,
  }) async {
    final json = await _post('/auth/apple', {
      'identityToken': identityToken,
      'appleUserId': appleUserId,
    });
    return json['token'] as String;
  }

  Future<SubmitResult> submit({
    required String text,
    required bool spoken,
    int? durationMs,
    String? toneId,
  }) async {
    final json = await _post('/entries', {
      'text': text,
      'inputMode': spoken ? 'voice' : 'typed',
      'transcriptConfirmed': spoken,
      'durationMs': ?durationMs,
      'localHour': DateTime.now().hour,
      'toneId': ?toneId,
    });
    return SubmitResult.fromJson(json);
  }

  Future<MirrorResult> mirror(String entryId) async {
    return MirrorResult.fromJson(await _post('/entries/$entryId/mirror', null));
  }

  Future<String> hold({
    required String entryId,
    required String chosen,
    String? offered,
    int horizonDays = 3,
  }) async {
    final json = await _post('/decisions', {
      'entryId': entryId,
      'chosenText': chosen,
      'offeredText': ?offered,
      'horizonDays': horizonDays,
    });
    return json['decisionId'] as String;
  }

  /// The profile from first run. Skipped questions are simply absent, and a
  /// profile where everything was skipped is not sent at all.
  ///
  /// The timezone is not sent. The server derives it from the region.
  /// A field with a null value is sent as null, which empties it. A field that
  /// is absent is left alone. Do not collapse the two.
  Future<void> profile(Map<String, Object?> fields) async {
    if (fields.isEmpty) return;
    await _post('/profile', fields);
  }

  /// What the app holds about this student. The profile tab shows exactly
  /// this and nothing it has not been told.
  Future<Map<String, dynamic>> profileHeld() => _get('/profile');

  /// The baseline set. Skipped questions are simply absent.
  Future<void> baseline(String setVersion, List<int?> answers) async {
    final chosen = <Map<String, int>>[
      for (var i = 0; i < answers.length; i++)
        if (answers[i] != null)
          {'questionIndex': i, 'choiceIndex': answers[i]!},
    ];
    if (chosen.isEmpty) return;
    await _post('/baseline', {'setVersion': setVersion, 'answers': chosen});
  }

  /// The week behind the home screen.
  ///
  /// The week is bounded by the student's own timezone on the server, so a
  /// Sunday evening in Los Angeles lands on Sunday. Nothing here asks the
  /// device what day it is.
  Future<WeekView> week() async => WeekView.fromJson(await _get('/week'));

  /// One day, earliest first. The date is YYYY-MM-DD and it is the string the
  /// week gave back, passed through untouched.
  /// Every day this student has written on, newest first. Days with nothing
  /// in them are not in the list, because a calendar of blanks reads as a
  /// record of what somebody did not do.
  /// How it went, days later. The student's own verdict, and the only place
  /// the two sections on the returning tab come from.
  Future<void> recordOutcome({
    required String decisionId,
    String? whatHappened,
    String? felt,
  }) async {
    await _post('/outcomes', {
      'decisionId': decisionId,
      'whatHappened': ?whatHappened,
      'felt': ?felt,
    });
  }

  Future<List<DayCount>> days() async {
    final json = await _getList('/days');
    return [for (final day in json) DayCount.fromJson(day as Map<String, dynamic>)];
  }

  Future<DayView> day(String date) async =>
      DayView.fromJson(await _get('/day/$date'));

  /// A cue card answered yes or no.
  ///
  /// Yes becomes a decision on the server, the same one the Mirror path
  /// writes, and the check back is scheduled from it. No writes no decision
  /// and books nothing, so the reply carries no decision to hand back and the
  /// answer is the whole of what was recorded.
  ///
  /// horizonDays goes out only with a yes, because there is nothing to come
  /// back to otherwise. detail is absent when the student wrote nothing,
  /// which is most of the time and is a complete answer.
  Future<String?> answerCard({
    required String cardId,
    required bool yes,
    String? detail,
    int? horizonDays,
  }) async {
    final booked = yes ? horizonDays : null;
    final json = await _post('/cards/$cardId/answer', {
      'answer': yes ? 'yes' : 'no',
      'detail': ?detail,
      'horizonDays': ?booked,
    });
    return json['decisionId'] as String?;
  }

  /// Everything that has come back for this student, what each of those is
  /// doing to them, and what is still too thin to say anything about.
  /// One reflection with the entries behind it. The theme carries spaces and
  /// apostrophes, so it goes as a query parameter rather than a path segment.
  Future<ReflectionView> reflection(String theme) async {
    final json = await _get('/reflection?theme=${Uri.encodeQueryComponent(theme)}');
    return ReflectionView.fromJson(json);
  }

  /// The people this student writes about, most recently mentioned first.
  Future<List<PersonRow>> people() async {
    final json = await _getList('/people');
    return [
      for (final person in json) PersonRow.fromJson(person as Map<String, dynamic>),
    ];
  }

  Future<PersonView> person(String id) async =>
      PersonView.fromJson(await _get('/people/$id'));

  /// The student's own words about somebody. Whatever they set here is theirs
  /// and is never written over by a later profile run.
  Future<void> editPerson(
    String id, {
    String? name,
    String? relation,
    String? reach,
  }) async {
    await _patch('/people/$id', {
      'name': ?name,
      'relation': ?relation,
      'reach': ?reach,
    });
  }

  /// Removes the person and the links. The entries stay.
  Future<void> forgetPerson(String id) async {
    await _delete('/people/$id');
  }

  Future<PatternsView> patterns() async =>
      PatternsView.fromJson(await _get('/patterns'));

  Future<void> answerPattern(String candidateId, String answer) async {
    await _post('/patterns/answer', {
      'candidateId': candidateId,
      'answer': answer,
    });
  }
}

class SoulApiException implements Exception {
  SoulApiException(this.status, this.body);
  final int status;
  final String body;

  @override
  String toString() => 'api returned $status';
}
