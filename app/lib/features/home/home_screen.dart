import 'package:flutter/material.dart';
import '../../data/sample.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 4. Home.
///
/// Two versions, and the empty one comes first. Every mockup shows a full week
/// of data and no student has that on day one, so a brand new account has to
/// look intentional rather than broken.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.momentsThisWeek,
    required this.onCapture,
    required this.onOpenDay,
    required this.onOpenPatterns,
    required this.onOutcome,
    this.heldDecision,
    this.showFooter = true,
  });

  final int momentsThisWeek;
  final String? heldDecision;
  final VoidCallback onCapture;
  final ValueChanged<String> onOpenDay;
  final VoidCallback onOpenPatterns;
  final VoidCallback onOutcome;

  /// The tab shell carries its own capture button, so home hides its footer
  /// when it is inside one and keeps it when it stands alone.
  final bool showFooter;

  bool get _empty => momentsThisWeek == 0;

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: _empty ? _dayOne() : _populated(),
      footer: showFooter
          ? SoulButton(
              'Something on your mind',
              kind: SoulButtonKind.filled,
              height: 56,
              onPressed: onCapture,
            )
          : null,
    );
  }

  /// Day one. No week circle, no patterns, one invitation.
  List<Widget> _dayOne() => const [
        SizedBox(height: 40),
        Text('Nothing here yet', style: SoulType.heading),
        SizedBox(height: 14),
        Text(
          'This fills in as you go. One moment is enough to start.',
          style: SoulType.secondary,
        ),
      ];

  List<Widget> _populated() => [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('This week', style: SoulType.heading),
              Label('$momentsThisWeek moments'),
            ],
          ),
        ),
        // Four tiles, one per theme, sized to the screen rather than to a
        // legend. The colour is the content here, not a key to a chart.
        Row(
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: _ThemeTile(theme: Sample.themes[i])),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 2; i < 4; i++) ...[
              if (i > 2) const SizedBox(width: 12),
              Expanded(child: _ThemeTile(theme: Sample.themes[i])),
            ],
          ],
        ),
        const SizedBox(height: 14),
        SoulCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('tap a day'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < 7; i++)
                    _DayDot(
                      letter: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                      color: Sample.week[i],
                      today: i == 6,
                      onTap: () => onOpenDay(const [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                        'Saturday',
                        'Sunday'
                      ][i]),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (heldDecision != null) ...[
          const SizedBox(height: 14),
          SoulCard(
            background: SoulColors.clayLight,
            borderColor: const Color(0x33EA5F17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Label('you were holding this'),
                const SizedBox(height: 6),
                Text(
                  heldDecision!,
                  style: const TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 18,
                    height: 1.35,
                    color: SoulColors.text,
                  ),
                ),
                const SizedBox(height: 14),
                ButtonRow(
                  children: [
                    SoulButton('I did', onPressed: onOutcome),
                    SoulButton('Not yet', onPressed: onOutcome),
                    SoulButton('Changed', onPressed: onOutcome),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        SoulCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: onOpenPatterns,
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What keeps returning',
                        style: TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                          color: SoulColors.text,
                        )),
                    SizedBox(height: 3),
                    Label('3 patterns, one still forming'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: SoulColors.text3),
            ],
          ),
        ),
      ];
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.color,
    required this.today,
    required this.onTap,
  });

  final String letter;
  final Color? color;
  final bool today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(letter, style: SoulType.muted),
          const SizedBox(height: 8),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: (color ?? SoulColors.s3).withValues(
                alpha: color == null ? 1 : 0.22,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: today
                    ? SoulColors.text3
                    : (color ?? Colors.transparent).withValues(alpha: 0.55),
                width: today ? 1 : 1.5,
              ),
            ),
            child: color == null
                ? null
                : Center(
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// One theme, as a filled tile. Large enough that the colour is the surface
/// rather than a mark beside a word.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.theme});
  final ThemeSlice theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${theme.count}',
            style: const TextStyle(
              fontFamily: SoulType.serif,
              fontSize: 34,
              height: 1,
              color: Colors.white,
            ),
          ),
          Text(
            theme.name,
            style: const TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
