import 'package:flutter/material.dart';
import '../../data/sample.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 7. One day, in order.
///
/// A lens over data that already exists. It adds nothing and interprets
/// nothing. The closing observation is a question, not a finding.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.day, required this.onBack});
  final String day;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_left,
                  size: 22, color: SoulColors.text3),
            ),
            const SizedBox(width: 6),
            Text(day,
                style: const TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 16,
                  color: SoulColors.text,
                )),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(left: 28),
          child: Label('four moments, in order'),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < Sample.day.length; i++)
          _TimelineItem(
            moment: Sample.day[i],
            last: i == Sample.day.length - 1,
          ),
        const SizedBox(height: 8),
        const Inset(
          body: 'The first one is a point you have changed before. Does that '
              'look like where the day turned?',
        ),
        const SizedBox(height: 14),
        ButtonRow(
          children: [
            SoulButton('Yes', kind: SoulButtonKind.filled, onPressed: onBack),
            SoulButton('Not really', onPressed: onBack),
          ],
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.moment, required this.last});
  final Moment moment;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: moment.color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!last)
                const Expanded(
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: SoulColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moment.what, style: SoulType.field),
                  const SizedBox(height: 4),
                  Label(moment.note),
                  if (moment.tag != null) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: SoulColors.clayLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        moment.tag!,
                        style: const TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 11,
                          color: SoulColors.clayDark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
