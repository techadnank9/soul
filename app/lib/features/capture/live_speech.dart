import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// One live connection to the transcriber.
///
/// Audio goes up as it is recorded and words come back while the person is
/// still speaking. The connection is opened with a single use token from our
/// own service, so no key lives on the phone, and it is closed the moment
/// the person stops. The audio is kept in memory only until then, for the
/// tone judgement, and then dropped with this object.
///
/// dart:io's WebSocket, no package, because the protocol is a handful of
/// JSON messages.
class Transcript {
  const Transcript(this.text, {required this.committed});
  final String text;

  /// Settled words, as opposed to the transcriber's current guess at the
  /// words still being spoken.
  final bool committed;
}

class LiveSpeech {
  LiveSpeech({required this.token, this.language = 'en'});

  final String token;
  final String language;

  WebSocket? _socket;
  final _transcripts = StreamController<Transcript>.broadcast();
  final _held = BytesBuilder(copy: false);
  Completer<void>? _settled;

  Stream<Transcript> get transcripts => _transcripts.stream;

  static const _sampleRate = 16000;

  Future<void> connect() async {
    final url = Uri(
      scheme: 'wss',
      host: 'api.elevenlabs.io',
      path: '/v1/speech-to-text/realtime',
      queryParameters: {
        'model_id': 'scribe_v2_realtime',
        'audio_format': 'pcm_16000',
        'language_code': language,
        // Manual, so the words on the screen keep flowing as a guess and are
        // settled when the person stops rather than on every pause.
        'commit_strategy': 'manual',
        'token': token,
      },
    );
    final socket = await WebSocket.connect(url.toString())
        .timeout(const Duration(seconds: 8));
    _socket = socket;
    socket.listen(_onMessage, onError: _transcripts.addError, onDone: () {
      _settled?.complete();
    });
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) return;
    final message = jsonDecode(raw);
    if (message is! Map) return;
    final type = message['message_type'];
    final text = (message['text'] as String?) ?? '';
    switch (type) {
      case 'partial_transcript':
        _transcripts.add(Transcript(text, committed: false));
      case 'committed_transcript':
      case 'committed_transcript_with_timestamps':
        _transcripts.add(Transcript(text, committed: true));
        _settled?.complete();
      case 'session_started':
      case 'warning':
        break;
      default:
        if (message['error'] != null) {
          _transcripts.addError(StateError('$type: ${message['error']}'));
        }
    }
  }

  /// One chunk of sixteen bit samples. Kept, and sent.
  void send(Uint8List chunk) {
    _held.add(chunk);
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    socket.add(jsonEncode({
      'message_type': 'input_audio_chunk',
      'audio_base_64': base64Encode(chunk),
      'sample_rate': _sampleRate,
    }));
  }

  /// Asks the transcriber to settle everything it has heard, and waits for
  /// that, up to the limit. A tenth of a second of silence goes with the
  /// request so there is always a chunk to carry the commit.
  Future<void> finish(Duration limit) async {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;
    final settled = Completer<void>();
    _settled = settled;
    socket.add(jsonEncode({
      'message_type': 'input_audio_chunk',
      'audio_base_64': base64Encode(Uint8List(3200)),
      'sample_rate': _sampleRate,
      'commit': true,
    }));
    await settled.future.timeout(limit, onTimeout: () {});
  }

  /// Everything the microphone produced, as a wav, for the tone judgement.
  Uint8List get audio {
    final pcm = _held.toBytes();
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }
    ascii(0, 'RIFF');
    header.setUint32(4, 36 + pcm.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, 1, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, pcm.length, Endian.little);
    final out = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(pcm);
    return out.toBytes();
  }

  Future<void> close() async {
    await _socket?.close();
    _socket = null;
    await _transcripts.close();
    _held.clear();
  }
}
