import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 1. The first thing a student reads.
///
/// CONTEXT.md is direct about this one: how a young person perceives what stays
/// private determines what they are willing to say. The wording here is the
/// product, not a formality.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: const [
        Text('Before we start', style: SoulType.heading),
        SizedBox(height: 24),
        Text(
          'This is a place to think out loud. It reflects back what you say. '
          'It does not diagnose, treat, or give advice.',
          style: SoulType.lead,
        ),
        SizedBox(height: 18),
        Rule(),
        SizedBox(height: 18),
        Text(
          'What you write stays yours. You can delete any of it, any time.',
          style: SoulType.secondary,
        ),
        SizedBox(height: 18),
        Text(
          'Nothing is shared with anyone unless you choose to share it.',
          style: SoulType.secondary,
        ),
        SizedBox(height: 18),
        Text(
          'If something serious comes up, we point you to real people who can '
          'help.',
          style: SoulType.secondary,
        ),
      ],
      footer: Column(
        children: [
          SoulButton('I understand',
              kind: SoulButtonKind.filled, onPressed: onContinue),
          const SizedBox(height: 9),
          SoulButton('Read the full terms', onPressed: () {}),
        ],
      ),
    );
  }
}
