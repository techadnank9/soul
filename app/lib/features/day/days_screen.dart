import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'day_screen.dart';

/// The days tab. Every day with something in it, newest first.
///
/// It opened straight into one day before this, which meant the tab had no
/// answer to the question a user actually arrives with, which is what have
/// I been saying lately.
///
/// A day opens its own page rather than unfolding in the row. The day carries
/// entries in full and the cards that ask what happens next, and that is more
/// than a row can hold without the list stopping being a list.
///
/// Days with nothing in them are absent. An unbroken calendar with empty rows
/// reads as a record of what somebody failed to do, and nothing here keeps
/// score.
class DaysScreen extends StatefulWidget {
  const DaysScreen({
    super.key,
    required this.api,
    this.revision = 0,
    this.openOn,
    this.onCapture,
  });

  final SoulApi api;

  /// Changes when an entry lands, because a new entry can start a new day.
  final int revision;

  /// A day the user picked somewhere else, on the week strip on home. It
  /// opens straight away rather than waiting to be found in the list.
  final String? openOn;

  /// Adds something to today, from a day that is today.
  final VoidCallback? onCapture;

  @override
  State<DaysScreen> createState() => _DaysScreenState();
}

class _DaysScreenState extends State<DaysScreen> {
  List<DayCount>? _days;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
    final wanted = widget.openOn;
    if (wanted != null) {
      // After the first frame, because opening a page from initState pushes a
      // route before this one has finished being built.
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(wanted));
    }
  }

  @override
  void didUpdateWidget(covariant DaysScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) _load();
    if (widget.openOn != null && widget.openOn != old.openOn) {
      _open(widget.openOn!);
    }
  }

  Future<void> _load() async {
    setState(() {
      _days = null;
      _failed = false;
    });
    try {
      final days = await widget.api.days();
      if (mounted) setState(() => _days = days);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Opens the day on its own page. The list stays where it was, so coming
  /// back lands on the same row rather than at the top.
  Future<void> _open(String date) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => DayScreen(
          api: widget.api,
          date: date,
          onBack: () => Navigator.of(page).pop(),
          onCapture: widget.onCapture,
        ),
      ),
    );

    // A card answered on that page changes nothing in this list, but an entry
    // written from it does, and coming back is the only moment to notice.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final days = _days;

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: [
        const Text('Days', style: SoulType.heading),
        const SizedBox(height: 6),
        Label(_countLine(days)),
        if (days != null && days.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Legend(days: days),
        ],
        const SizedBox(height: 18),
        if (_failed) ...[
          const SizedBox(height: 30),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach your days just now. What you wrote is '
            'still there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          SoulButton('Try again', onPressed: _load),
        ] else if (days == null) ...[
          const SizedBox(height: 100),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SoulColors.clay,
              ),
            ),
          ),
        ] else if (days.isEmpty) ...[
          const SizedBox(height: 30),
          const Text('No days yet', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The first thing you say will make one.',
            style: SoulType.secondary,
          ),
        ] else ...[
          for (final day in days) ...[
            _DayRow(
              day: day,
              onTap: () => _open(day.date),
            ),
            const SizedBox(height: 10),
          ],
          // Room under the last day for the capture button that floats over
          // this screen.
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  static String _countLine(List<DayCount>? days) {
    if (days == null) return 'reading them back';
    if (days.isEmpty) return 'nothing yet';
    return days.length == 1 ? 'one day so far' : '${days.length} days so far';
  }
}

/// One day, closed. The name is what a user would call it out loud, so the
/// last two days are today and yesterday rather than dates.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onTap});

  final DayCount day;
  final VoidCallback onTap;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _palette = [
    SoulColors.clay,
    SoulColors.amber,
    SoulColors.violet,
    SoulColors.moss,
  ];

  String get _name {
    final date = DateTime.parse(day.date);
    final today = DateTime.parse(todayOnDevice());
    final apart = today.difference(date).inDays;

    if (apart == 0) return 'Today';
    if (apart == 1) return 'Yesterday';
    if (apart < 7) return _weekdays[date.weekday - 1];
    return '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';
  }

  String get _when {
    final date = DateTime.parse(day.date);
    return '${date.day} ${_months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return SoulCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // A dot per feeling in that day, in the order the day gave them.
          // Enough to recognise a day, not enough to be a chart.
          for (var i = 0; i < day.feelings.length && i < 4; i++) ...[
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: _palette[i % _palette.length],
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (day.feelings.isNotEmpty) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name,
                  style: TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 20,
                    color: SoulColors.text,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Label(
                  '$_when, ${day.count == 1 ? 'one moment' : '${day.count} moments'}',
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: SoulColors.text3),
        ],
      ),
    );
  }
}

/// What is inside the open day. The same words, in the same order they were
/// said, with nothing added, and under them whatever the day is asking about.

/// What the dots on the days mean. The first four feelings across the days,
/// in the order they appear, each with the colour its dot carries.
class _Legend extends StatelessWidget {
  const _Legend({required this.days});
  final List<DayCount> days;

  static const _palette = [
    SoulColors.clay,
    SoulColors.amber,
    SoulColors.violet,
    SoulColors.moss,
  ];

  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    for (final day in days) {
      for (final feeling in day.feelings) {
        if (!names.contains(feeling) && names.length < 4) names.add(feeling);
      }
    }
    if (names.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (var i = 0; i < names.length; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: _palette[i],
                  shape: BoxShape.circle,
                ),
              ),
              Text(names[i], style: SoulType.muted),
            ],
          ),
      ],
    );
  }
}
