import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../data/device_location.dart';
import '../../data/device_weather.dart';
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
    this.onOpenProfile,
  });

  final SoulApi api;

  /// The first name the user gave at first run, if they gave one. Used
  /// once, on the empty screen, where the alternative is a room with nobody
  /// in it. Never used to praise them and never used twice in a row.
  final String? name;

  /// The profile, which left the tab bar and is reached from here.
  final VoidCallback? onOpenProfile;

  /// Opens capture. A prompt and a note put a question at the top of it,
  /// which is how the weather card asks something specific.
  final void Function({String? prompt, String? note}) onCapture;

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

  /// Asked for on its own rather than as part of the week, so a slow or
  /// unreachable weather service costs this card and nothing else on the
  /// screen. Null is the ordinary answer when no position was ever shared.
  DeviceWeather? _weather;

  /// The place the phone named for their position, for the line on the card.
  String? _place;

  @override
  void initState() {
    super.initState();
    _load();
    _sky();
  }

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) {
      _load();
      // Asked for again whenever the week is, so a first attempt that
      // found nothing is not the last word for the life of the app. It
      // failed once against a service that was still deploying and the
      // card stayed missing until the app was closed and opened.
      if (_weather == null) _sky();
    }
  }

  /// Where to look comes from the service, and the weather itself from
  /// Apple on this device, so the position never leaves the phone.
  ///
  /// Null anywhere along the way means no card, which is an ordinary answer
  /// and is not shown as a failure. A card answered today is not shown
  /// again until tomorrow, and tapping one is not answering it.
  Future<void> _sky() async {
    final where = await widget.api.weatherWhere();
    if (where == null || where.answeredToday) return;

    var sky = await weatherAt(
      latitude: where.latitude,
      longitude: where.longitude,
      fahrenheit: where.fahrenheit,
    );

    // Apple declines on a simulator, which is where most of this is looked
    // at. In a debug build the service reads it instead so the card is
    // there to look at. A release build never asks.
    if (sky == null && kDebugMode) {
      final reading = await widget.api.weatherReading();
      final condition = reading?['condition'] as String?;
      final celsius = (reading?['celsius'] as num?)?.toDouble();
      if (condition != null && celsius != null) {
        sky = readingToWeather(
          condition: condition,
          celsius: celsius,
          daylight: reading?['daylight'] as bool? ?? true,
          fahrenheit: where.fahrenheit,
        );
      }
    }
    if (!mounted || sky == null) return;

    final place = await placeName(where.latitude, where.longitude);
    if (!mounted) return;
    setState(() {
      _weather = sky;
      _place = place?.split(',').first.trim();
    });
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
              onPressed: () => widget.onCapture(),
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
      // The same header every tab has: the tab's name in serif, one muted
      // line under it. The card holds the ring and nothing else.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(widget.name), style: SoulType.heading),
                const SizedBox(height: 6),
                Label(_today()),
              ],
            ),
          ),
          if (widget.onOpenProfile != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onOpenProfile,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: SoulColors.s1,
                  shape: BoxShape.circle,
                  border: Border.all(color: SoulColors.border),
                ),
                child: const Icon(Icons.person_outline, size: 20, color: SoulColors.text2),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      // The week across the top, the way a calendar reads, so which day it
      // is and which days were written on are both answered before the
      // first card. It used to sit halfway down as a card of its own.
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final day in week.days)
            _DayColumn(
              date: day.date,
              written: day.count > 0,
              today: day.date == today,
              onTap: () => widget.onOpenDay(day.date),
            ),
        ],
      ),
      // What the sky is doing, and one question that follows from it. It is
      // the shortest way into the app: tapping it opens capture with the
      // question already at the top.
      if (_weather != null) ...[
        const SizedBox(height: 16),
        SoulCard(
          background: SoulColors.clayLight,
          borderColor: const Color(0x33EA5F17),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          onTap: () => widget.onCapture(
            prompt: _weather!.question,
            note: _weather!.lineIn(_place),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Label(_weather!.lineIn(_place)),
                    const SizedBox(height: 6),
                    Text(
                      _weather!.question,
                      style: const TextStyle(
                        fontFamily: SoulType.serif,
                        fontSize: 18,
                        height: 1.35,
                        color: SoulColors.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Apple asks for this wherever their weather is shown.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => launchWeatherAttribution(),
                      child: Text(
                        'Weather',
                        style: SoulType.muted.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: SoulColors.clay,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none, size: 18, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
      SoulCard(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Label(_momentLine(week.moments)),
            const SizedBox(height: 10),
            Center(
              child: SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(painter: _WeekRing(slices)),
              ),
            ),
            // A week can hold entries with nothing to divide by: the tagger
            // has not run on them yet, or it ran and found no feeling in
            // them, which is the honest answer for a few words typed to see
            // what happens. Rather than a blank circle, the card holds what
            // the baseline said, which is the one thing the app does know
            // about somebody who has only just arrived. Their own week
            // replaces it as soon as it has something in it.
            if (slices.isEmpty) ...[
              const SizedBox(height: 16),
              if (week.opening != null) ...[
                Text(
                  week.opening!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 17,
                    height: 1.4,
                    color: SoulColors.text,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Center(child: Label('nothing to divide yet')),
            ],
            if (slices.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (var i = 0; i < slices.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    for (var j = i; j < i + 2 && j < slices.length; j++)
                      Expanded(
                        child: _LegendRow(
                          slice: slices[j],
                          // These have no entries behind them yet, so there
                          // is no number to give.
                          counted: !week.themesFromAnswers,
                        ),
                      ),
                  ],
                ),
              ],
              if (week.themesFromAnswers) ...[
                const SizedBox(height: 12),
                const Center(child: Label('from what you answered')),
              ],
            ],
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

  /// Morning until noon, afternoon until five, evening after that and
  /// through the night, because nobody wants to be told good night by the
  /// thing they opened at two in the morning.
  static String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final part = hour >= 5 && hour < 12
        ? 'Good morning'
        : hour >= 12 && hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    return name == null ? part : '$part, $name';
  }

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// Written out rather than in numbers, and without a package to do it.
  static String _today() {
    final now = DateTime.now();
    return '${_weekdays[now.weekday - 1]} ${now.day} ${_months[now.month - 1]}';
  }

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

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.written,
    required this.today,
    required this.onTap,
  });

  /// The day, as the server gave it, so tapping opens the same day the
  /// server would answer for.
  final String date;

  /// Whether anything was written that day. How much is not shown, and
  /// neither is what it held: a mark that guessed a feeling would be the app
  /// making one up.
  final bool written;

  final bool today;
  final VoidCallback onTap;

  static const _letters = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final day = DateTime.parse(date);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: today ? SoulColors.s1 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: today ? SoulColors.border2 : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_letters[day.weekday - 1], style: SoulType.muted),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: TextStyle(
                fontFamily: SoulType.sans,
                fontSize: 15,
                fontWeight: today ? FontWeight.w600 : FontWeight.w400,
                color: today ? SoulColors.text : SoulColors.text2,
              ),
            ),
            const SizedBox(height: 5),
            // Held open whether or not there is a mark, so the row does not
            // shift as the week fills.
            SizedBox(
              height: 5,
              child: written
                  ? Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: SoulColors.clay,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
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
  const _LegendRow({required this.slice, this.counted = true});

  final ({String name, int count, Color colour}) slice;

  /// Whether the number means anything. A theme drawn from the baseline
  /// answers has no entries behind it, so it carries a weight rather than a
  /// count and the weight is nobody's business.
  final bool counted;

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
        if (counted) ...[
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
        ],
        const SizedBox(width: 14),
      ],
    );
  }
}
