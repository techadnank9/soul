import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 9. A pattern candidate, asked as a question inside a later reflection.
///
/// A pattern is never asserted. It is proposed, and it is stored only when the
/// user confirms it. Rejections are stored too, so the same wrong guess is
/// never offered twice.
class PatternPromptScreen extends StatelessWidget {
  const PatternPromptScreen({
    super.key,
    required this.when,
    required this.entry,
    required this.proposal,
    required this.onFits,
    required this.onNotTheSame,
    required this.onLater,
  });

  final String when;
  final String entry;
  final String proposal;
  final VoidCallback onFits;
  final VoidCallback onNotTheSame;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        Label(when),
        const SizedBox(height: 18),
        Quote(entry),
        const SizedBox(height: 24),
        SoulCard(
          background: SoulColors.clayLight,
          borderColor: const Color(0x33EA5F17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proposal,
                style: SoulType.lead.copyWith(color: SoulColors.clayDark),
              ),
              const SizedBox(height: 18),
              ButtonRow(
                children: [
                  SoulButton('It fits',
                      kind: SoulButtonKind.filled, onPressed: onFits),
                  SoulButton('Not the same', onPressed: onNotTheSame),
                ],
              ),
            ],
          ),
        ),
      ],
      footer: SoulButton('Ask me later',
          kind: SoulButtonKind.ghost, onPressed: onLater),
    );
  }
}
