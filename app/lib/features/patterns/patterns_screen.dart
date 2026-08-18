import 'package:flutter/material.dart';
import '../../data/sample.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 10. What keeps returning.
///
/// Everything listed here was confirmed by the student. The one below the rule
/// is a candidate that has not met the threshold, and it says so rather than
/// pretending to be a finding.
class PatternsScreen extends StatelessWidget {
  const PatternsScreen({super.key, required this.reflectionCount});
  final int reflectionCount;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const Text('What keeps returning',
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: SoulColors.text,
            )),
        const SizedBox(height: 6),
        Label('from $reflectionCount reflections since June'),
        const SizedBox(height: 24),
        for (final pattern in Sample.patterns) ...[
          _PatternRow(pattern: pattern),
          const SizedBox(height: 22),
        ],
        const Rule(),
        const SizedBox(height: 18),
        const Text(
          'Something around your brother',
          style: TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: SoulColors.text2,
          ),
        ),
        const SizedBox(height: 3),
        const Label('seen twice, not enough to say yet'),
        const SizedBox(height: 14),
        SoulButton('Take a look', onPressed: () {}),
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({required this.pattern});
  final Pattern pattern;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          pattern.name,
          style: const TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 15,
            fontWeight: FontWeight.w300,
            color: SoulColors.text,
          ),
        ),
        const SizedBox(height: 3),
        Label(pattern.detail),
        const SizedBox(height: 10),
        // One mark per week. The filled ones are the entries behind the claim,
        // and every one of them can be opened and read.
        Row(
          children: [
            for (var week = 0; week < 12; week++) ...[
              if (week > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: pattern.marks.contains(week)
                        ? pattern.color
                        : SoulColors.s3,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
