import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../data/sample.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 4. Home.
///
/// Two versions, and the empty one comes first. Every mockup shows a full week
/// of data and no student has that on day one, so a brand new account has to
/// look intentional rather than broken.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.momentsThisWeek,
    required this.onCapture,
    required this.onOpenDay,
    required this.onOpenPatterns,
    required this.onOutcome,
    this.heldDecision,
  });

  final int momentsThisWeek;
  final String? heldDecision;
  final VoidCallback onCapture;
  final ValueChanged<String> onOpenDay;
  final VoidCallback onOpenPatterns;
  final VoidCallback onOutcome;

  bool get _empty => momentsThisWeek == 0;

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: _empty ? _dayOne() : _populated(),
      footer: SoulButton(
        'Something on your mind',
        kind: SoulButtonKind.filled,
        height: 50,
        onPressed: onCapture,
      ),
    );
  }

  /// Day one. No week circle, no patterns, one invitation.
  List<Widget> _dayOne() => const [
        SizedBox(height: 40),
        Text('Nothing here yet', style: SoulType.heading),
        SizedBox(height: 14),
        Text(
          'This fills in as you go. One moment is enough to start.',
          style: SoulType.secondary,
        ),
      ];

  List<Widget> _populated() => [
        SoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('This week',
                      style: TextStyle(
                        fontFamily: SoulType.sans,
                        fontSize: 16,
                        color: SoulColors.text,
                      )),
                  Label('$momentsThisWeek moments'),
                ],
              ),
              const SizedBox(height: 10),
              const Center(child: _ThemeRing(size: 126)),
              const SizedBox(height: 14),
              for (final theme in Sample.themes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(theme.name, style: SoulType.secondary),
                      ),
                      Text('${theme.count}', style: SoulType.muted),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoulCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('tap a day'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _DayDot(
                      letter: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                      color: Sample.week[i],
                      today: i == 6,
                      onTap: () => onOpenDay(const [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday'
                      ][i]),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (heldDecision != null) ...[
          const SizedBox(height: 14),
          SoulCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Label('you were holding this'),
                const SizedBox(height: 6),
                Text(
                  heldDecision!,
                  style: const TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 18,
                    height: 1.35,
                    color: SoulColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                ButtonRow(
                  children: [
                    SoulButton('I did', onPressed: onOutcome),
                    SoulButton('Not yet', onPressed: onOutcome),
                    SoulButton('Changed', onPressed: onOutcome),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SoulCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: onOpenPatterns,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What keeps returning',
                        style: TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: SoulColors.text,
                        )),
                    SizedBox(height: 3),
                    Label('3 patterns, one still forming'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: SoulColors.text3),
            ],
          ),
        ),
      ];
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.color,
    required this.today,
    required this.onTap,
  });

  final String letter;
  final Color? color;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(letter, style: SoulType.muted),
          const SizedBox(height: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color ?? SoulColors.s3,
              shape: BoxShape.circle,
              border: today
                  ? Border.all(color: SoulColors.text3, width: 1)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The week as one ring. Counts only, no judgement, no score.
class _ThemeRing extends StatelessWidget {
  const _ThemeRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _RingPainter(Sample.themes)),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.slices);
  final List<ThemeSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.count);
    if (total == 0) return;

    final stroke = size.width * 0.104;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = SoulColors.s3;
    canvas.drawCircle(rect.center, rect.width / 2, track);

    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.count / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = slice.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.slices != slices;
}
