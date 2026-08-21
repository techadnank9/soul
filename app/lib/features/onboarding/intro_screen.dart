import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// The first screen a student ever sees.
///
/// It says what the app does and what it does not do, and then gets out of the
/// way. No sign up, no account, no promise about how anyone will feel. The
/// clinical guidance is direct that scope is set at the start rather than
/// discovered later, and the two lines about what this is not are the part
/// that does that work.
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onContinue, this.onSkip});

  final VoidCallback onContinue;

  /// Development only. Jumps the whole of first run and opens home as the
  /// seeded demo student, who has a week of entries behind them, so how home
  /// behaves can be looked at without answering fifteen questions first.
  ///
  /// It is labelled on the screen as what it is. A skip that looks like a
  /// product control is one somebody ships by forgetting it is there.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 26),
      body: [
        const _Mark(),
        const SizedBox(height: 34),
        // The heading asks the question the two paragraphs under it answer,
        // in the same shape they are written in: not that, this. Thirty
        // seconds is gone from here on purpose. It reappears on the capture
        // screen, where it is a fact about what you are about to do rather
        // than a claim on a screen that has not asked for anything yet.
        Text(
          'What reflection\nactually is.',
          style: SoulType.heading.copyWith(height: 1.15),
        ),
        const SizedBox(height: 26),
        // The founder's words, kept as written. They say what reflection is
        // before the app says what it does, which is the right order: a
        // student who does not know what this is for cannot want it.
        Text(
          'Reflection is not thinking harder about something. It is saying it '
          'out loud and hearing what was actually in there.',
          style: SoulType.lead,
        ),
        const SizedBox(height: 16),
        Text(
          'Most of it never gets said. It just sits, shaping what you do next '
          'without you noticing.',
          style: SoulType.lead,
        ),
        const SizedBox(height: 16),
        // One line on the mechanic, after the idea rather than before it.
        Text(
          'So you say it here. One line comes back holding what you said, and '
          'days later the app asks how it went.',
          style: SoulType.lead,
        ),
        const SizedBox(height: 26),
        const Inset(
          label: 'what this is not',
          body: 'It does not score you, tell you what you feel, or replace '
              'anyone you would talk to. Nothing you say here is graded.',
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SoulButton(
            'Continue',
            kind: SoulButtonKind.filled,
            onPressed: onContinue,
          ),
          if (onSkip != null) ...[
            const SizedBox(height: 4),
            SoulButton(
              'Skip to demo home, development only',
              kind: SoulButtonKind.ghost,
              onPressed: onSkip,
            ),
          ],
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
