import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    this.onSkip,
    this.prompt = 'What is going on with you lately?',
    this.note = 'Anything. A few words is enough.',
    this.opener = 'to begin',
  });

  final ValueChanged<String> onSubmitted;
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
  bool _holding = false;

  /// Drives the waves while the mic is held. Runs only while held, so an idle
  /// screen is not animating a thing nobody is looking at.
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
    _controller.dispose();
    super.dispose();
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
        // The mic sits low and centred, with room around it. It is the
        // thing most students will reach for, and it should not look like an
        // afterthought under the typing field.
        const SizedBox(height: 90),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTapDown: (_) {
                  setState(() => _holding = true);
                  _wave.repeat();
                },
                onTapUp: (_) {
                  setState(() => _holding = false);
                  _wave.stop();
                },
                onTapCancel: () {
                  setState(() => _holding = false);
                  _wave.stop();
                },
                child: SizedBox(
                  width: 220,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_holding)
                        AnimatedBuilder(
                          animation: _wave,
                          builder: (context, _) => CustomPaint(
                            size: const Size(220, 130),
                            painter: _WavePainter(_wave.value),
                          ),
                        ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: _holding ? 92 : 84,
                        height: _holding ? 92 : 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _holding ? SoulColors.clay : SoulColors.s2,
                          border: Border.all(
                            color: _holding
                                ? SoulColors.clay
                                : SoulColors.border2,
                          ),
                          boxShadow: _holding
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
                          Icons.mic_none,
                          size: 32,
                          color: _holding ? Colors.white : SoulColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Label(
                  _holding ? 'listening' : 'hold to speak',
                  key: ValueKey(_holding),
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

  static const _bars = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SoulColors.clay.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5;

    final middle = size.height / 2;
    final gap = 13.0;

    for (var side = -1; side <= 1; side += 2) {
      for (var i = 1; i <= _bars; i++) {
        final phase = (t * 2 * math.pi) + i * 0.7;
        final falloff = 1 - (i / (_bars + 2));
        final height = (18 + 26 * math.sin(phase).abs()) * falloff;
        final x = size.width / 2 + side * (46 + i * gap);

        canvas.drawLine(
          Offset(x, middle - height / 2),
          Offset(x, middle + height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}
