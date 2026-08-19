import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../../api/client.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 3. Voice or text, on the same screen, at the same weight.
///
/// Typing is not a fallback. Recognition on children's voices is materially
/// worse than on adults, and worst for students from non English speaking
/// homes, so the students served least well by the mic are exactly the ones who
/// need the other path to look like a real choice.
///
/// Nothing records yet. The mic gesture is wired to the same place the typed
/// path goes, so the shape of the screen can be judged before task 3.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.onSubmitted,
    this.onTranscribed,
    this.onSkip,
    this.prompt = 'What is going on with you lately?',
    this.note = 'Anything. A few words is enough.',
    this.opener = 'to begin',
  });

  /// Called with the text once there is text, whether it was typed or spoken.
  /// A spoken entry has already been through the confirm step by then.
  final ValueChanged<String> onSubmitted;

  /// Called with a transcript that still needs confirming. The caller shows
  /// the confirm screen, because send or discard belongs to the flow rather
  /// than to this screen.
  final ValueChanged<String>? onTranscribed;
  final VoidCallback? onSkip;
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
  /// student talking about something that just happened should be able to set
  /// the phone on a desk and speak.
  bool _recording = false;

  /// Between stopping and the transcript arriving. The student should see that
  /// something is happening rather than a mic that went quiet.
  bool _transcribing = false;
  String? _failure;

  final _recorder = AudioRecorder();
  final _api = SoulApi.fromEnvironment();

  /// Drives the waves while recording. Runs only then, so an idle screen is
  /// not animating a thing nobody is looking at.
  late final _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

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
    _wave.dispose();
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
    _wave.repeat();
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
    _wave.stop();

    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });

    if (path == null) {
      setState(() => _transcribing = false);
      return;
    }

    final file = File(path);
    try {
      await _settled(file);
      final audio = await file.readAsBytes();
      final text = await _api.transcribe(audio, 'audio/wav');

      if (!mounted) return;
      setState(() => _transcribing = false);

      if (text.trim().isEmpty) {
        setState(() => _failure = 'Nothing came through. Try again.');
        return;
      }

      // Never straight into the field. The transcript is the permanent record
      // and the text the safety classifier reads, so the student sees it and
      // chooses send or discard first.
      widget.onTranscribed?.call(text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _transcribing = false;
        _failure = 'That did not go through. You can type it instead.';
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
        // is the thing most students will reach for, and it should not look
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
                        animation: _wave,
                        builder: (context, _) => CustomPaint(
                          painter: _WavePainter(_wave.value),
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
          if (!typing && widget.onSkip != null)
            SoulButton('Skip for now',
                kind: SoulButtonKind.ghost, onPressed: widget.onSkip),
        ],
      ),
    );
  }
}


/// The waves while someone is speaking.
///
/// Bars either side of the mic, rising and falling out of step so it reads as
/// a voice rather than a loading spinner. Nothing here is driven by the
/// microphone yet, because recording lands with task 3. When it does, the
/// amplitude replaces the sine and nothing else about this changes.
class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  static const _bars = 21;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SoulColors.clay.withValues(alpha: 0.7)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;

    final middle = size.height / 2;
    final spacing = size.width / (_bars + 1);

    for (var i = 0; i < _bars; i++) {
      // Out of step with its neighbours, and taller in the middle, so it reads
      // as a voice rather than a loading spinner.
      final phase = (t * 2 * math.pi) + i * 0.55;
      final centreness = 1 - ((i - (_bars - 1) / 2).abs() / ((_bars - 1) / 2));
      final height =
          (6 + 44 * math.sin(phase).abs() * (0.35 + 0.65 * centreness));
      final x = spacing * (i + 1);

      canvas.drawLine(
        Offset(x, middle - height / 2),
        Offset(x, middle + height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}
