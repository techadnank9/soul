import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'baseline.dart';

/// The four ways to answer.
///
/// Every one of them does the same three things: arrives with a stagger so the
/// screen assembles rather than appears, responds under the finger, and settles
/// visibly once chosen. None of them praises the student for choosing.

/// Options arrive one after another rather than all at once.
class Enter extends StatelessWidget {
  const Enter({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(child.hashCode + index),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: inner),
      ),
      child: child,
    );
  }
}

/// A field you drag a light across.
///
/// Four choices sit in the corners. The light follows the finger, the nearest
/// choice lights up, and letting go chooses it. Answering becomes a movement
/// toward something rather than a tick in a box, which is the whole reason for
/// building it this way.
class OrbField extends StatefulWidget {
  const OrbField({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  State<OrbField> createState() => _OrbFieldState();
}

class _OrbFieldState extends State<OrbField> {
  Offset _at = const Offset(0.5, 0.5);
  int? _near;
  bool _moved = false;

  static const _corners = [
    Offset(0.16, 0.18),
    Offset(0.84, 0.18),
    Offset(0.16, 0.82),
    Offset(0.84, 0.82),
  ];

  void _move(Offset local, Size size) {
    final at = Offset(
      (local.dx / size.width).clamp(0.08, 0.92),
      (local.dy / size.height).clamp(0.08, 0.92),
    );

    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < _corners.length; i++) {
      final d = (at - _corners[i]).distance;
      if (d < best) {
        best = d;
        nearest = i;
      }
    }

    setState(() {
      _at = at;
      _moved = true;
      // Only counts as leaning somewhere once the light has actually left the
      // middle. Sitting in the centre is not an answer.
      _near = best < 0.34 ? nearest : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Square, and centred in whatever room the question leaves.
        //
        // Filling the space made a tall panel with the four corners stretched
        // to its ends, so leaning up cost a longer drag than leaning across
        // and the light never sat where the finger expected. A square makes
        // the four directions cost the same.
        final side = math.min(box.maxWidth, box.maxHeight);
        final size = Size(side, side);
        final colour =
            _near == null ? SoulColors.border2 : baselineColours[_near!];

        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => _move(d.localPosition, size),
          onPanEnd: (_) {
            if (_near != null) widget.onChoose(_near!);
          },
          onTapDown: (d) => _move(d.localPosition, size),
          onTapUp: (_) {
            if (_near != null) widget.onChoose(_near!);
          },
          child: Container(
            decoration: BoxDecoration(
              color: SoulColors.s2,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Stack(
              children: [
                for (var i = 0; i < widget.options.length; i++)
                  Align(
                    alignment: Alignment(
                      _corners[i].dx * 2 - 1,
                      _corners[i].dy * 2 - 1,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: _near == i ? 16 : 14,
                          fontWeight:
                              _near == i ? FontWeight.w600 : FontWeight.w400,
                          color: _near == i
                              ? baselineColours[i]
                              : SoulColors.text3,
                        ),
                        textAlign: TextAlign.center,
                        child: SizedBox(
                          width: size.width * 0.36,
                          child: Text(
                            widget.options[i],
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: Duration(milliseconds: _moved ? 60 : 300),
                  curve: Curves.easeOut,
                  left: _at.dx * size.width - 34,
                  top: _at.dy * size.height - 34,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color.lerp(colour, Colors.white, 0.55)!,
                          colour,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colour.withValues(alpha: 0.45),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        );
      },
    );
  }
}

/// A stack of rows. For options too long to sit in a tile.
///
/// The colour lives in a bar down the left until a row is chosen, and then it
/// floods the row. That flood is the whole point of this one.
class ListChoices extends StatelessWidget {
  const ListChoices({
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
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Enter(
            index: i,
            child: _Pressable(
              height: 74,
              radius: 20,
              onTap: () => onChoose(i),
              chosen: chosen == i,
              dimmed: chosen != null && chosen != i,
              colour: chosen == i ? baselineColours[i] : SoulColors.s1,
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: chosen == i ? 0 : 6,
                    decoration: BoxDecoration(
                      color: baselineColours[i],
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontFamily: SoulType.sans,
                        fontSize: 16,
                        height: 1.3,
                        fontWeight:
                            chosen == i ? FontWeight.w500 : FontWeight.w400,
                        color: chosen == i ? Colors.white : SoulColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A scale you drag. Only for questions whose options run in an order.
///
/// The thumb follows the finger, the track colours behind it, and the label
/// under it changes as you pass each stop. Choosing is a movement rather than
/// a tap, which is the point of using it here at all.
class ScaleChoice extends StatefulWidget {
  const ScaleChoice({
    super.key,
    required this.options,
    required this.chosen,
    required this.onChoose,
    this.ends,
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  /// Words at either end, when the option names themselves read badly there.
  final (String, String)? ends;

  @override
  State<ScaleChoice> createState() => _ScaleChoiceState();
}

class _ScaleChoiceState extends State<ScaleChoice> {
  /// Where the thumb actually is, from zero to one, following the finger
  /// rather than jumping between stops. The stops are still what gets
  /// answered; they just stop being what the hand feels.
  late double _t =
      (widget.chosen ?? 0) / math.max(1, widget.options.length - 1);
  bool _touched = false;
  bool _dragging = false;

  int get _at => (_t * (widget.options.length - 1))
      .round()
      .clamp(0, widget.options.length - 1);

  void _moveTo(double dx, double width) {
    setState(() {
      _t = (dx / width).clamp(0.0, 1.0);
      _touched = true;
      _dragging = true;
    });
  }

  /// On release the thumb settles onto the nearest stop rather than staying
  /// wherever the finger left it. The drag is continuous, the answer is not.
  void _settle() {
    setState(() {
      _t = _at / math.max(1, widget.options.length - 1);
      _dragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - 56;
        final position = width * _t;

        // The colour crosses between stops rather than switching at them.
        // Snapping the hue at a boundary was most of what made this feel
        // steppy, even after the thumb itself started following the finger.
        final last = widget.options.length - 1;
        final exact = (_t * last).clamp(0.0, last.toDouble());
        final low = exact.floor().clamp(0, last);
        final high = exact.ceil().clamp(0, last);
        final colour = Color.lerp(
          baselineColours[low],
          baselineColours[high],
          exact - low,
        )!;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Enter(
              index: 0,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Text(
                  widget.options[_at],
                  key: ValueKey(_at),
                  style: SoulType.heading.copyWith(
                    fontSize: 26,
                    color: _touched ? colour : SoulColors.text3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Enter(
              index: 1,
              child: GestureDetector(
                // Moving and choosing are separate. Committing on release
                // meant a student could not adjust, and when the release did
                // not register the screen became a dead end with no way on.
                onPanUpdate: (d) => _moveTo(d.localPosition.dx, width),
                onPanEnd: (_) => _settle(),
                onPanCancel: _settle,
                onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) => _settle(),
                onTapDown: (d) => _moveTo(d.localPosition.dx, width),
                onTapUp: (_) => _settle(),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  height: 76,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 28),
                        height: 8,
                        decoration: BoxDecoration(
                          color: SoulColors.s3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: _dragging ? 0 : 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.only(left: 28),
                        width: position,
                        height: 8,
                        decoration: BoxDecoration(
                          color: colour,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      for (var i = 0; i < widget.options.length; i++)
                        Positioned(
                          left: 28 +
                              width * (i / (widget.options.length - 1)) -
                              4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i <= _at
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : SoulColors.border2,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      AnimatedPositioned(
                        duration: Duration(milliseconds: _dragging ? 0 : 260),
                        curve: Curves.easeOutCubic,
                        left: position + 6,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          // Grows under the finger, so the thumb reads as
                          // picked up rather than pushed along.
                          width: _dragging ? 50 : 44,
                          height: _dragging ? 50 : 44,
                          decoration: BoxDecoration(
                            color: colour,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colour.withValues(
                                    alpha: _dragging ? 0.55 : 0.45),
                                blurRadius: _dragging ? 22 : 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Enter(
              index: 2,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.ends?.$1 ?? widget.options.first,
                      style: SoulType.muted),
                  Text(widget.ends?.$2 ?? widget.options.last,
                      style: SoulType.muted),
                ],
              ),
            ),
            const SizedBox(height: 36),
            AnimatedOpacity(
              opacity: _touched ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_touched,
                child: SizedBox(
                  width: 180,
                  child: SoulButton(
                    'That is it',
                    kind: SoulButtonKind.filled,
                    onPressed: () => widget.onChoose(_at),
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

/// Single words, sized by nothing but themselves. Tap one and it takes the
/// screen while the others fall back.
class WordChoices extends StatelessWidget {
  const WordChoices({
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
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 14,
        children: [
          for (var i = 0; i < options.length; i++)
            Enter(
              index: i,
              child: _Pressable(
                radius: 999,
                onTap: () => onChoose(i),
                chosen: chosen == i,
                dimmed: chosen != null && chosen != i,
                colour: baselineColours[i],
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 18,
                ),
                shrink: true,
                child: Text(options[i], style: _onColour.copyWith(fontSize: 20)),
              ),
            ),
        ],
      ),
    );
  }
}

const _onColour = TextStyle(
  fontFamily: SoulType.sans,
  fontSize: 15,
  height: 1.3,
  fontWeight: FontWeight.w500,
  color: Colors.white,
);

/// Anything that can be chosen. Presses in under the finger, settles a little
/// larger once chosen, and the unchosen fall back so the choice is what is
/// left on screen.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.child,
    required this.onTap,
    required this.chosen,
    required this.dimmed,
    required this.colour,
    this.height,
    this.radius = 24,
    this.padding = const EdgeInsets.all(16),
    this.shrink = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final bool chosen;
  final bool dimmed;
  final Color colour;
  final double? height;
  final double radius;
  final EdgeInsets padding;
  final bool shrink;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : (widget.chosen ? 1.03 : 1),
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: widget.dimmed ? 0.3 : 1,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: widget.shrink ? null : double.infinity,
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.colour,
              borderRadius: BorderRadius.circular(widget.radius),
              border: widget.colour == SoulColors.s1
                  ? Border.all(color: SoulColors.border)
                  : null,
              boxShadow: widget.chosen
                  ? [
                      BoxShadow(
                        color: widget.colour.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: SoulColors.shade,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}


/// A sentence with a hole in it.
///
/// The words that could fill it are scattered rather than stacked, and the
/// chosen one drops into the blank. Reading the finished sentence back is the
/// answer, which is closer to how someone would actually say it.
class BlankSentence extends StatelessWidget {
  const BlankSentence({
    super.key,
    required this.lead,
    required this.options,
    required this.chosen,
    required this.onChoose,
  });

  final String lead;
  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  /// Scattered, but the same scatter every time. Random placement would move
  /// the words under the finger between builds.
  static const _offsets = [
    Offset(-0.34, 0),
    Offset(0.30, 0),
    Offset(-0.26, 0),
    Offset(0.34, 0),
  ];

  @override
  Widget build(BuildContext context) {
    final filled = chosen == null
        ? lead
        : lead.replaceAll(RegExp('_+'), options[chosen!]);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Enter(
          index: 0,
          child: Text(
            filled,
            textAlign: TextAlign.center,
            style: SoulType.heading.copyWith(
              fontSize: 24,
              color: chosen == null ? SoulColors.text3 : SoulColors.text,
            ),
          ),
        ),
        const SizedBox(height: 40),
        for (var i = 0; i < options.length; i++)
          Enter(
            index: i + 1,
            child: Align(
              alignment: Alignment(_offsets[i % _offsets.length].dx, 0),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: GestureDetector(
                  onTap: () => onChoose(i),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: chosen == null || chosen == i ? 1 : 0.3,
                    child: Text(
                      options[i],
                      style: TextStyle(
                        fontFamily: SoulType.serif,
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: chosen == i
                            ? baselineColours[i]
                            : SoulColors.text2,
                      ),
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
