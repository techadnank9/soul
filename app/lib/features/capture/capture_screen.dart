import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 3. Voice or text, on the same screen, at the same weight.
///
/// Typing is not a fallback. Recognition on children's voices is materially
/// worse than on adults, and worst for users from non English speaking
/// homes, so the users served least well by the mic are exactly the ones who
/// need the other path to look like a real choice.
///
/// Nothing records yet. The mic gesture is wired to the same place the typed
/// path goes, so the shape of the screen can be judged before task 3.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.onSubmitted,
    this.onTranscribed,
    this.onClose,
    this.onBack,
    this.prompt = 'What is going on with you lately?',
    this.note = 'Anything. A few words is enough.',
    this.opener = 'to begin',
  });

  /// Called with the text once there is text, whether it was typed or spoken.
  /// A spoken entry has already been through the confirm step by then.
  final ValueChanged<String> onSubmitted;

  /// Called with a transcript that still needs confirming. The caller shows
  /// the confirm screen, because send or discard belongs to the flow rather
  /// than to this screen. The transcript carries the handle for how it
  /// sounded, which goes with the entry or goes when it is discarded.
  final ValueChanged<Transcript>? onTranscribed;

  /// Closes the screen. Not a skip and not an answer: it is the way out for
  /// somebody who opened this and decided not to say anything, which has to
  /// stay an ordinary thing to do rather than something to back out of.
  final VoidCallback? onClose;

  /// The previous screen, when this one sits in a sequence. Shown top left
  /// as a chevron, the same one every screen in first run uses.
  final VoidCallback? onBack;

  final String prompt;
  final String note;
  final String opener;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();

  /// Tap to start, tap again to stop. Not hold.
  ///
  /// Holding a button for thirty seconds is tiring, it fails the moment a
  /// finger slips, and it cannot be done while putting the phone down. A
  /// user talking about something that just happened should be able to set
  /// the phone on a desk and speak.
  bool _recording = false;

  /// Between stopping and the transcript arriving. The user should see that
  /// something is happening rather than a mic that went quiet.
  bool _transcribing = false;
  String? _failure;

  final _recorder = AudioRecorder();
  final _api = SoulApi.fromEnvironment();

  /// The last few seconds of what the microphone heard, newest last, one
  /// value per bar between 0 and 1. The waves are drawn from this and from
  /// nothing else, so silence is flat and a word is a spike, the way a voice
  /// recorder looks.
  final List<double> _levels = List<double>.filled(_WavePainter.bars, 0);
  StreamSubscription<Amplitude>? _listening;

  /// Decibels relative to full scale into a bar height. Quiet rooms sit near
  /// minus sixty and a voice a hand's width from the phone reaches minus ten,
  /// so that is the range that fills the bar.
  static double _level(double dbfs) {
    if (!dbfs.isFinite) return 0;
    return ((dbfs + 60) / 50).clamp(0.0, 1.0);
  }

  void _listen() {
    _listening?.cancel();
    _listening = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 70))
        .listen((amplitude) {
      if (!mounted) return;
      setState(() {
        _levels.removeAt(0);
        _levels.add(_level(amplitude.current));
      });
    });
  }

  void _stopListening() {
    _listening?.cancel();
    _listening = null;
    for (var i = 0; i < _levels.length; i++) {
      _levels[i] = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    // Without this the send button never appears, because nothing tells the
    // screen that the field now has something in it.
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _listening?.cancel();
    _recorder.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_transcribing) return;

    if (_recording) {
      await _stopAndTranscribe();
      return;
    }

    if (!await _recorder.hasPermission()) {
      // The permission sheet can sit there for as long as the user leaves
      // it, and the screen can be closed underneath it.
      _api.event('record_no_permission');
      if (!mounted) return;
      setState(() => _failure = 'Soul needs the microphone to hear you.');
      return;
    }

    // The system temporary directory, so the file lives outside anything that
    // gets backed up, and only until the upload returns.
    final path =
        '${Directory.systemTemp.path}/soul_capture_${DateTime.now().millisecondsSinceEpoch}.wav';

    // Wav rather than m4a. An aac container has to be finalised when recording
    // stops, and a short clip can reach the provider before that has happened,
    // which comes back as corrupt audio. Wav is written straight through.
    // Sixteen kilohertz mono is what speech recognition wants anyway, so the
    // file is not much larger than the compressed one would have been.
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _recording = true;
      _failure = null;
    });
    _listen();
  }

  /// Waits for the recorder to finish writing.
  ///
  /// stop() returns the path before the last buffers have reached disk, and
  /// reading too early sends a header with almost no audio behind it, which
  /// the provider rejects as corrupt. Poll until the size stops changing.
  static Future<void> _settled(File file) async {
    var previous = -1;
    for (var attempt = 0; attempt < 20; attempt++) {
      final size = file.existsSync() ? await file.length() : 0;
      if (size > 0 && size == previous) return;
      previous = size;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _stopAndTranscribe() async {
    final path = await _recorder.stop();

    // Finishing the file is real elapsed time and this screen can be left
    // during it. Touching the animation after dispose throws, so the mounted
    // check comes first.
    if (!mounted) return;
    _stopListening();

    setState(() {
      _recording = false;
      _transcribing = true;
    });

    if (path == null) {
      setState(() => _transcribing = false);
      return;
    }

    final file = File(path);
    final startedAt = DateTime.now();
    var bytes = 0;
    try {
      await _settled(file);
      final audio = await file.readAsBytes();
      bytes = audio.length;
      final transcript = await _api.transcribe(audio, 'audio/wav');
      _api.event('transcribe_ok', {
        'bytes': bytes,
        'ms': DateTime.now().difference(startedAt).inMilliseconds,
        'words': transcript.text.trim().split(RegExp(r'\s+')).length,
        'tone': transcript.toneId != null,
      });

      if (!mounted) return;
      setState(() => _transcribing = false);

      if (transcript.text.trim().isEmpty) {
        setState(() => _failure = 'Nothing came through. Try again.');
        return;
      }

      // Never straight into the field. The transcript is the permanent record
      // and the text the safety classifier reads, so the user sees it and
      // chooses send or discard first.
      widget.onTranscribed?.call(transcript);
    } catch (error) {
      final status = error is SoulApiException ? error.status : null;
      _api.event('transcribe_failed', {
        'status': status,
        'bytes': bytes,
        'ms': DateTime.now().difference(startedAt).inMilliseconds,
        'error': status == null ? error.runtimeType.toString() : null,
      });
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        // Which thing failed, in one line, so a person can act on it. The
        // exact words in a status are on the server, never shown here.
        _failure = switch (status) {
          403 => 'Nothing left the app. Agree to the terms first.',
          401 => 'This phone is not signed in yet. Close the app and open it again.',
          422 => 'Nothing came through. Try again.',
          final int s when s >= 500 => 'The service had a problem. Try again in a moment.',
          null => 'No connection. You can type it instead.',
          _ => 'That did not go through. You can type it instead.',
        };
      });
    } finally {
      // The audio is deleted the moment we are done with it, success or not.
      if (file.existsSync()) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
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
          hint: 'Type it here',
        ),
        // The mic sits low, down where a thumb rests, with room around it. It
        // is the thing most users will reach for, and it should not look
        // like an afterthought under the typing field.
        const SizedBox(height: 200),
        Center(
          child: Column(
            children: [
              // The waves sit above the mic. While recording they move; the
              // rest of the time the space is held open so nothing jumps when
              // recording starts.
              SizedBox(
                height: 64,
                width: double.infinity,
                child: _recording
                    ? AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => CustomPaint(
                          painter: _WavePainter(List<double>.of(_levels), recording: _recording),
                        ),
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
                  _transcribing
                      ? 'writing it down'
                      : _recording
                          ? 'tap to stop'
                          : 'tap to speak',
                  key: ValueKey('$_recording$_transcribing'),
                ),
              ),
            ],
          ),
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (typing)
            SoulButton('Send', kind: SoulButtonKind.filled, onPressed: _send),
        ],
      ),
    );
  }
}


/// The waves while someone is speaking.
///
/// One bar per level from the microphone, newest on the right, so the line
/// scrolls the way a voice recorder does: flat while nobody speaks, spiking
/// with each word. Before recording starts the bars sit at their resting
/// height so nothing jumps when they come alive.
class _WavePainter extends CustomPainter {
  _WavePainter(this.levels, {required this.recording});
  final List<double> levels;
  final bool recording;

  static const bars = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SoulColors.clay.withValues(alpha: recording ? 0.8 : 0.35)
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
  bool shouldRepaint(covariant _WavePainter old) =>
      old.recording != recording || !_same(old.levels, levels);

  static bool _same(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
