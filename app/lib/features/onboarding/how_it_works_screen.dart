import 'dart:async';

import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'onboarding_kit.dart';

/// The second screen. What the app does, as the four things that happen
/// every time, and then what it is not.
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
    'Say what just happened, out loud or typed',
    'One line comes back holding something you said',
    'Look closer if you want, and decide something',
    'Days later the app asks how it went',
  ];

  /// 0 nothing, 1 the core line, 2 to 5 the four steps, 6 the rest.
  int _phase = 0;
  Timer? _timer;

  bool get _complete => _phase >= 6;

  @override
  void initState() {
    super.initState();
    // The frame after first build, so reduce motion can be read.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    if (!mounted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _phase = 6);
      return;
    }
    setState(() => _phase = 1);
    // The core line holds for two seconds before the steps start, because it
    // is the sentence the rest hangs off and it deserves to be read first.
    _timer = Timer(const Duration(seconds: 2), () {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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
    setState(() => _phase = 6);
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
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
            const SizedBox(height: 26),
            _appear(
              _complete,
              const Inset(
                label: 'what this is not',
                body: 'It does not score you, tell you what you feel, or '
                    'replace anyone you would talk to. Nothing you say here '
                    'is graded.',
              ),
            ),
            const Spacer(),
            _appear(
              _complete,
              PrimaryCta('Continue', enabled: _complete, onPressed: widget.onContinue),
            ),
          ],
        ),
      ),
    );
  }
}
