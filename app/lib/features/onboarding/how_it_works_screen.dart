import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'onboarding_kit.dart';

/// The second screen. What the app does, as the four things that happen
/// every time, then the one thing that happens across all of them, and then
/// what it is not.
///
/// The four are the loop, in the order they happen. The fifth is the part
/// the product is actually for, and leaving it off made this read like a
/// voice recorder that answers back.
///
/// It reveals itself: the core line, then the four steps one a second, then
/// the button. Two things the timer respects. Tapping anywhere shows the
/// whole screen at once, because a reveal that cannot be hurried reads
/// slower than the reader. And under reduce motion it renders complete
/// immediately, since an unskippable timed reveal is exactly what that
/// setting exists to switch off.
class HowItWorksScreen extends StatefulWidget {
  const HowItWorksScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  State<HowItWorksScreen> createState() => _HowItWorksScreenState();
}

class _HowItWorksScreenState extends State<HowItWorksScreen> {
  static const _steps = [
    'Say what just happened. Speak and the words land as you talk, or type',
    'A line comes back, holding something you actually said',
    'Look closer if you want. It offers one question, and you decide what to do',
    'On the day you chose, it asks how that went',
  ];

  /// 0 nothing, 1 the core line, 2 to 5 the four steps, 6 what they add up
  /// to, 7 the rest.
  int _phase = 0;
  Timer? _timer;

  bool get _complete => _phase >= 7;

  @override
  void initState() {
    super.initState();
    // The frame after first build, so reduce motion can be read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _phase = 7);
      return;
    }
    setState(() => _phase = 1);
    // The core line holds for two seconds before the steps start, because it
    // is the sentence the rest hangs off and it deserves to be read first.
    _timer = Timer(const Duration(seconds: 2), () {
      _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
        if (!mounted || _complete) {
          t.cancel();
          return;
        }
        setState(() => _phase++);
      });
      if (mounted) setState(() => _phase = 2);
    });
  }

  void _revealAll() {
    if (_complete) return;
    _timer?.cancel();
    setState(() => _phase = 7);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _appear(bool shown, Widget child) {
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: shown ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _revealAll,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 34),
        // The list grew when the pattern line was added, so the screen
        // scrolls rather than overflowing on a phone shorter than the one
        // it was drawn on. It still centres itself when there is room,
        // which is every phone this has been opened on so far.
        child: LayoutBuilder(builder: (context, box) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 70),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    _appear(
                      _phase >= 1,
                      Text(
                        'So you say it here, and something comes back.',
                        style: SoulType.heading.copyWith(fontSize: 30, height: 1.15),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _appear(
                      _phase >= 2,
                      Text('Four things, every time.',
                          style: SoulType.secondary.copyWith(fontSize: 14)),
                    ),
                    const SizedBox(height: 18),
                    for (var i = 0; i < _steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 14),
                      _appear(
                        _phase >= i + 2,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: SoulColors.clayLight,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontFamily: SoulType.sans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: SoulColors.clayDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _steps[i],
                                style: const TextStyle(
                                  fontFamily: SoulType.serif,
                                  fontSize: 18,
                                  height: 1.35,
                                  color: SoulColors.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // The part the loop is for. Four moments on their own are a
                    // voice recorder that answers back, and this is the sentence
                    // that says what they add up to.
                    _appear(
                      _phase >= 6,
                      Text('And across all of them.',
                          style: SoulType.secondary.copyWith(fontSize: 14)),
                    ),
                    const SizedBox(height: 10),
                    _appear(
                      _phase >= 6,
                      const Text(
                        'What keeps coming back is offered to you as a pattern. You '
                        'say whether it fits, and the ones that do are sorted into '
                        'what is doing you good and what is costing you.',
                        style: TextStyle(
                          fontFamily: SoulType.serif,
                          fontSize: 18,
                          height: 1.35,
                          color: SoulColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _appear(
                      _complete,
                      const Inset(
                        label: 'what this is not',
                        body: 'It does not score you, tell you what you feel, or '
                            'replace anyone you would talk to. Nothing you say here '
                            'is graded.',
                      ),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _appear(
                _complete,
                PrimaryCta('Continue', enabled: _complete, onPressed: widget.onContinue),
              ),
            ],
          );
        }),
      ),
    );
  }
}
