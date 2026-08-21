import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'baseline.dart';
import 'baseline_answering.dart';

/// A night sky. Four choices sit as stars, and picking one lights it while the
/// rest recede.
///
/// The dark panel is the only dark surface in the product. It is here because
/// this question asks what someone waits for, and waiting reads better against
/// something quiet than against cream.
class Constellation extends StatelessWidget {
  const Constellation({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  /// Fixed positions. Scattered, but never moving between builds, because a
  /// target that moves under the finger is a trick rather than a delight.
  static const _places = [
    Alignment(-0.5, -0.62),
    Alignment(0.55, -0.28),
    Alignment(-0.45, 0.2),
    Alignment(0.4, 0.66),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Square and centred, the same as the orb. Filling the height pulled
        // the four points so far apart that they stopped reading as one sky
        // and started reading as a list that had been knocked over.
        final side = math.min(box.maxWidth, box.maxHeight);

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF241F1B),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          for (var i = 0; i < options.length; i++)
            Align(
              alignment: _places[i],
              child: Enter(
                index: i,
                child: GestureDetector(
                  onTap: () => onChoose(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: chosen == null || chosen == i ? 1 : 0.25,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            width: chosen == i ? 12 : 7,
                            height: chosen == i ? 12 : 7,
                            decoration: BoxDecoration(
                              color: chosen == i
                                  ? baselineColours[i]
                                  : const Color(0xFF8A7F73),
                              shape: BoxShape.circle,
                              boxShadow: chosen == i
                                  ? [
                                      BoxShadow(
                                        color: baselineColours[i],
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            options[i],
                            style: TextStyle(
                              fontFamily: SoulType.serif,
                              fontSize: chosen == i ? 21 : 19,
                              color: chosen == i
                                  ? Colors.white
                                  : const Color(0xFFCFC5B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
            ),
          ),
        );
      },
    );
  }
}

/// A stack of cards, face up, overlapping. Tapping one pulls it to the front.
///
/// For the question about where good decisions come from, because the choices
/// are competing beliefs and a stack shows them competing.
class CardStack extends StatelessWidget {
  const CardStack({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final step = (box.maxHeight - 150) / (options.length - 1);

        return Stack(
          children: [
            for (var i = 0; i < options.length; i++)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: chosen == i ? 0 : 10.0 * (options.length - i - 1),
                right: chosen == i ? 0 : 10.0 * (options.length - i - 1),
                top: chosen == i ? 0 : step * i,
                child: Enter(
                  index: i,
                  child: GestureDetector(
                    onTap: () => onChoose(i),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 220),
                      opacity: chosen == null || chosen == i ? 1 : 0.2,
                      child: Container(
                        height: 132,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: baselineColours[i],
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: SoulColors.shade,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(
                            options[i],
                            style: const TextStyle(
                              fontFamily: SoulType.sans,
                              fontSize: 17,
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Rings spreading from the centre. The further out, the stronger the pull.
///
/// For what strong emotion does, because a ripple is what that actually feels
/// like and a list of four boxes is not.
class Ripples extends StatelessWidget {
  const Ripples({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = options.length - 1; i >= 0; i--)
          Enter(
            index: options.length - i,
            child: GestureDetector(
              onTap: () => onChoose(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(
                  horizontal: 8.0 * i,
                  vertical: 5,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: chosen == i
                      ? baselineColours[i]
                      : baselineColours[i].withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: baselineColours[i]
                        .withValues(alpha: chosen == i ? 1 : 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SoulType.sans,
                      fontSize: 15,
                      fontWeight:
                          chosen == i ? FontWeight.w600 : FontWeight.w400,
                      color: chosen == i ? Colors.white : SoulColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One card at a time, swiped through. Tap the one that fits.
///
/// For what happens after deciding under pressure, because each of those is a
/// small scene and they read better one at a time than four at once.
class SwipeDeck extends StatelessWidget {
  const SwipeDeck({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    // Every option on screen at once.
    //
    // This was a swipe deck, one card at a time. A student who does not swipe
    // never sees options two, three and four, and answers from the one card
    // they were shown. A question whose options are hidden is not a question.
    return Column(
      children: [
        for (var row = 0; row < (options.length + 1) ~/ 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: row * 2 + column < options.length
                        ? _Card(
                            index: row * 2 + column,
                            text: options[row * 2 + column],
                            chosen: chosen == row * 2 + column,
                            dimmed: chosen != null &&
                                chosen != row * 2 + column,
                            onTap: () => onChoose(row * 2 + column),
                          )
                        : const SizedBox(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.index,
    required this.text,
    required this.chosen,
    required this.dimmed,
    required this.onTap,
  });

  final int index;
  final String text;
  final bool chosen;
  final bool dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Enter(
      index: index,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: dimmed ? 0.45 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: chosen ? baselineColours[index] : SoulColors.s1,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: baselineColours[index].withValues(alpha: chosen ? 1 : 0.35),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: SoulColors.shade,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: SoulType.serif,
                  fontSize: 20,
                  height: 1.25,
                  color: chosen ? Colors.white : SoulColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dial you turn. The needle points at what you are ready for.
///
/// For the readiness question, because readiness is a direction rather than an
/// item in a list.
class Dial extends StatefulWidget {
  const Dial({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  State<Dial> createState() => _DialState();
}

class _DialState extends State<Dial> {
  double _angle = -math.pi / 2;
  bool _turned = false;

  int get _pointing {
    final step = math.pi * 2 / widget.options.length;
    final from = _angle + math.pi / 2 + step / 2;
    final wrapped = (from % (math.pi * 2) + math.pi * 2) % (math.pi * 2);
    return (wrapped ~/ step) % widget.options.length;
  }

  void _turn(Offset local, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final v = local - centre;
    setState(() {
      _angle = math.atan2(v.dy, v.dx);
      _turned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, math.min(box.maxHeight, box.maxWidth));
        final radius = size.width / 2 - 20;
        final colour = baselineColours[_pointing];

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: size.width,
              height: size.height,
              child: GestureDetector(
                onPanUpdate: (d) => _turn(d.localPosition, size),
                onTapDown: (d) => _turn(d.localPosition, size),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: radius * 2,
                      height: radius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: SoulColors.s2,
                      ),
                    ),
                    for (var i = 0; i < widget.options.length; i++)
                      Align(
                        alignment: Alignment(
                          math.cos(i * math.pi * 2 / widget.options.length -
                                  math.pi / 2) *
                              0.95,
                          math.sin(i * math.pi * 2 / widget.options.length -
                                  math.pi / 2) *
                              0.95,
                        ),
                        child: SizedBox(
                          width: size.width * 0.42,
                          child: Text(
                            widget.options[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: SoulType.sans,
                              fontSize: 14,
                              fontWeight: _turned && _pointing == i
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: _turned && _pointing == i
                                  ? baselineColours[i]
                                  : SoulColors.text3,
                            ),
                          ),
                        ),
                      ),
                    Transform.rotate(
                      angle: _angle,
                      child: Container(
                        width: radius * 1.1,
                        height: 6,
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: radius * 0.55,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _turned ? colour : SoulColors.border2,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _turned ? colour : SoulColors.border2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedOpacity(
              opacity: _turned ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_turned,
                child: SizedBox(
                  width: 180,
                  child: SoulButton(
                    'That is it',
                    kind: SoulButtonKind.filled,
                    onPressed: () => widget.onChoose(_pointing),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
