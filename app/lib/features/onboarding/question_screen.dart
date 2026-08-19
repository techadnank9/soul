import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 2. One question, a baseline, and a skip that costs nothing.
///
/// Autonomy is the reason the skip is there. A student who is here because an
/// adult sent them needs a way through that is not answering.
class QuestionScreen extends StatelessWidget {
  const QuestionScreen({
    super.key,
    required this.onAnswered,
    required this.onSkip,
  });

  final VoidCallback onAnswered;

  /// Skip leaves first run entirely and lands on home. A skip that moves you
  /// to the next question is not a skip, it is a slower question.
  final VoidCallback onSkip;

  static const _answers = [
    'Strongly agree',
    'Somewhat agree',
    'Not sure',
    'Disagree',
  ];

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const _Progress(step: 0, of: 3),
        const SizedBox(height: 32),
        const Text(
          'Certain situations tend to trigger the same reaction in me.',
          style: TextStyle(
            fontFamily: SoulType.serif,
            fontSize: 21,
            height: 1.35,
            color: SoulColors.text,
          ),
        ),
        const SizedBox(height: 32),
        for (final answer in _answers) ...[
          SoulButton(answer, alignLeft: true, onPressed: onAnswered),
          const SizedBox(height: 9),
        ],
      ],
      footer: SoulButton('Skip',
          kind: SoulButtonKind.ghost, onPressed: onSkip),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.of});
  final int step;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(
            width: 22,
            height: 3,
            decoration: BoxDecoration(
              color: i == step ? SoulColors.clay : SoulColors.s3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }
}
