import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../day/day_screen.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import '../outcome/outcome_screen.dart';

/// Screen 4. Home.
///
/// Two versions, and the empty one comes first. Every mockup shows a full week
/// of data and no user has that on day one, so a brand new account has to
/// look intentional rather than broken.
///
/// The week comes from the server, boundaries and all. Nothing here decides
/// which day an entry belongs to.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.onCapture,
    required this.onOpenDay,
    required this.onOpenPatterns,
    this.revision = 0,
    this.showFooter = true,
    this.name,
  });

  final SoulApi api;

  /// The first name the user gave at first run, if they gave one. Used
  /// once, on the empty screen, where the alternative is a room with nobody
  /// in it. Never used to praise them and never used twice in a row.
  final String? name;

  final VoidCallback onCapture;

  /// Given the date of the day that was tapped, as YYYY-MM-DD.
  final ValueChanged<String> onOpenDay;

  final VoidCallback onOpenPatterns;

  /// Changes when an entry lands. The count and the dots then come from the
  /// server again rather than being added up on the device, so what is on
  /// screen is what is stored.
  final int revision;

  /// The tab shell carries its own capture button, so home hides its footer
  /// when it is inside one and keeps it when it stands alone.
  final bool showFooter;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeekView? _week;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _week = null;
      _failed = false;
    });
    try {
      final week = await widget.api.week();
      if (mounted) setState(() => _week = week);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final week = _week;

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: _failed
          ? _notLoaded()
          : week == null
              ? _waiting()
              // Day one, and every later week with nothing in it yet.
              : week.moments == 0
                  ? _dayOne()
                  : _populated(week),
      // The invitation is the one thing worth offering while the week is still
      // coming, and it is the only way out of a week that would not load.
      footer: widget.showFooter
          ? SoulButton(
              'Something on your mind',
              kind: SoulButtonKind.filled,
              height: 56,
              onPressed: widget.onCapture,
            )
          : null,
    );
  }

  List<Widget> _waiting() => const [
        SizedBox(height: 120),
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SoulColors.clay,
            ),
          ),
        ),
      ];

  List<Widget> _notLoaded() => [
        const SizedBox(height: 40),
        const Text('Not loaded', style: SoulType.heading),
        const SizedBox(height: 14),
        const Text(
          'The app could not reach your week just now. Everything you wrote is '
          'still there.',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 22),
        // Without this a dropped connection at launch leaves home with nothing
        // on it until the app is quit and reopened.
        SoulButton('Try again', onPressed: _load),
      ];

  /// Day one. No week circle, no patterns, one invitation.
  List<Widget> _dayOne() => [
        const SizedBox(height: 40),
        Text(
          widget.name == null
              ? 'Nothing here yet'
              : 'Nothing here yet, ${widget.name}',
          style: SoulType.heading,
        ),
        const SizedBox(height: 14),
        const Text(
          'This fills in as you go. One moment is enough to start.',
          style: SoulType.secondary,
        ),
      ];

  /// Opens the check back, and records what they say.
  ///
  /// This is the only place in the product where an outcome is written, and
  /// without it the two sections built on outcomes could never fill: the job
  /// marks a decision due and nothing ever asked about it.
  Future<void> _askHowItWent(Holding holding) async {
    final answer = await Navigator.of(context).push<({String? happened, String? felt})>(
      MaterialPageRoute(
        builder: (page) => OutcomeScreen(
          decision: holding.chose,
          onDone: (happened, felt) =>
              Navigator.of(page).pop((happened: happened, felt: felt)),
        ),
      ),
    );

    if (answer == null || !mounted) return;

    try {
      await widget.api.recordOutcome(
        decisionId: holding.decisionId,
        whatHappened: answer.happened,
        felt: answer.felt,
      );
    } catch (_) {
      // Nothing said here. The card stays where it is and the question can be
      // answered again, which is better than telling a user their answer
      // went somewhere it did not.
    }

    if (mounted) await _load();
  }

  List<Widget> _populated(WeekView week) {
    final slices = _slices(week.themes);
    final today = todayOnDevice();

    return [
      // The ring, as the original design had it.
      //
      // Four tiles replaced it for a while and they were louder but flatter:
      // four numbers side by side say how much of each, and the ring says
      // how the week divided. The proportion is the point, so it is drawn as
      // one shape rather than four.
      SoulCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'This week',
                  style: TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 26,
                    color: SoulColors.text,
                  ),
                ),
                Label(_momentLine(week.moments)),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(painter: _WeekRing(slices)),
              ),
            ),
            // The tagger runs after a reflection is already on screen, so a
            // week can hold entries that have not been named yet. The ring
            // stays as its empty track and no key is drawn under it, rather
            // than the card losing its shape for a day.
            if (slices.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (var i = 0; i < slices.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var j = i; j < i + 2 && j < slices.length; j++)
                      Expanded(child: _LegendRow(slice: slices[j])),
                  ],
                ),
              ],
            ],
          ],
        ),
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
                for (final day in week.days)
                  _DayDot(
                    letter: day.weekday,
                    written: day.count > 0,
                    today: day.date == today,
                    onTap: () => widget.onOpenDay(day.date),
                  ),
              ],
            ),
          ],
        ),
      ),
      // The thing they are holding, once the day they named has passed. It
      // sits above what keeps returning because it is the only card on this
      // screen that is waiting on them.
      if (week.holding != null) ...[
        const SizedBox(height: 14),
        SoulCard(
          background: SoulColors.clayLight,
          borderColor: const Color(0x33EA5F17),
          onTap: () => _askHowItWent(week.holding!),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('you were holding this'),
              const SizedBox(height: 6),
              Text(
                week.holding!.chose,
                style: const TextStyle(
                  fontFamily: SoulType.serif,
                  fontSize: 18,
                  height: 1.35,
                  color: SoulColors.text,
                ),
              ),
              const SizedBox(height: 12),
              // Neutral. It asks what happened rather than whether they did
              // it, because a check back that reads as a test turns this into
              // something that keeps score.
              Row(
                children: [
                  const Expanded(
                    child: Text('How did it go?', style: SoulType.secondary),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: SoulColors.text3),
                ],
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 14),
      SoulCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        onTap: widget.onOpenPatterns,
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'What keeps returning',
                style: TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                  color: SoulColors.text,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: SoulColors.text3),
          ],
        ),
      ),
      const SizedBox(height: 60),
    ];
  }

  static String _momentLine(int moments) =>
      moments == 1 ? 'one moment' : '$moments moments';

  /// The themes, each given one of the four colours.
  ///
  /// By position, because the week arrives highest first and four distinct
  /// colours in a fixed order is what makes the ring readable. Nothing in the
  /// contract ties a feeling to a colour, and a colour chosen here only ever
  /// says which arc is which line of the key.
  static List<({String name, int count, Color colour})> _slices(
    List<WeekTheme> themes,
  ) {
    const palette = [
      SoulColors.clay,
      SoulColors.amber,
      SoulColors.violet,
      SoulColors.moss,
    ];

    return [
      for (var i = 0; i < themes.length && i < palette.length; i++)
        (name: themes[i].name, count: themes[i].count, colour: palette[i]),
    ];
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.letter,
    required this.written,
    required this.today,
    required this.onTap,
  });

  final String letter;

  /// Whether anything was written that day. How much is not shown: the week
  /// says nothing about which feeling a day held, and a dot that guessed one
  /// would be the app making it up.
  final bool written;

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
              color: written
                  ? SoulColors.clay.withValues(alpha: 0.22)
                  : SoulColors.s3,
              shape: BoxShape.circle,
              border: Border.all(
                color: today
                    ? SoulColors.text3
                    : (written
                        ? SoulColors.clay.withValues(alpha: 0.55)
                        : Colors.transparent),
                width: today ? 1 : 1.5,
              ),
            ),
            child: written
                ? const Center(
                    child: SizedBox(
                      width: 7,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: SoulColors.clay,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// The week as one ring, divided by theme.
///
/// Arc lengths are the share of the week each theme took, so a glance answers
/// what most of it was about before any number is read. Drawn with a rounded
/// cap and a gap between arcs, because touching arcs read as one smeared band.
class _WeekRing extends CustomPainter {
  const _WeekRing(this.slices);

  final List<({String name, int count, Color colour})> slices;

  static const _stroke = 15.0;

  /// A hair of space between arcs, in radians.
  static const _gap = 0.045;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _stroke) / 2;
    final box = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..color = SoulColors.s3;
    canvas.drawCircle(centre, radius, track);

    final total = slices.fold<int>(0, (sum, slice) => sum + slice.count);
    if (total == 0) return;

    // From the top, clockwise, in the order the themes are given.
    var start = -math.pi / 2;

    for (final slice in slices) {
      final sweep = (slice.count / total) * math.pi * 2;
      if (sweep <= _gap) continue;

      canvas.drawArc(
        box,
        start + _gap / 2,
        sweep - _gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _stroke
          ..strokeCap = StrokeCap.round
          ..color = slice.colour,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_WeekRing old) => !listEquals(old.slices, slices);
}

/// One line of the key under the ring. The dot carries the colour, the name
/// says what it is, the number is last because it is the least of the three.
class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.slice});

  final ({String name, int count, Color colour}) slice;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.colour,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            slice.name,
            style: SoulType.secondary.copyWith(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${slice.count}',
          style: const TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: SoulColors.text,
          ),
        ),
        const SizedBox(width: 14),
      ],
    );
  }
}
