import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'cue_card.dart';

/// The calendar date this device is on, as YYYY-MM-DD.
///
/// The only date the client ever works out for itself, and it decides which
/// day the Days tab opens on before the user has picked one. It is not a
/// boundary: the entries inside a day are still cut by the user's own
/// timezone on the server. A phone in a different zone to the user's region
/// can open the neighbouring day, and every dot on the week strip carries a
/// date from the server, so tapping one is always exact.
String todayOnDevice() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

/// Screen 7. One day, in order.
///
/// A lens over entries that already exist. It adds nothing and interprets
/// nothing: the words are the user's, the feeling and the trigger under
/// them are the tagger's, and there is no closing observation because nothing
/// on this screen is in a position to make one.
class DayScreen extends StatefulWidget {
  const DayScreen({
    super.key,
    required this.api,
    required this.date,
    required this.onBack,
    this.onCapture,
    this.revision = 0,
  });

  final SoulApi api;

  /// YYYY-MM-DD, as the week gave it back.
  final String date;

  final VoidCallback onBack;

  /// Adds something else to today. Absent on a day that has already been,
  /// because an entry written now belongs to now and putting it on last
  /// Tuesday would be the app writing something nobody said then.
  final VoidCallback? onCapture;

  /// Changes when an entry lands. The entry belongs to a day, and if that day
  /// is the one on screen it should be on it.
  final int revision;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  DayView? _day;
  bool _failed = false;

  /// What the user chose, per card, for as long as this page is open. The
  /// day says a card was answered and never what with, so a card answered here
  /// can show it and one answered on another day cannot.
  final Map<String, CueCardAnswer> _answers = {};

  /// Cards put off during this visit, so the pile moves on at once rather
  /// than waiting for the day to be read again.
  final Set<String> _later = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DayScreen old) {
    super.didUpdateWidget(old);
    // The tab stays alive while another day is picked, so the date changing is
    // the signal to go and get that one.
    if (widget.date != old.date || widget.revision != old.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _day = null;
      _failed = false;
    });
    try {
      final day = await widget.api.day(widget.date);
      if (mounted) setState(() => _day = day);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    final colours = day == null ? const <Color>[] : _colours(day.entries);

    final today = todayOnDevice() == widget.date;

    return Screen(
      floating: widget.onCapture != null && today
          ? GestureDetector(
              onTap: widget.onCapture,
              child: Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: SoulColors.clay,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x4DEA5F17),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
      body: [
        _Header(date: widget.date, onBack: widget.onBack),
        if (_failed) ...[
          const SizedBox(height: 40),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach this day just now. What you wrote is '
            'still there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          // Without this the day is dead until the app is quit and reopened.
          SoulButton('Try again', onPressed: _load),
        ] else if (day == null) ...[
          const SizedBox(height: 120),
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
        ] else if (day.entries.isEmpty) ...[
          const SizedBox(height: 40),
          const Text('Nothing on this day', style: SoulType.heading),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Label(_countLine(day.entries.length)),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < day.entries.length; i++)
            _TimelineItem(
              entry: day.entries[i],
              colour: colours[i],
              last: i == day.entries.length - 1,
            ),
          // Under the day, because a card asks what happens next about
          // something that is already up there in the user's own words.
          //
          // Only the top of the pile is shown. Four questions at once is a
          // form, and the answer to the second one often depends on what was
          // said to the first. The edges of the ones behind it show that
          // there are more, and answering or putting off brings the next one
          // forward.
          ..._pile(day),
          // Room under the last entry for the capture button that floats over
          // this screen.
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  /// The cards, as a pile with one on top and the answered ones under it.
  List<Widget> _pile(DayView day) {
    final waiting = [
      for (final card in day.cards)
        if (!card.answered && _answers[card.id] == null && !_later.contains(card.id)) card,
    ];
    final done = [
      for (final card in day.cards)
        if (card.answered || _answers[card.id] != null) card,
    ];

    return [
      if (waiting.isNotEmpty) ...[
        const SizedBox(height: 22),
        CueCardTile(
          // Keyed by the card, not by where it sits. Matched by position, a
          // day whose cards reorder hands one card's typed words and its
          // half made answer to the next one, and a user can answer a card
          // they never read.
          key: ValueKey(waiting.first.id),
          card: waiting.first,
          answer: _answers[waiting.first.id],
          behind: waiting.length - 1,
          onAnswer: (answer) => _answer(waiting.first, answer),
          onLater: () => _later_(waiting.first),
        ),
        // The edges of the cards underneath, tucked up so they read as one
        // pile rather than three separate things.
        for (var i = 1; i < waiting.length && i < 3; i++)
          Transform.translate(
            offset: Offset(0, -6.0 * i),
            child: Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 10.0 * i),
                height: 10,
                decoration: BoxDecoration(
                  color: SoulColors.s1,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  border: Border.all(color: SoulColors.border),
                ),
              ),
            ),
          ),
        if (waiting.length > 1) ...[
          const SizedBox(height: 10),
          Center(
            child: Label(
              waiting.length == 2 ? 'one more after this' : '${waiting.length - 1} more after this',
            ),
          ),
        ],
      ],
      for (final card in done) ...[
        const SizedBox(height: 22),
        CueCardTile(
          key: ValueKey(card.id),
          card: card,
          answer: _answers[card.id],
          onAnswer: (answer) => _answer(card, answer),
        ),
      ],
    ];
  }

  /// Put off until tomorrow. Nothing is recorded about the question itself,
  /// so the next one comes forward and this one comes back another day.
  Future<void> _later_(CueCard card) async {
    setState(() => _later.add(card.id));
    try {
      await widget.api.laterCard(card.id);
    } catch (_) {
      // It stays out of the way for this visit either way. The day is read
      // again next time and the card comes back if the server never heard.
    }
  }

  /// One card answered. A yes writes a decision and books the check back, a
  /// no writes neither and is recorded as what it is.
  ///
  /// It throws back to the card when the answer did not land, because the card
  /// is where the user is looking and where the way back belongs.
  Future<void> _answer(CueCard card, CueCardAnswer answer) async {
    try {
      await widget.api.answerCard(
        cardId: card.id,
        yes: answer.yes,
        detail: answer.detail,
        horizonDays: answer.horizonDays,
      );
      if (mounted) setState(() => _answers[card.id] = answer);
    } on SoulApiException catch (failure) {
      // Answered already, or not this user's card. Neither is something a
      // second tap fixes, so the day is read again and the card comes back
      // saying what it now is.
      if (failure.status == 409 || failure.status == 404) {
        // The answer already yielded, so this page may be gone.
        if (mounted) await _load();
        return;
      }
      rethrow;
    }
  }

  static String _countLine(int entries) =>
      entries == 1 ? 'one moment, in order' : '$entries moments, in order';

  /// A colour for each dot on the timeline.
  ///
  /// Entries that share a feeling share a colour, so a day where the same
  /// thing kept happening looks like one. The four colours are handed out in
  /// the order the feelings appear, because nothing in the contract says which
  /// feeling is which colour and a colour picked here is only ever a way to
  /// group what is on this screen. An entry the tagger has not reached yet
  /// takes the quiet one.
  static List<Color> _colours(List<DayEntry> entries) {
    const palette = [
      SoulColors.clay,
      SoulColors.amber,
      SoulColors.violet,
      SoulColors.moss,
    ];

    final assigned = <String, Color>{};
    return [
      for (final entry in entries)
        if (entry.feeling == null)
          SoulColors.border2
        else
          assigned.putIfAbsent(
            entry.feeling!,
            () => palette[assigned.length % palette.length],
          ),
    ];
  }
}

/// The way back, and which day this is. Shown before the entries arrive, so
/// the screen never goes blank while it loads.
class _Header extends StatelessWidget {
  const _Header({required this.date, required this.onBack});

  final String date;
  final VoidCallback onBack;

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

  /// A date the user would say out loud. Built from the digits in the
  /// string rather than from an instant, so nothing here can slide into the
  /// day before.
  String get _spoken {
    final on = DateTime.tryParse(date);
    if (on == null) return date;
    return '${_weekdays[on.weekday - 1]} ${on.day} ${_months[on.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(
            Icons.chevron_left,
            size: 22,
            color: SoulColors.text3,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _spoken,
          style: const TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 16,
            color: SoulColors.text,
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.entry,
    required this.colour,
    required this.last,
  });

  final DayEntry entry;
  final Color colour;
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
                  color: colour,
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
                  // All of it. These are the user's own words and cutting
                  // them off at a line count would be the app deciding which
                  // part mattered.
                  Text(entry.text, style: SoulType.field),
                  if (entry.feeling != null) ...[
                    const SizedBox(height: 4),
                    Label(entry.feeling!),
                  ],
                  if (entry.trigger != null) ...[
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SoulColors.clayLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        entry.trigger!,
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
