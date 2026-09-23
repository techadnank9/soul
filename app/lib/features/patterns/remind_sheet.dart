import 'package:flutter/material.dart';

import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// The one time this app offers to ring a phone about something the person
/// did not name a time for themselves.
///
/// It is offered once, straight after they confirm a pattern, and never
/// again unasked. They pick the hour. Nothing is watched for in between:
/// the app cannot know when the thing is about to happen and does not
/// pretend to, so what they get is an hour they chose, before an evening
/// rather than in the middle of one.
///
/// Doing nothing is a real answer and it is the one on the left.
/// Decision 295.
Future<DateTime?> askWhenToRemind(BuildContext context) async {
  final now = DateTime.now();

  final choices = <_When>[
    _When('Tomorrow evening, 7:00', _at(now.add(const Duration(days: 1)), 19)),
    _When('Tomorrow morning, 8:30', _at(now.add(const Duration(days: 1)), 8, 30)),
    _When('In three days, 7:00', _at(now.add(const Duration(days: 3)), 19)),
  ];

  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: SoulColors.bg,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Want me to say something next time?',
              style: SoulType.lead,
            ),
            const SizedBox(height: 10),
            Text(
              'You pick when. Nothing is watched in between, and you can turn '
              'it off whenever you like.',
              style: SoulType.secondary,
            ),
            const SizedBox(height: 20),
            for (final choice in choices) ...[
              SoulButton(
                choice.label,
                onPressed: () => Navigator.of(sheet).pop(choice.at),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            SoulButton(
              'Only when I ask',
              kind: SoulButtonKind.ghost,
              onPressed: () => Navigator.of(sheet).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

class _When {
  const _When(this.label, this.at);
  final String label;
  final DateTime at;
}
