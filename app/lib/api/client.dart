import 'dart:convert';
import 'dart:io';
import 'models.dart';

/// The API client.
///
/// dart:io rather than a package. There are four calls and the standard library
/// makes all of them, and every package added here is a maintenance liability
/// and a name in a district data agreement.
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
  final String token;

  final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10)
    // The Mirror thinks for a while. Cutting it off client side would show a
    // student a failure for a response that was on its way.
    ..idleTimeout = const Duration(minutes: 3);

  Future<Map<String, dynamic>> _post(String path, Object? body) async {
    final request = await _client.postUrl(Uri.parse('$baseUrl$path'));
    request.headers.set('content-type', 'application/json');
    request.headers.set('authorization', 'Bearer $token');
    if (body != null) request.write(jsonEncode(body));

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode >= 400) {
      throw SoulApiException(response.statusCode, text);
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<SubmitResult> submit({
    required String text,
    required bool spoken,
    int? durationMs,
  }) async {
    final json = await _post('/entries', {
      'text': text,
      'inputMode': spoken ? 'voice' : 'typed',
      'transcriptConfirmed': spoken,
      'durationMs': ?durationMs,
      'localHour': DateTime.now().hour,
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
