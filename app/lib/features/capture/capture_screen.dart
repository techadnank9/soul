import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../api/client.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'live_speech.dart';

/// Screen 3. Voice or text, on the same screen, at the same weight.
///
/// Typing is not a fallback. Recognition on some voices is worse than on
/// others, so the people served least well by the mic are exactly the ones
/// who need the other path to look like a real choice.
///
/// Speaking writes into the same box typing does, while the person is still
/// talking. There is no separate transcript screen: the words are on the
/// screen as they are said, they can be fixed by hand, and send is the same
/// button either way.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.onSubmitted,
    this.onClose,
    this.onBack,
    this.prompt = 'What is going on with you lately?',
    this.note = 'Anything. A few words is enough.',
    this.opener = 'to begin',
  });

  /// Called with the text once the person sends it. spoken says whether the
  /// mic was used for any of it, and toneId is how it sounded, when the mic
  /// was used and the judgement came back in time.
  final void Function(String text, {required bool spoken, String? toneId})
      onSubmitted;

  /// Closes the screen. Not a skip and not an answer: it is the way out for
  /// somebody who opened this and decided not to say anything, which has to
  /// stay an ordinary thing to do rather than something to back out of.
  final VoidCallback? onClose;

  /// The previous screen, when this one sits in a sequence.
  final VoidCallback? onBack;

  final String prompt;
  final String note;
  final String opener;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  final _api = SoulApi.fromEnvironment();

  /// Tap to start, tap again to stop. Not hold.
  ///
  /// Holding a button for thirty seconds is tiring, it fails the moment a
  /// finger slips, and it cannot be done while putting the phone down.
  bool _recording = false;

  /// Between the tap and the connection opening, and between stopping and
  /// the last words landing. Which one is shown under the mic.
  bool _finishing = false;
  bool _connecting = false;
  String? _failure;

  /// The live connection, while one is open.
  LiveSpeech? _live;
  StreamSubscription<Uint8List>? _audio;

  /// What was in the box before the mic started, what the transcriber has
  /// settled on since, and what it is still deciding. The box shows all
  /// three in that order, so a person sees words arrive and firm up.
  String _before = '';
  String _committed = '';
  String _partial = '';

  /// Whether any of the text came from the mic, and how it sounded.
  bool _spoken = false;
  String? _toneId;
  Future<void>? _judging;

  /// The last few seconds of what the microphone heard, newest last, one
  /// value per bar between 0 and 1. Flat in silence, a spike per word.
  final List<double> _levels = List<double>.filled(_WavePainter.bars, 0);

  DateTime? _recordingSince;
  int _bytes = 0;
  int _partialChars = 0;

  /// A token fetched the moment the screen opens, so the tap on the mic has
  /// only a connection to make. Single use, so a fresh one is fetched after
  /// each recording. A failed fetch is retried on the tap.
  Future<String>? _token;

  void _prefetchToken() {
    _token = _api.speechToken().catchError((Object error) {
      _token = null;
      throw error;
    });
  }

  @override
  void initState() {
    super.initState();
    // Without this the send button never appears, because nothing tells the
    // screen that the field now has something in it.
    _controller.addListener(_onChanged);
    _prefetchToken();
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _audio?.cancel();
    _live?.close();
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_finishing) return;
    if (_recording) {
      await _stop();
    } else {
      await _start();
    }
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      _api.event('record_no_permission');
      if (!mounted) return;
      setState(() => _failure = 'Soul needs the microphone to hear you.');
      return;
    }

    setState(() {
      _failure = null;
      _finishing = true;
      _connecting = true;
    });

    // A token for one connection, from our own service, so the transcriber's
    // key never reaches the phone.
    final String token;
    try {
      token = await (_token ?? _api.speechToken());
      _token = null;
    } catch (error) {
      final status = error is SoulApiException ? error.status : null;
      _api.event('speech_failed', {'stage': 'token', 'status': status});
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _connecting = false;
        _failure = switch (status) {
          401 => 'This phone is not signed in yet. Close the app and open it again.',
          503 => 'Speech is not available right now. You can type it instead.',
          null => 'No connection. You can type it instead.',
          _ => 'That did not go through. You can type it instead.',
        };
      });
      return;
    }

    final live = LiveSpeech(token: token, language: 'en');
    try {
      await live.connect();
    } catch (error) {
      _api.event('speech_failed', {'stage': 'connect', 'error': error.runtimeType.toString()});
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _connecting = false;
        _failure = 'Could not reach the transcriber. You can type it instead.';
      });
      return;
    }

    _live = live;
    _before = _controller.text.trimRight();
    _committed = '';
    _partial = '';
    live.transcripts.listen(_onTranscript, onError: (Object error) {
      _api.event('speech_failed', {'stage': 'stream', 'error': error.toString().substring(0, 120)});
    });

    // Raw sixteen bit samples at sixteen kilohertz, mono, straight from the
    // microphone. Each chunk drives the waves, goes to the transcriber, and is
    // kept in memory for the tone judgement at the end.
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _recordingSince = DateTime.now();
    _bytes = 0;
    _audio = stream.listen((chunk) {
      _bytes += chunk.length;
      live.send(chunk);
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(_rms(chunk));
      });
    });

    _api.event('speech_started');
    _partialChars = 0;
    if (!mounted) return;
    setState(() {
      _recording = true;
      _finishing = false;
      _connecting = false;
      _spoken = true;
    });
  }

  /// The loudness of one chunk, 0 to 1. Root mean square of the samples,
  /// read two bytes at a time so an unaligned buffer cannot throw, against
  /// a ceiling well under full scale so ordinary speech fills the bar.
  static double _rms(Uint8List chunk) {
    final bytes = ByteData.sublistView(chunk);
    final count = chunk.length ~/ 2;
    if (count == 0) return 0;
    var sum = 0.0;
    for (var i = 0; i < count; i++) {
      final sample = bytes.getInt16(i * 2, Endian.little).toDouble();
      sum += sample * sample;
    }
    final rms = math.sqrt(sum / count);
    // About 2500 is a clear speaking voice a hand's width from the phone.
    // Square root of the ratio so quiet speech still shows as movement.
    return math.sqrt((rms / 2500).clamp(0.0, 1.0));
  }

  void _onTranscript(Transcript transcript) {
    if (!mounted) return;
    setState(() {
      if (transcript.committed) {
        _committed = _join(_committed, transcript.text);
        _partial = '';
      } else {
        _partial = transcript.text;
        _partialChars = transcript.text.length;
      }
      _show();
    });
  }

  static String _join(String a, String b) {
    if (a.isEmpty) return b.trim();
    if (b.trim().isEmpty) return a;
    return '$a ${b.trim()}';
  }

  /// Puts the three parts in the box with the cursor at the end, so the
  /// person watches words arrive rather than fights the caret.
  void _show() {
    final text = _join(_join(_before, _committed), _partial);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _stop() async {
    final live = _live;
    setState(() {
      _recording = false;
      _finishing = true;
    });
    await _audio?.cancel();
    _audio = null;
    await _recorder.stop();
    for (var i = 0; i < _levels.length; i++) {
      _levels[i] = 0;
    }

    final recordedMs = _recordingSince == null
        ? null
        : DateTime.now().difference(_recordingSince!).inMilliseconds;

    // Ask for the tail to be settled, give it a moment, then let go.
    if (live != null) {
      await live.finish(const Duration(milliseconds: 2500));
      final held = live.audio;
      _live = null;
      await live.close();
      // If the commit never came back, the last guess is the best there is,
      // and it stays on the screen rather than vanishing.
      if (mounted) {
        setState(() {
          if (_partial.isNotEmpty) {
            _committed = _join(_committed, _partial);
            _partial = '';
          }
          _show();
        });
      }

      _api.event('speech_stopped', {
        'recorded_ms': recordedMs,
        'bytes': _bytes,
        'chars': _committed.length,
        'partial_chars': _partialChars,
      });
      _prefetchToken();

      // How it sounded, judged once from the audio the phone held, then the
      // audio goes. Nobody waits on this: send can happen before it lands.
      if (held.length > 16000) {
        _judging = _api.tone(held).then((id) {
          _toneId = id;
        }).catchError((Object error) {
          _api.event('tone_failed', {
            'status': error is SoulApiException ? error.status : null,
          });
        });
      }
    }

    if (!mounted) return;
    setState(() => _finishing = false);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (_recording) await _stop();
    // A tone still on its way gets one more second, then goes without.
    if (_judging != null) {
      await _judging!.timeout(const Duration(seconds: 1), onTimeout: () {});
    }
    widget.onSubmitted(text, spoken: _spoken, toneId: _toneId);
  }

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().isNotEmpty;

    return Screen(
      body: [
        // Back top left, close top right. Each absent when there is nowhere
        // to go that way.
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 16, bottom: 12),
                child: Icon(Icons.chevron_left, size: 26, color: SoulColors.text3),
              ),
            ),
          ),
        if (widget.onClose != null)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: const Padding(
                padding: EdgeInsets.only(left: 16, bottom: 12),
                child: Icon(Icons.close, size: 24, color: SoulColors.text3),
              ),
            ),
          ),
        Label(widget.opener),
        const SizedBox(height: 14),
        Text(widget.prompt, style: SoulType.heading),
        const SizedBox(height: 14),
        Text(widget.note, style: SoulType.secondary),
        const SizedBox(height: 24),
        SoulField(
          controller: _controller,
          hint: 'Type it here, or tap the mic and talk',
        ),
        // The mic sits low, down where a thumb rests, with room around it.
        const SizedBox(height: 200),
        Center(
          child: Column(
            children: [
              // The waves sit above the mic. While recording they follow the
              // voice; the rest of the time the space is held open so nothing
              // jumps when recording starts.
              SizedBox(
                height: 64,
                width: double.infinity,
                child: _recording
                    ? CustomPaint(
                        painter: _WavePainter(List<double>.of(_levels)),
                      )
                    : null,
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _toggleRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _recording ? 92 : 84,
                  height: _recording ? 92 : 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? SoulColors.clay : SoulColors.s2,
                    border: Border.all(
                      color: _recording ? SoulColors.clay : SoulColors.border2,
                    ),
                    boxShadow: _recording
                        ? [
                            const BoxShadow(
                              color: Color(0x59EA5F17),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    // A square to stop, because a mic that means stop is the
                    // same picture meaning two opposite things.
                    _recording ? Icons.stop_rounded : Icons.mic_none,
                    size: 32,
                    color: _recording ? Colors.white : SoulColors.text2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_failure != null) ...[
                Text(
                  _failure!,
                  textAlign: TextAlign.center,
                  style: SoulType.secondary.copyWith(color: SoulColors.clay),
                ),
                const SizedBox(height: 8),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Label(
                  _finishing
                      ? (_connecting ? 'connecting' : 'finishing')
                      : _recording
                          ? 'tap to stop'
                          : 'tap to speak',
                  key: ValueKey('$_finishing $_recording'),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: typing
          ? SoulButton(
              'Send it',
              kind: SoulButtonKind.filled,
              onPressed: _finishing ? null : _send,
            )
          : null,
    );
  }
}

/// The waves while someone is speaking.
///
/// One bar per level from the microphone, newest on the right, so the line
/// scrolls the way a voice recorder does: flat while nobody speaks, spiking
/// with each word.
class _WavePainter extends CustomPainter {
  _WavePainter(this.levels);
  final List<double> levels;

  static const bars = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SoulColors.clay.withValues(alpha: 0.8)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final middle = size.height / 2;
    final spacing = size.width / (bars + 1);

    for (var i = 0; i < bars; i++) {
      final level = i < levels.length ? levels[i] : 0.0;
      final height = 6 + 44 * level;
      final x = spacing * (i + 1);
      canvas.drawLine(
        Offset(x, middle - height / 2),
        Offset(x, middle + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) {
    if (old.levels.length != levels.length) return true;
    for (var i = 0; i < levels.length; i++) {
      if (old.levels[i] != levels[i]) return true;
    }
    return false;
  }
}
