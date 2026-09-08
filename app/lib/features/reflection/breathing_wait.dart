import 'package:flutter/material.dart';

import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// The wait after somebody sends what they said.
///
/// It used to be a spinner on an empty screen. A spinner says the app is
/// busy, and four to nine seconds of it says the app is stuck. This is the
/// one place in the product where somebody has just finished talking and has
/// nothing to do, which is a moment worth handing back to them rather than a
/// gap to cover over.
///
/// A circle that opens slowly and closes more slowly, at the pace of a
/// breath. Four seconds out, six back, which is one full cycle in the time
/// the model usually takes.
///
/// **It never tells anybody to breathe.** No count, no in and out, no
/// instruction of any kind. The rule that there is no advice in this product
/// holds here too, and a screen that tells a person to breathe is a screen
/// that decided they needed calming. Somebody who wants to follow it can
/// follow it, somebody who wants to watch it can watch it, and both of those
/// are the same screen. The only words on it are the ones that were already
/// there, saying what the app is doing.
///
/// It settles rather than stopping. When the line arrives mid breath the
/// circle is on its way somewhere, and cutting it dead is the one thing that
/// would make the screen feel like a loader again.
class BreathingWait extends StatefulWidget {
  const BreathingWait({super.key, required this.note});

  /// What the app is doing, in its own words. Under the circle, quiet.
  final String note;

  @override
  State<BreathingWait> createState() => _BreathingWaitState();
}

class _BreathingWaitState extends State<BreathingWait>
    with SingleTickerProviderStateMixin {
  /// Ten seconds a cycle: four opening, one held, five closing. A real
  /// breath is longer on the way out than on the way in, and a circle that
  /// moves symmetrically reads as a machine rather than as breathing.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  late final Animation<double> _size = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.52, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 40,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 10),
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.52)
          .chain(CurveTween(curve: Curves.easeInOutSine)),
      weight: 50,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Somebody who has asked their phone to stop moving things has asked
    // this too. They get the circle at rest, and the same words under it.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) _controller.stop();

    return Screen(
      body: [
        const SizedBox(height: 140),
        Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: AnimatedBuilder(
              animation: _size,
              builder: (context, _) {
                final t = still ? 0.76 : _size.value;
                return CustomPaint(
                  painter: _Breath(t),
                  size: const Size.square(220),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 34),
        Center(child: Label(widget.note)),
      ],
    );
  }
}

/// Three rings and a wash, so the edge is soft rather than drawn.
///
/// The outermost ring lags the innermost slightly, which is what stops the
/// whole thing reading as one shape being scaled and makes it read as
/// something expanding.
class _Breath extends CustomPainter {
  const _Breath(this.t);

  /// How open the breath is, from about a half to one.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final full = size.width / 2;

    // The wash under everything. It carries most of the movement, because a
    // soft edge growing is calmer than a line growing.
    canvas.drawCircle(
      centre,
      full * t,
      Paint()
        ..shader = RadialGradient(
          colors: [
            SoulColors.clay.withValues(alpha: 0.16),
            SoulColors.clay.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: full * t)),
    );

    final rings = <({double scale, double width, double alpha})>[
      (scale: 0.62, width: 1.0, alpha: 0.30),
      (scale: 0.82, width: 1.2, alpha: 0.22),
      (scale: 1.0, width: 1.4, alpha: 0.14),
    ];

    for (var i = 0; i < rings.length; i++) {
      final ring = rings[i];
      // Each ring outside the first is a little behind the one inside it, so
      // the shape opens rather than inflates.
      final lag = 1 - (i * 0.06) * (1 - t);
      canvas.drawCircle(
        centre,
        full * t * ring.scale * lag,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.width
          ..color = SoulColors.clay.withValues(alpha: ring.alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_Breath old) => old.t != t;
}
