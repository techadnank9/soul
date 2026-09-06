import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import 'onboarding_kit.dart';

/// The first screen a person ever sees.
///
/// It says what the app is for and then gets out of the way. No sign up, no
/// account, no promise about how anyone will feel. What the app does and
/// what it is not come on the next screen, once the idea has landed: a
/// person who does not know what this is for cannot want it.
///
/// It settles into place in parts rather than snapping on, because the
/// first thing the app does should be to arrive rather than appear.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onContinue, this.onSignIn});

  final VoidCallback onContinue;

  /// For somebody who has been here before, on another phone or after a log
  /// out. Straight to sign in, no questions. Without this the only sign in
  /// in first run is on the last screen, fifteen questions away.
  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Settle(
            child: Row(
              children: [
                const _Mark(),
                const Spacer(),
                if (onSignIn != null)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSignIn,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: Text('Sign in', style: SoulType.secondary),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          // The heading asks the question the lines under it answer, in the
          // same shape they are written in: not that, this. Thirty seconds
          // is not here on purpose. It reappears on the capture screen, where
          // it is a fact about what you are about to do rather than a claim
          // on a screen that has not asked for anything yet.
          Settle(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'A bridge between journaling and therapy.',
              style: SoulType.heading.copyWith(fontSize: 38, height: 1.1),
            ),
          ),
          const SizedBox(height: 22),
          // The founder's words, kept as written. They say what reflection is
          // before the app says what it does, which is the right order.
          Settle(
            delay: const Duration(milliseconds: 220),
            child: Text(
              'Reflection is not thinking harder about something. It is saying '
              'it out loud and hearing what was actually in there.',
              style: const TextStyle(
                fontFamily: SoulType.serif,
                fontSize: 21,
                height: 1.4,
                color: SoulColors.text,
              ),
            ),
          ),
          const Spacer(),
          Settle(
            delay: const Duration(milliseconds: 380),
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                'Most of it never gets said. It just sits, shaping what you do '
                'next without you noticing.',
                style: SoulType.secondary.copyWith(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 26),
          Settle(
            delay: const Duration(milliseconds: 520),
            child: Row(
              children: [
                const Spacer(),
                PrimaryCta(
                  'Begin',
                  arrow: true,
                  expand: false,
                  onPressed: onContinue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The one piece of decoration on the screen. Four marks for the four colours
/// the interface uses, arranged as something settling rather than a logo.
class _Mark extends StatelessWidget {
  const _Mark();

  @override
  Widget build(BuildContext context) {
    const colours = [
      SoulColors.clay,
      SoulColors.amber,
      SoulColors.violet,
      SoulColors.moss,
    ];

    return Row(
      children: [
        for (var i = 0; i < colours.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Container(
            width: i == 0 ? 26 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: colours[i],
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ],
    );
  }
}
