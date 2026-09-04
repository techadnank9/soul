import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/soul_theme.dart';

/// The ten ways the baseline set is answered. One scene per question, no
/// repeats, each one a movement rather than a tick: a light dragged to a
/// corner, an answer sunk in a pond, a wall pushed over, a sun raised.
///
/// The mechanics are Nouvel's first onboarding, the one it replaced with
/// rows in August 2026, rebuilt here for Soul's questions and drawn in
/// Soul's colours. Every scene does the same three things: responds under
/// the finger, settles visibly once chosen, and reports the option index.
/// None of them praises the person for choosing, and none of them says
/// what an answer means.
///
/// A scene is handed the answer already given, if there is one, so coming
/// back to a question shows it settled rather than blank.

/// What every scene takes.
abstract class Scene extends StatefulWidget {
  const Scene({
    super.key,
    required this.options,
    required this.answer,
    required this.onSelect,
  });

  final List<String> options;
  final int? answer;
  final ValueChanged<int> onSelect;
}

/// The one line under a scene that says what to do, or what was chosen.
class SceneHint extends StatelessWidget {
  const SceneHint(this.text, {super.key, this.chosen = false});
  final String text;
  final bool chosen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            text,
            key: ValueKey(text),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SoulType.serif,
              fontSize: 18,
              height: 1.2,
              color: chosen ? SoulColors.clayDark : SoulColors.text3,
            ),
          ),
        ),
      ),
    );
  }
}

bool _still(BuildContext context) => MediaQuery.disableAnimationsOf(context);

// ---------------------------------------------------------------------------
// 1. The field. A light dragged toward one of four corners.
// ---------------------------------------------------------------------------

class FieldScene extends Scene {
  const FieldScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<FieldScene> createState() => _FieldSceneState();
}

class _FieldSceneState extends State<FieldScene> {
  static const _corners = [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)];

  Offset _orb = Offset.zero;
  bool _dragging = false;
  int _nearest = -1;
  int? _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
  }

  String get _hint {
    if (_committed != null) return widget.options[_committed!];
    if (_dragging && _nearest >= 0) return widget.options[_nearest];
    return 'Drag the light toward what feels true';
  }

  int _nearestTo(Offset unit) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < _corners.length; i++) {
      final d = (_corners[i] - unit).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void _commit(int i, Offset target) {
    HapticFeedback.mediumImpact();
    setState(() {
      _committed = i;
      _dragging = false;
      _orb = target;
    });
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: LayoutBuilder(builder: (context, box) {
            const inset = 62.0;
            final cx = box.maxWidth / 2;
            final cy = box.maxHeight / 2;
            final maxX = cx - inset;
            final maxY = cy - inset;
            if (_committed != null && _orb == Offset.zero && !_dragging) {
              _orb = Offset(_corners[_committed!].dx * maxX, _corners[_committed!].dy * maxY);
            }
            final reach = math.min(1.0, _orb.distance / Offset(maxX, maxY).distance);

            void update(Offset local) {
              if (_committed != null) return;
              final dx = (local.dx - cx).clamp(-maxX, maxX);
              final dy = (local.dy - cy).clamp(-maxY, maxY);
              final next = _nearestTo(Offset(dx / maxX, dy / maxY));
              if (next != _nearest) HapticFeedback.selectionClick();
              setState(() {
                _dragging = true;
                _orb = Offset(dx, dy);
                _nearest = next;
              });
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => update(d.localPosition),
              onPanUpdate: (d) => update(d.localPosition),
              onPanEnd: (_) {
                if (_committed != null || !_dragging) return;
                final i = _nearest;
                _commit(i, Offset(_corners[i].dx * maxX, _corners[i].dy * maxY));
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: SoulColors.s2,
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: cx + _corners[i].dx * maxX - 56,
                      top: cy + _corners[i].dy * maxY - 24,
                      width: 112,
                      height: 48,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_committed != null) return;
                          _nearest = i;
                          _commit(i, Offset(_corners[i].dx * maxX, _corners[i].dy * maxY));
                        },
                        child: Center(
                          child: AnimatedScale(
                            scale: (_committed == i || (_committed == null && _dragging && _nearest == i)) ? 1.08 : 1,
                            duration: const Duration(milliseconds: 150),
                            child: Text(
                              widget.options[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: SoulType.sans,
                                fontSize: 12,
                                height: 1.25,
                                fontWeight: FontWeight.w500,
                                color: (_committed == i || (_committed == null && _dragging && _nearest == i))
                                    ? SoulColors.text
                                    : SoulColors.text3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: _dragging ? Duration.zero : const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    left: cx + _orb.dx - 30,
                    top: cy + _orb.dy - 30,
                    child: IgnorePointer(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [Color(0xFFFFC49A), SoulColors.clay],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: SoulColors.clay.withValues(alpha: 0.3 + reach * 0.35),
                              blurRadius: 12 + reach * 22,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        transform: Matrix4.diagonal3Values(1.0 + reach * 0.35, 1.0 + reach * 0.35, 1),
                        transformAlignment: Alignment.center,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SceneHint(_hint, chosen: _committed != null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. The pond. Four answers drift on dark water. Tap one to sink it.
// ---------------------------------------------------------------------------

class PondScene extends Scene {
  const PondScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<PondScene> createState() => _PondSceneState();
}

class _PondSceneState extends State<PondScene> with SingleTickerProviderStateMixin {
  static const _spots = [Offset(0.27, 0.2), Offset(0.72, 0.32), Offset(0.3, 0.68), Offset(0.72, 0.82)];

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();

  final List<_Ripple> _ripples = [];
  int? _committed;
  DateTime _lastRipple = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _ripple(Offset at) {
    final r = _Ripple(at);
    setState(() => _ripples.add(r));
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _ripples.remove(r));
    });
  }

  void _commit(int i, Offset at) {
    HapticFeedback.lightImpact();
    _ripple(at);
    setState(() => _committed = i);
    Future<void>.delayed(const Duration(milliseconds: 850), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (d) {
                if (_committed != null) return;
                final now = DateTime.now();
                if (now.difference(_lastRipple).inMilliseconds < 140) return;
                _lastRipple = now;
                _ripple(d.localPosition);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2A1D18), Color(0xFF3B2A22)],
                        ),
                      ),
                    ),
                    for (final r in _ripples) _RippleRing(key: ValueKey(r), at: r.at),
                    AnimatedBuilder(
                      animation: _drift,
                      builder: (context, _) {
                        final t = still ? 0.0 : _drift.value * 2 * math.pi;
                        return Stack(
                          children: [
                            for (var i = 0; i < 4; i++)
                              Positioned(
                                left: _spots[i].dx * size.width - 65 + math.sin(t * 1.9 + i) * 6,
                                top: _spots[i].dy * size.height - 24 + math.cos(t * 1.6 + i * 1.4) * 5,
                                width: 130,
                                height: 48,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (_committed != null) return;
                                    _commit(i, Offset(_spots[i].dx * size.width, _spots[i].dy * size.height));
                                  },
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 600),
                                    opacity: _committed == i ? 0 : (_committed != null ? 0.25 : 0.92),
                                    child: AnimatedScale(
                                      duration: const Duration(milliseconds: 600),
                                      scale: _committed == i ? 0.6 : 1,
                                      child: Center(
                                        child: Text(
                                          widget.options[i],
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: SoulType.serif,
                                            fontSize: 17,
                                            height: 1.2,
                                            color: Color(0xFFFAEFE4),
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
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SceneHint(
          _committed == null ? 'Tap the one that is true, and let it sink' : widget.options[_committed!],
          chosen: _committed != null,
        ),
      ],
    );
  }
}

class _Ripple {
  _Ripple(this.at);
  final Offset at;
}

class _RippleRing extends StatelessWidget {
  const _RippleRing({super.key, required this.at});
  final Offset at;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1300),
      curve: Curves.easeOut,
      builder: (context, p, _) {
        final d = 20 + p * 100;
        return Positioned(
          left: at.dx - d / 2,
          top: at.dy - d / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: 1 - p,
              child: Container(
                width: d,
                height: d,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SoulColors.violet.withValues(alpha: 0.6), width: 1.5),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 3. The stones. Four low walls across a path. Push one over.
// ---------------------------------------------------------------------------

class StonesScene extends Scene {
  const StonesScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<StonesScene> createState() => _StonesSceneState();
}

class _StonesSceneState extends State<StonesScene> {
  int? _dragging;
  double _dragX = 0;
  int? _toppled;
  bool _toppleRight = true;

  @override
  void initState() {
    super.initState();
    _toppled = widget.answer;
  }

  void _topple(int i, {required bool right}) {
    HapticFeedback.heavyImpact();
    setState(() {
      _toppled = i;
      _toppleRight = right;
      _dragging = null;
    });
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 270,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: _wall(i)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
        SceneHint(
          _toppled == null ? 'Push a wall aside' : widget.options[_toppled!],
          chosen: _toppled != null,
        ),
      ],
    );
  }

  Widget _wall(int i) {
    final dragging = _dragging == i;
    final toppled = _toppled == i;
    final live = dragging ? _dragX : 0.0;
    final turns = toppled ? (_toppleRight ? 0.22 : -0.22) : live / 5 / 360;
    final slide = toppled ? (_toppleRight ? 4.0 : -4.0) : live / 60;
    final quick = dragging && !toppled;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_toppled != null) return;
            _topple(i, right: true);
          },
          onHorizontalDragStart: (_) {
            if (_toppled != null) return;
            setState(() {
              _dragging = i;
              _dragX = 0;
            });
          },
          onHorizontalDragUpdate: (d) {
            if (_toppled != null || _dragging != i) return;
            setState(() => _dragX += d.delta.dx);
          },
          onHorizontalDragEnd: (d) {
            if (_toppled != null || _dragging != i) return;
            final fling = d.primaryVelocity ?? 0;
            if (_dragX.abs() > 40 || fling.abs() > 300) {
              _topple(i, right: _dragX > 0 || (_dragX == 0 && fling > 0));
            } else {
              setState(() {
                _dragging = null;
                _dragX = 0;
              });
            }
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 450),
            opacity: toppled ? 0 : (_toppled != null ? 0.35 : 1),
            child: AnimatedSlide(
              duration: quick ? Duration.zero : const Duration(milliseconds: 500),
              curve: Curves.easeIn,
              offset: Offset(slide, 0),
              child: AnimatedRotation(
                duration: quick ? Duration.zero : const Duration(milliseconds: 500),
                curve: Curves.easeIn,
                turns: turns,
                alignment: Alignment.bottomCenter,
                // Narrow and tall, three times as high as wide, the way the
                // first flow drew them: a wall, not a card.
                child: Container(
                  width: 54,
                  height: 180,
                  decoration: BoxDecoration(
                    color: SoulColors.s1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: SoulColors.border2),
                    boxShadow: const [
                      BoxShadow(color: SoulColors.shade, blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(height: 1, color: SoulColors.border),
                      const Spacer(),
                      Container(height: 1, color: SoulColors.border),
                      const Spacer(),
                      Container(
                        height: 6,
                        decoration: const BoxDecoration(
                          color: SoulColors.border2,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 46,
          child: Text(
            widget.options[i],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 10,
              height: 1.25,
              letterSpacing: -0.2,
              fontWeight: FontWeight.w500,
              color: toppled ? SoulColors.text : SoulColors.text2,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 4. The beam. A ball on a seesaw, four stops along it.
// ---------------------------------------------------------------------------

class BeamScene extends Scene {
  const BeamScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<BeamScene> createState() => _BeamSceneState();
}

class _BeamSceneState extends State<BeamScene> {
  double _p = 0.5;
  bool _dragging = false;
  int? _committed;
  int _lastLive = -1;

  int get _live => (_p * 3).round().clamp(0, 3);

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) _p = _committed! / 3;
  }

  void _snap() {
    final i = _live;
    HapticFeedback.mediumImpact();
    setState(() {
      _p = i / 3;
      _committed = i;
      _dragging = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shown = _committed ?? (_dragging ? _live : null);
    return Column(
      children: [
        SceneHint(
          shown == null ? 'Roll the ball to where it is true' : widget.options[shown],
          chosen: _committed != null,
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: SizedBox(
            height: 90,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              void update(double x) {
                if (_committed != null) return;
                final next = ((x / w).clamp(0.0, 1.0) * 3).round();
                if (next != _lastLive) {
                  HapticFeedback.selectionClick();
                  _lastLive = next;
                }
                setState(() {
                  _dragging = true;
                  _p = (x / w).clamp(0.0, 1.0);
                });
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => update(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
                onHorizontalDragEnd: (_) {
                  if (_committed == null && _dragging) _snap();
                },
                onTapUp: (d) {
                  if (_committed != null) return;
                  _p = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  _dragging = true;
                  _snap();
                },
                child: Column(
                  children: [
                    SizedBox(
                      height: 44,
                      child: AnimatedRotation(
                        duration: _dragging ? Duration.zero : const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        turns: (_p - 0.5) * 2 * 15 / 360,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: SoulColors.border2,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            for (var i = 0; i < 4; i++)
                              Positioned(
                                left: w * i / 3 - 3,
                                top: 19,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: SoulColors.border2,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            AnimatedPositioned(
                              duration: _dragging ? Duration.zero : const Duration(milliseconds: 350),
                              curve: Curves.easeOutBack,
                              left: (w * _p - 14).clamp(0.0, w - 28),
                              top: 8,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: SoulColors.clay,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: SoulColors.clay.withValues(alpha: 0.35),
                                      blurRadius: _dragging ? 10 : 5,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    CustomPaint(
                      size: const Size(20, 14),
                      painter: _TrianglePainter(SoulColors.text2),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Text(
                  widget.options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SoulType.sans,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: shown == i ? SoulColors.text : SoulColors.text3,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.colour);
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = colour);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.colour != colour;
}

// ---------------------------------------------------------------------------
// 5. The weight. An orb on a vertical track. Heavier dims the room.
// ---------------------------------------------------------------------------

class WeightScene extends Scene {
  const WeightScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<WeightScene> createState() => _WeightSceneState();
}

class _WeightSceneState extends State<WeightScene> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  double _p = 0.5;
  bool _dragging = false;
  int? _committed;
  int _lastLive = -1;

  int get _live => (_p * 3).round().clamp(0, 3);

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) _p = _committed! / 3;
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _snap() {
    final i = _live;
    if (_p < 0.5) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _p = i / 3;
      _committed = i;
      _dragging = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final still = _still(context);

    // Morning at the top, the app's own dusk at the very bottom.
    //
    // The room used to darken evenly, which put the third of four options in
    // the middle of the fade: a grey the palette does not own, under text
    // that was halfway to cream and readable on neither. It stays warm and
    // light now until the last stretch, then falls away quickly, so every
    // resting place is a colour this app would have chosen.
    final sink = _p < 0.5 ? 0.0 : math.pow((_p - 0.5) * 2, 2.6).toDouble();
    final room = Color.lerp(
      Color.lerp(const Color(0xFFFFF9F0), SoulColors.s3, math.min(_p * 2, 1))!,
      const Color(0xFF2A1F1A),
      sink,
    )!;

    // Ink is chosen against the room rather than against the position, so it
    // is always one of two readable colours and never the average of them.
    // The change happens in time, through the animations below, not through
    // a grey in between.
    final dusk = room.computeLuminance() < 0.2;
    final ink = dusk ? const Color(0xFFF6EBDD) : SoulColors.text;
    final inkSoft = dusk ? const Color(0xFFB9A898) : SoulColors.text3;
    final shown = _committed ?? (_dragging ? _live : null);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 340,
          decoration: BoxDecoration(
            color: room,
            borderRadius: BorderRadius.circular(26),
          ),
          child: LayoutBuilder(builder: (context, box) {
            const top = 54.0;
            final bottom = box.maxHeight - 54;
            final trackX = 84.0;

            void update(double y) {
              if (_committed != null) return;
              final p = ((y - top) / (bottom - top)).clamp(0.0, 1.0);
              final next = (p * 3).round();
              if (next != _lastLive) {
                HapticFeedback.selectionClick();
                _lastLive = next;
              }
              setState(() {
                _dragging = true;
                _p = p;
              });
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (d) => update(d.localPosition.dy),
              onVerticalDragUpdate: (d) => update(d.localPosition.dy),
              onVerticalDragEnd: (_) {
                if (_committed == null && _dragging) _snap();
              },
              onTapUp: (d) {
                if (_committed != null) return;
                _p = ((d.localPosition.dy - top) / (bottom - top)).clamp(0.0, 1.0);
                _dragging = true;
                _snap();
              },
              child: AnimatedBuilder(
                animation: _bob,
                builder: (context, _) {
                  final amp = still || _dragging ? 0.0 : 8 - _p * 4;
                  final bob = math.sin(_bob.value * 2 * math.pi * (1.4 - _p * 0.5)) * amp;
                  final y = top + (bottom - top) * _p + bob;
                  return Stack(
                    children: [
                      Positioned(
                        left: trackX,
                        top: top,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: 1,
                          height: bottom - top,
                          color: inkSoft.withValues(alpha: 0.5),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 4,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 1,
                          color: inkSoft.withValues(alpha: 0.5),
                        ),
                      ),
                      Positioned(
                        left: trackX - 40,
                        top: top - 40,
                        width: 80,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(fontFamily: SoulType.sans, fontSize: 12, color: inkSoft),
                          textAlign: TextAlign.center,
                          child: const Text('light'),
                        ),
                      ),
                      Positioned(
                        left: trackX - 40,
                        top: bottom + 26,
                        width: 80,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(fontFamily: SoulType.sans, fontSize: 12, color: inkSoft),
                          textAlign: TextAlign.center,
                          child: const Text('heavy'),
                        ),
                      ),
                      for (var i = 0; i < 4; i++)
                        Positioned(
                          left: trackX + 46,
                          right: 20,
                          top: top + (bottom - top) * i / 3 - 16,
                          height: 32,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: TextStyle(
                                fontFamily: SoulType.sans,
                                fontSize: shown == i ? 14 : 12,
                                height: 1.2,
                                fontWeight: shown == i ? FontWeight.w600 : FontWeight.w400,
                                color: shown == i ? ink : inkSoft,
                              ),
                              child: Text(widget.options[i]),
                            ),
                          ),
                        ),
                      AnimatedPositioned(
                        duration: _dragging ? Duration.zero : const Duration(milliseconds: 420),
                        curve: _p < 0.5 ? Curves.easeOutBack : Curves.bounceOut,
                        left: trackX - 24,
                        top: y - 24,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.3, -0.4),
                              colors: [const Color(0xFFFFC49A), Color.lerp(SoulColors.clay, SoulColors.clayDark, _p)!],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: SoulColors.clay.withValues(alpha: 0.25 + (1 - _p) * 0.3),
                                blurRadius: 10 + (1 - _p) * 18,
                                offset: Offset(0, 4 + _p * 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        SceneHint(
          shown == null ? 'Drag the orb to where it sits' : widget.options[shown],
          chosen: _committed != null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 6. The cards. A deck of four. Swipe left to pass, right to choose.
// ---------------------------------------------------------------------------

class DeckScene extends Scene {
  const DeckScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<DeckScene> createState() => _DeckSceneState();
}

class _DeckSceneState extends State<DeckScene> {
  /// Card order, top first. Passing moves the top card to the back.
  late List<int> _order = List.generate(widget.options.length, (i) => i);
  Offset _drag = Offset.zero;
  bool _dragging = false;
  int? _committed;
  int? _flying;
  bool _flyRight = true;

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) {
      _order = [_committed!, ...List.generate(widget.options.length, (i) => i).where((i) => i != _committed)];
    }
  }

  void _choose(int i) {
    HapticFeedback.mediumImpact();
    setState(() {
      _committed = i;
      _dragging = false;
      _drag = Offset.zero;
    });
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) widget.onSelect(i);
    });
  }

  void _pass(int i) {
    HapticFeedback.selectionClick();
    setState(() {
      _flying = i;
      _flyRight = false;
      _dragging = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() {
        _order = [..._order.where((o) => o != i), i];
        _flying = null;
        _drag = Offset.zero;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            return Stack(
              alignment: Alignment.center,
              children: [
                for (var depth = _order.length - 1; depth >= 0; depth--) _card(_order[depth], depth, w),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        SceneHint(
          _committed == null ? 'Swipe right if it is you, left if it is not' : widget.options[_committed!],
          chosen: _committed != null,
        ),
      ],
    );
  }

  Widget _card(int i, int depth, double w) {
    final top = depth == 0;
    final chosen = _committed == i;
    final flying = _flying == i;
    final live = top && _dragging ? _drag : Offset.zero;
    final x = flying ? (_flyRight ? w * 1.4 : -w * 1.4) : live.dx;
    final angle = flying ? (_flyRight ? 0.35 : -0.35) : live.dx / 400;
    final quick = top && _dragging && !flying;

    return AnimatedPositioned(
      duration: quick ? Duration.zero : const Duration(milliseconds: 320),
      curve: Curves.easeOut,
      left: 16 + x,
      right: 16 - x,
      top: 12 + depth * 10.0,
      bottom: 12 - depth * 10.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 320),
        scale: 1 - depth * 0.04,
        child: AnimatedRotation(
          duration: quick ? Duration.zero : const Duration(milliseconds: 320),
          turns: angle / (2 * math.pi),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 320),
            opacity: (_committed != null && !chosen) ? 0.25 : (depth > 2 ? 0 : 1),
            child: GestureDetector(
              onTap: top && _committed == null ? () => _choose(i) : null,
              onPanStart: top && _committed == null ? (_) => setState(() => _dragging = true) : null,
              onPanUpdate: top && _committed == null
                  ? (d) => setState(() => _drag += Offset(d.delta.dx, 0))
                  : null,
              onPanEnd: top && _committed == null
                  ? (_) {
                      if (_drag.dx > 90) {
                        _flyRight = true;
                        _choose(i);
                      } else if (_drag.dx < -90) {
                        _pass(i);
                      } else {
                        setState(() {
                          _dragging = false;
                          _drag = Offset.zero;
                        });
                      }
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: chosen ? SoulColors.clay : SoulColors.s1,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: chosen ? SoulColors.clay : SoulColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: chosen ? SoulColors.clay.withValues(alpha: 0.35) : SoulColors.shade,
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: SoulType.serif,
                      fontSize: 24,
                      height: 1.25,
                      color: chosen ? Colors.white : SoulColors.text,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. The sunrise. Drag the sun up and the sky warms. For the one scale.
// ---------------------------------------------------------------------------

class SunriseScene extends Scene {
  const SunriseScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
    this.ends,
  });

  /// The words at the bottom and the top of the sky.
  final (String, String)? ends;

  @override
  State<SunriseScene> createState() => _SunriseSceneState();
}

class _SunriseSceneState extends State<SunriseScene> {
  /// 1 is full dawn, which is the first option: the options run from most
  /// to least, so up is more.
  double _p = 0;
  bool _dragging = false;
  int? _committed;

  int get _count => widget.options.length;
  int get _live => ((1 - _p) * (_count - 1)).round().clamp(0, _count - 1);

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) _p = 1 - _committed! / (_count - 1);
  }

  void _commit(int i) {
    HapticFeedback.mediumImpact();
    setState(() {
      _committed = i;
      _p = 1 - i / (_count - 1);
      _dragging = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sky = Color.lerp(const Color(0xFF2B2230), const Color(0xFFFFE2B8), _p)!;
    final shown = _committed ?? (_dragging ? _live : null);
    return Column(
      children: [
        Row(
          children: [
            if (widget.ends != null)
              SizedBox(
                width: 64,
                height: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(widget.ends!.$2, textAlign: TextAlign.right, style: SoulType.muted.copyWith(fontSize: 11)),
                    Text(widget.ends!.$1, textAlign: TextAlign.right, style: SoulType.muted.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            if (widget.ends != null) const SizedBox(width: 12),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 150,
                decoration: BoxDecoration(color: sky, borderRadius: BorderRadius.circular(22)),
                child: LayoutBuilder(builder: (context, box) {
                  final h = box.maxHeight;
                  void update(double y) {
                    if (_committed != null) return;
                    setState(() {
                      _dragging = true;
                      _p = (1 - y / h).clamp(0.0, 1.0);
                    });
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: (d) => update(d.localPosition.dy),
                    onVerticalDragUpdate: (d) => update(d.localPosition.dy),
                    onVerticalDragEnd: (_) {
                      if (_committed == null && _dragging) _commit(_live);
                    },
                    onTapUp: (d) {
                      if (_committed != null) return;
                      _p = (1 - d.localPosition.dy / h).clamp(0.0, 1.0);
                      _commit(_live);
                    },
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: _dragging ? Duration.zero : const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          left: box.maxWidth / 2 - 22,
                          top: 8 + (h - 60) * (1 - _p),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color.lerp(const Color(0xFFF3D9CB), SoulColors.amber, _p),
                              boxShadow: [
                                BoxShadow(
                                  color: SoulColors.amber.withValues(alpha: 0.2 + _p * 0.5),
                                  blurRadius: 10 + _p * 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _count; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (_committed != null) return;
              _commit(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: shown == i ? SoulColors.clay : SoulColors.s1,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: shown == i ? SoulColors.clay : SoulColors.border),
              ),
              child: Text(
                widget.options[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: shown == i ? Colors.white : SoulColors.text,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 8. The sentence. Endings drift near a blank. Drag one on, or tap it.
// ---------------------------------------------------------------------------

class SentenceScene extends Scene {
  const SentenceScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
    required this.lead,
  });

  /// The sentence with an underscore run where the ending goes.
  final String lead;

  @override
  State<SentenceScene> createState() => _SentenceSceneState();
}

class _SentenceSceneState extends State<SentenceScene> {
  static const _spots = [Offset(0.24, 0.16), Offset(0.76, 0.24), Offset(0.26, 0.6), Offset(0.74, 0.7)];

  int? _dragging;
  Offset _drag = Offset.zero;
  int? _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
  }

  void _commit(int i) {
    HapticFeedback.mediumImpact();
    setState(() {
      _dragging = null;
      _drag = Offset.zero;
      _committed = i;
    });
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) widget.onSelect(i);
    });
  }

  /// The ending, made to sit inside the sentence. A leading I is dropped
  /// when the sentence already says it, and is never lower cased when it
  /// stays, because i is not a word.
  String _ending(int i) {
    var o = widget.options[i];
    final before = _before.trimRight();
    if (o.startsWith('I ') && (before.endsWith(' I') || before == 'I')) {
      o = o.substring(2);
    }
    if (o.isEmpty || o.startsWith('I ') || o == 'I') return o;
    return o[0].toLowerCase() + o.substring(1);
  }

  String get _before {
    final match = RegExp(r'_+').firstMatch(widget.lead);
    return match == null ? widget.lead : widget.lead.substring(0, match.start);
  }

  @override
  Widget build(BuildContext context) {
    final blank = RegExp(r'_+');
    final match = blank.firstMatch(widget.lead);
    final before = match == null ? widget.lead : widget.lead.substring(0, match.start);
    final after = match == null ? '' : widget.lead.substring(match.end);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: const TextStyle(fontFamily: SoulType.serif, fontSize: 20, height: 1.35, color: SoulColors.text2),
            textAlign: TextAlign.center,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: before),
                TextSpan(
                  text: _committed == null ? '__________' : _ending(_committed!),
                  style: TextStyle(color: _committed == null ? SoulColors.text3 : SoulColors.clayDark),
                ),
                TextSpan(text: after),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 230,
          child: LayoutBuilder(builder: (context, box) {
            final size = Size(box.maxWidth, box.maxHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: _spots[i].dx * size.width - 75 + (_dragging == i ? _drag.dx : 0),
                    top: _spots[i].dy * size.height - 24 + (_dragging == i ? _drag.dy : 0),
                    width: 150,
                    height: 48,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_committed != null) return;
                        _commit(i);
                      },
                      onPanStart: (_) {
                        if (_committed != null) return;
                        setState(() {
                          _dragging = i;
                          _drag = Offset.zero;
                        });
                      },
                      onPanUpdate: (d) {
                        if (_committed != null || _dragging != i) return;
                        setState(() => _drag += d.delta);
                      },
                      onPanEnd: (_) {
                        if (_committed != null || _dragging != i) return;
                        if (_drag.dy < -60) {
                          _commit(i);
                        } else {
                          setState(() {
                            _dragging = null;
                            _drag = Offset.zero;
                          });
                        }
                      },
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: _committed == i ? 0 : (_committed != null ? 0.2 : 1),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 400),
                          scale: _committed == i ? 0.4 : (_dragging == i ? 1.08 : 1),
                          child: Center(
                            child: Text(
                              _ending(i),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: SoulType.serif,
                                fontSize: 17,
                                height: 1.2,
                                color: SoulColors.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
        SceneHint(
          _committed == null ? 'Tap an ending, or lift it into the blank' : 'That is the sentence',
          chosen: _committed != null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 9. The warmth. An ember slid along a line, glowing as it goes.
// ---------------------------------------------------------------------------

class WarmthScene extends Scene {
  const WarmthScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
  });

  @override
  State<WarmthScene> createState() => _WarmthSceneState();
}

class _WarmthSceneState extends State<WarmthScene> {
  double _p = 0.5;
  bool _dragging = false;
  int? _committed;
  int _lastLive = -1;

  int get _live => (_p * 3).round().clamp(0, 3);

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) _p = _committed! / 3;
  }

  void _snap() {
    final i = _live;
    HapticFeedback.mediumImpact();
    setState(() {
      _p = i / 3;
      _committed = i;
      _dragging = false;
    });
    Future<void>.delayed(const Duration(milliseconds: 550), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ember = Color.lerp(SoulColors.text3, SoulColors.clay, _p)!;
    final shown = _committed ?? (_dragging ? _live : null);
    return Column(
      children: [
        SceneHint(
          shown == null ? 'Slide the ember to where it is warm' : widget.options[shown],
          chosen: _committed != null,
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 48,
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              void update(double x) {
                if (_committed != null) return;
                final p = (x / w).clamp(0.0, 1.0);
                final next = (p * 3).round();
                if (next != _lastLive) {
                  HapticFeedback.selectionClick();
                  _lastLive = next;
                }
                setState(() {
                  _dragging = true;
                  _p = p;
                });
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (d) => update(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
                onHorizontalDragEnd: (_) {
                  if (_committed == null && _dragging) _snap();
                },
                onTapUp: (d) {
                  if (_committed != null) return;
                  _p = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  _dragging = true;
                  _snap();
                },
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [SoulColors.border2, SoulColors.clay.withValues(alpha: 0.7)],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    for (var i = 0; i < 4; i++)
                      Positioned(
                        left: (w * i / 3 - 4).clamp(0.0, w - 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: SoulColors.s1, shape: BoxShape.circle),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: _dragging ? Duration.zero : const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      left: (w * _p - 22).clamp(-4.0, w - 40),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: _dragging ? 1.12 : 1,
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [ember.withValues(alpha: 0.45), Colors.transparent]),
                          ),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ember,
                              boxShadow: [BoxShadow(color: ember.withValues(alpha: 0.4 * _p), blurRadius: 14)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Text(
                  widget.options[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: SoulType.sans,
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: shown == i ? SoulColors.text : SoulColors.text3,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 10. The bloom. Four seeds. Tap one and it grows and opens.
// ---------------------------------------------------------------------------

class BloomScene extends Scene {
  const BloomScene({
    super.key,
    required super.options,
    required super.answer,
    required super.onSelect,
    required this.colours,
  });

  final List<Color> colours;

  @override
  State<BloomScene> createState() => _BloomSceneState();
}

class _BloomSceneState extends State<BloomScene> {
  int? _committed;
  bool _grown = false;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _committed = widget.answer;
    if (_committed != null) {
      _grown = true;
      _open = true;
    }
  }

  void _commit(int i) {
    HapticFeedback.lightImpact();
    setState(() => _committed = i);
    Future<void>.delayed(const Duration(milliseconds: 40), () {
      if (mounted) setState(() => _grown = true);
    });
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _open = true);
    });
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) widget.onSelect(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 4; i++) Expanded(child: _seed(i)),
            ],
          ),
        ),
        SceneHint(
          _committed == null ? 'Tap the seed that is yours' : widget.options[_committed!],
          chosen: _committed != null,
        ),
      ],
    );
  }

  Widget _seed(int i) {
    final chosen = _committed == i;
    final colour = widget.colours[i % widget.colours.length];
    final stem = chosen && _grown ? 120.0 : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_committed != null) return;
        _commit(i);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _committed != null && !chosen ? 0.3 : 1,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(
              height: 190,
              child: Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    width: 4,
                    height: stem,
                    decoration: BoxDecoration(color: SoulColors.moss, borderRadius: BorderRadius.circular(2)),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    bottom: stem - 4,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutBack,
                      scale: chosen && _open ? 1 : (chosen ? 0.7 : 0.45),
                      child: chosen && _open
                          ? _Flower(colour: colour)
                          : Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colour,
                                boxShadow: [BoxShadow(color: colour.withValues(alpha: 0.35), blurRadius: 10)],
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: SoulColors.border2),
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: Text(
                widget.options[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                  color: chosen ? SoulColors.text : SoulColors.text2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Flower extends StatelessWidget {
  const _Flower({required this.colour});
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 6; i++)
            Transform.rotate(
              angle: i * math.pi / 3,
              child: Transform.translate(
                offset: const Offset(0, -18),
                child: Container(
                  width: 22,
                  height: 34,
                  decoration: BoxDecoration(
                    color: colour,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(color: SoulColors.amber, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
