import 'dart:async';

import 'package:record/record.dart';

import '../../api/client.dart';
import 'live_speech.dart';

/// Speaking instead of typing, into any box in the app.
///
/// The capture screen has its own recorder because it does more: the waves,
/// the tone judgement, the audio held in memory to the end. This is the
/// small version, for a box where the only thing wanted is the words.
///
/// It owns one recorder and one connection and hands back text as it
/// arrives. Every failure is the same failure to the caller: it stopped, and
/// the keyboard is still there.
class Dictation {
  Dictation({required this.api, required this.onText});

  final SoulApi api;

  /// Called with everything said so far, settled words and the current
  /// guess together, so a field can be set rather than appended to.
  final void Function(String text) onText;

  final _recorder = AudioRecorder();
  LiveSpeech? _live;
  StreamSubscription<dynamic>? _audio;
  String _committed = '';
  String _partial = '';

  bool get listening => _live != null;

  /// Null when it started, or a short line to show when it did not.
  Future<String?> start() async {
    if (!await _recorder.hasPermission()) {
      api.event('dictation_no_permission');
      return 'Soul needs the microphone to hear you.';
    }

    final String token;
    try {
      token = await api.speechToken();
    } catch (_) {
      api.event('dictation_failed', {'stage': 'token'});
      return 'Speech is not available right now.';
    }

    final live = LiveSpeech(token: token, language: 'en');
    try {
      await live.connect();
    } catch (_) {
      api.event('dictation_failed', {'stage': 'connect'});
      return 'Could not reach the transcriber.';
    }

    _live = live;
    _committed = '';
    _partial = '';
    live.transcripts.listen((transcript) {
      if (transcript.committed) {
        _committed = _join(_committed, transcript.text);
        _partial = '';
      } else {
        _partial = transcript.text;
      }
      onText(_join(_committed, _partial));
    }, onError: (Object _) {});

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    _audio = stream.listen(live.send);
    api.event('dictation_started');
    return null;
  }

  /// Stops, waits briefly for the last words to settle, and leaves the text
  /// in the box either way.
  Future<void> stop() async {
    await _audio?.cancel();
    _audio = null;
    await _recorder.stop();

    final live = _live;
    _live = null;
    if (live == null) return;
    try {
      await live.finish(const Duration(seconds: 3));
    } catch (_) {
      // The words already on screen are the words. Nothing else is owed.
    }
    await live.close();
    onText(_join(_committed, _partial));
  }

  Future<void> dispose() async {
    await _audio?.cancel();
    await _recorder.dispose();
    await _live?.close();
    _live = null;
  }

  static String _join(String a, String b) {
    if (a.isEmpty) return b.trim();
    if (b.trim().isEmpty) return a;
    return '$a ${b.trim()}';
  }
}
