import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
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

/// Two by two colour tiles. The opener, and the loudest of the four.
class TileChoices extends StatelessWidget {
  const TileChoices({
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
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++) ...[
                  if (column > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Enter(
                      index: row * 2 + column,
                      child: _Pressable(
                        onTap: () => onChoose(row * 2 + column),
                        chosen: chosen == row * 2 + column,
                        dimmed: chosen != null && chosen != row * 2 + column,
                        colour: baselineColours[row * 2 + column],
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Text(
                                options[row * 2 + column],
                                style: _onColour,
                              ),
                            ),
                            if (chosen == row * 2 + column)
                              const Align(
                                alignment: Alignment.topRight,
                                child: Icon(Icons.check,
                                    size: 20, color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
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
  });

  final List<String> options;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  State<ScaleChoice> createState() => _ScaleChoiceState();
}

class _ScaleChoiceState extends State<ScaleChoice> {
  late int _at = widget.chosen ?? 0;
  bool _touched = false;

  void _moveTo(double dx, double width) {
    final stop = ((dx / width) * (widget.options.length - 1))
        .round()
        .clamp(0, widget.options.length - 1);
    if (stop == _at && _touched) return;
    setState(() {
      _at = stop;
      _touched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth - 56;
        final position = width * (_at / (widget.options.length - 1));

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Enter(
              index: 0,
              child: Text(
                widget.options[_at],
                style: SoulType.heading.copyWith(
                  fontSize: 26,
                  color: _touched ? baselineColours[_at] : SoulColors.text3,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Enter(
              index: 1,
              child: GestureDetector(
                onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, width),
                onHorizontalDragEnd: (_) => widget.onChoose(_at),
                onTapDown: (d) => _moveTo(d.localPosition.dx, width),
                onTapUp: (_) => widget.onChoose(_at),
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
                      Container(
                        margin: const EdgeInsets.only(left: 28),
                        width: position,
                        height: 8,
                        decoration: BoxDecoration(
                          color: baselineColours[_at],
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
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOut,
                        left: position + 6,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: baselineColours[_at],
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: baselineColours[_at]
                                    .withValues(alpha: 0.45),
                                blurRadius: 16,
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
                  Text(widget.options.first, style: SoulType.muted),
                  Text(widget.options.last, style: SoulType.muted),
                ],
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
