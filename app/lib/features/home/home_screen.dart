import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, listEquals;
import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../data/analytics.dart';
import '../../data/device_location.dart';
import '../../data/flags.dart';
import '../../data/device_weather.dart';
import '../../api/models.dart';
import '../day/day_screen.dart';
import '../../theme/soul_theme.dart';
import 'feedback_sheet.dart';
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
    required this.onOpenPerson,
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

  /// Opens somebody's page, from a chip or a node on the map.
  final ValueChanged<String> onOpenPerson;

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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  HomeView? _home;
  bool _failed = false;

  /// Asked for on its own rather than as part of the week, so a slow or
  /// unreachable weather service costs this card and nothing else on the
  /// screen. Null is the ordinary answer when no position was ever shared.
  /// The one line on the card. Written by the service from what the phone
  /// found, and the app's own plain question when that does not arrive.
  String? _ask;

  /// What to call them in the greeting.
  ///
  /// It arrives with the screen only on the launch that finished first run,
  /// so on every launch after that it was missing and the greeting had no
  /// name in it. It is read from the profile when it is not handed over.
  String? _name;

  /// Which days have something on them, across the whole strip rather than
  /// the seven the week returns. Empty until it lands, which only means no
  /// marks for a moment.
  Set<String> _written = {};

  /// How far back the strip goes. Six weeks is further than anybody scrolls
  /// to look at a day and short enough that the row is not a year long.
  static const _stripDays = 42;

  final _strip = ScrollController();

  /// Whether the strip has been scrolled off today, which is when there is
  /// anything to go back to.
  bool _scrolled = false;

  /// The strip is inside the branch that waits for the week, so it does not
  /// exist on the first frame. This puts it on today the first frame it
  /// does exist, whatever a restored offset says.
  bool _stripPlaced = false;

  @override
  void initState() {
    super.initState();
    _name = widget.name;
    _load();
    WidgetsBinding.instance.addObserver(this);
    _sky();
    _marks();
    if (_name == null) _whoTheyAre();
    _strip.addListener(() {
      if (!_strip.hasClients) return;
      final away = _strip.offset > 40;
      if (away != _scrolled) setState(() => _scrolled = away);
    });
  }

  /// Coming back to the app is opening it. The card is about where somebody
  /// is standing and what the sky is doing there, and both of those change
  /// while a phone is in a pocket. Without this the card was written once at
  /// launch and then sat there for as long as the app stayed in memory,
  /// which on a phone is days.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _sky();
    _load();
    _marks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _strip.dispose();
    super.dispose();
  }

  /// The name they gave, when the screen was not handed it.
  Future<void> _whoTheyAre() async {
    try {
      final held = await widget.api.profileHeld();
      // The account, not the person: a random id, so the same account on a
      // second phone is one line in a funnel rather than two.
      final account = held['accountId'] as String?;
      if (account != null) {
        await identify(
          account,
          entriesWritten: (held['entriesWritten'] as num?)?.toInt(),
          email: held['email'] as String?,
          name: held['displayName'] as String?,
        );
      }
      final name = held['displayName'] as String?;
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _name = name);
      }
    } catch (_) {
      // The greeting says good afternoon on its own perfectly well.
    }
  }

  /// Every day this person has written on, for the marks under the dates.
  Future<void> _marks() async {
    try {
      final days = await widget.api.days();
      if (mounted) setState(() => _written = {for (final d in days) d.date});
    } catch (_) {
      // No marks this time. The dates are still there and still open.
    }
  }

  /// The dates in the strip, today first. The row is drawn reversed, so
  /// today sits at the right hand end and is where it opens, with no jump
  /// to make once it has been laid out.
  List<DateTime> get _dates {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var back = 0; back < _stripDays; back++)
        today.subtract(Duration(days: back)),
    ];
  }

  static String _iso(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  void didUpdateWidget(covariant HomeScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) {
      _load();
      // Asked for again whenever the week is, so a first attempt that
      // found nothing is not the last word for the life of the app. It
      // failed once against a service that was still deploying and the
      // card stayed missing until the app was closed and opened.
      if (_ask == null) _sky();
    }
  }

  /// Where to look, and then the weather itself from Apple on this device,
  /// so the position never leaves the phone.
  ///
  /// Where to look is the phone's own position, asked for the first time
  /// home opens, so the card is about where somebody is standing rather
  /// than where they were when they first opened the app. It falls back to
  /// what the service holds, which is the position they gave in the profile
  /// or the middle of the region they picked.
  ///
  /// The phone's position is never written anywhere. The one in the profile
  /// is theirs, and only they change it.
  ///
  /// Null anywhere along the way means no card, which is an ordinary answer
  /// and is not shown as a failure. A card answered today is not shown
  /// again until tomorrow, and tapping one is not answering it.
  Future<void> _sky() async {
    // The whole weather path behind one switch: the position, Apple, the
    // geocoder and the written question. Off is a home with no card, which
    // is a state this screen already knows how to be.
    if (!isOn(Flag.weatherCard)) return;

    final where = await widget.api.weatherWhere();
    if (where != null && where.answeredToday) return;

    // Where the phone is, then where it last was, then the ones before
    // that, then the position in the profile. The card is shown whatever
    // this answers, because a card that disappears when somebody is in a
    // basement reads as an app that broke.
    final here = await locationForCard();
    final latitude = here?.latitude ?? where?.latitude;
    final longitude = here?.longitude ?? where?.longitude;
    final fahrenheit = where?.fahrenheit ?? true;

    DeviceWeather? sky;
    if (latitude != null && longitude != null) {
      sky = await weatherAt(
        latitude: latitude,
        longitude: longitude,
        fahrenheit: fahrenheit,
      );

      // Apple declines on a simulator, which is where most of this is looked
      // at. In a debug build the service reads it instead so the card is
      // there to look at. A release build never asks.
      if (sky == null && kDebugMode) {
        final reading = await widget.api.weatherReading(
          latitude: latitude,
          longitude: longitude,
        );
        final condition = reading?['condition'] as String?;
        final celsius = (reading?['celsius'] as num?)?.toDouble();
        if (condition != null && celsius != null) {
          sky = readingToWeather(
            condition: condition,
            celsius: celsius,
            daylight: reading?['daylight'] as bool? ?? true,
            fahrenheit: fahrenheit,
          );
        }
      }
    }

    final found = sky;
    if (!mounted) return;

    final place = latitude == null || longitude == null
        ? null
        : (await placeName(latitude, longitude))?.split(',').first.trim();
    if (!mounted) return;

    // The sky is one of the things the question can be built from, not the
    // thing it needs. A phone that could not read it still gets a question
    // written from the time, the day, the season and where they left off.
    final written = await widget.api.weatherQuestion(
      condition: found?.condition,
      degrees: found?.degrees,
      fahrenheit: fahrenheit,
      daylight: found?.daylight,
      place: place,
    );
    if (!mounted) return;
    setState(() => _ask = written ?? found?.plainIn(place) ?? _plainAsk);
  }

  /// What the card asks when there is no sky to ask about.
  static const _plainAsk = 'What has today been like so far?';

  Future<void> _load() async {
    setState(() {
      _home = null;
      _failed = false;
    });
    try {
      final home = await widget.api.home();
      if (mounted) setState(() => _home = home);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final home = _home;

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: [
        if (_failed)
          ..._notLoaded()
        else if (home == null)
          ..._waiting()
        // Nothing at all: no answers held, nothing written. A rostered
        // account that skipped first run, and nobody else for long.
        else if (home.moments == 0 && home.tiles.isEmpty && home.map.nodes.isEmpty)
          ..._dayOne()
        else
          ..._populated(home),
        // Under everything, on every state of this screen including the one
        // that would not load, because a screen that failed is exactly when
        // somebody has something to say. Not while the week is still coming:
        // there is nothing to have an opinion about yet.
        if (home != null || _failed) ..._tellUs(),
      ],
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

  /// The greeting, the date, and the way to the profile.
  ///
  /// On every state of this screen, not only the one with a week in it. It
  /// used to sit inside the populated branch, so a person whose week had
  /// nothing in it, or whose week would not load, had no profile button on
  /// screen and therefore no way to reach sign in or log out.
  List<Widget> _header() => [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting(_name), style: SoulType.heading),
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
      ];

  List<Widget> _waiting() => [
        ..._header(),
        const SizedBox(height: 120),
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
        ..._header(),
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
        ..._header(),
        const SizedBox(height: 40),
        const Text('Nothing here yet', style: SoulType.heading),
        const SizedBox(height: 14),
        const Text(
          'This fills in as you go. One moment is enough to start.',
          style: SoulType.secondary,
        ),
      ];

  /// The way to say something about the app.
  ///
  /// Quiet, at the bottom, under whatever the week turned out to be. Loud
  /// would be an app asking to be rated, which is the opposite of what this
  /// product is for. Findable, because the alternative is somebody deciding
  /// on their own that nobody is listening.
  ///
  /// Neutral words. It asked what was not working, which is a question with
  /// its answer already in it and no room for anybody who liked something.
  List<Widget> _tellUs() => [
        const SizedBox(height: 36),
        Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.api.event('feedback_opened', {'surface': 'home'});
              openFeedback(context, surface: 'home');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Text(
                'Give us feedback',
                style: SoulType.secondary.copyWith(
                  color: SoulColors.text3,
                  decoration: TextDecoration.underline,
                  decorationColor: SoulColors.text3,
                ),
              ),
            ),
          ),
        ),
      ];

  /// Opens the check back, and records what they say.
  ///
  /// This is the only place in the product where an outcome is written, and
  /// without it the two sections built on outcomes could never fill: the job
  /// marks a decision due and nothing ever asked about it.
  Future<void> _askHowItWent(String decisionId, String chose) async {
    final answer = await Navigator.of(context).push<({String? happened, String? felt})>(
      MaterialPageRoute(
        builder: (page) => OutcomeScreen(
          decision: chose,
          onDone: (happened, felt) =>
              Navigator.of(page).pop((happened: happened, felt: felt)),
        ),
      ),
    );

    if (answer == null || !mounted) return;

    try {
      await widget.api.recordOutcome(
        decisionId: decisionId,
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

  List<Widget> _populated(HomeView home) {
    final today = todayOnDevice();

    return [
      // The ring, as the original design had it.
      //
      // Four tiles replaced it for a while and they were louder but flatter:
      // four numbers side by side say how much of each, and the ring says
      // how the week divided. The proportion is the point, so it is drawn as
      // one shape rather than four.
      ..._header(),
      const SizedBox(height: 16),
      // The strip runs back six weeks and opens on today, so a day from
      // last month is a scroll rather than a search. Today sits at the
      // right hand end, where the row starts.
      SizedBox(
        height: 78,
        child: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                if (!_stripPlaced && _strip.hasClients) {
                  _stripPlaced = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_strip.hasClients && _strip.offset != 0) {
                      _strip.jumpTo(0);
                      if (mounted) setState(() => _scrolled = false);
                    }
                  });
                }
                return false;
              },
              child: ListView(
              controller: _strip,
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.only(left: 4),
              children: [
                for (final day in _dates)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _DayColumn(
                      date: _iso(day),
                      written: _written.contains(_iso(day)),
                      today: _iso(day) == today,
                      onTap: _written.contains(_iso(day))
                          ? () => widget.onOpenDay(_iso(day))
                          : () => widget.onCapture(),
                    ),
                  ),
              ],
            ),
            ),
            // The way back, only while there is anywhere to come back from.
            if (_scrolled)
              Positioned(
                right: 0,
                top: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _strip.animateTo(
                    0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SoulColors.clay,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(color: SoulColors.shade, blurRadius: 10),
                      ],
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: SoulType.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (_ask != null) ...[
        const SizedBox(height: 16),
        SoulCard(
          background: SoulColors.clayLight,
          borderColor: const Color(0x33EA5F17),
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          onTap: () => widget.onCapture(prompt: _ask),
          // The mic sits beside the question rather than under it. On its
          // own row it left a band of empty card below the words and made
          // the card twice the height of what it says.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Full size, and a second line rather than smaller type. A
              // question that shrinks to fit is a question nobody reads.
              Expanded(
                child: Text(
                  _ask!,
                  style: const TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 25,
                    height: 1.25,
                    color: SoulColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: SoulColors.clay,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none, size: 21, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
      // What they said about how they decide, filled in by what they have
      // written since. The first thing on the screen that is about them, and
      // it is there the minute first run ends. Decision 279.
      if (home.tiles.isNotEmpty) ...[
        const SizedBox(height: 18),
        _TilesCard(
          moments: home.moments,
          tiles: home.tiles,
          opening: home.opening,
          onOpenTile: (tile) {
            if (tile.lastOn != null) widget.onOpenDay(tile.lastOn!);
          },
        ),
      ],
      // The people and things around them, growing with every entry.
      if (home.map.nodes.isNotEmpty) ...[
        const SizedBox(height: 14),
        _MapCard(
          map: home.map,
          opening: home.tiles.isEmpty ? home.opening : null,
          onOpenPerson: widget.onOpenPerson,
        ),
      ],
      // What is waiting for an answer: a check back on something they
      // decided, or a card about something they said was coming up.
      if (home.leftOff != null) ...[
        const SizedBox(height: 14),
        SoulCard(
          background: SoulColors.clayLight,
          borderColor: const Color(0x33EA5F17),
          onTap: () {
            final left = home.leftOff!;
            if (left.kind == 'decision') {
              _askHowItWent(left.id, left.text);
            } else {
              widget.onCapture(prompt: left.text);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('where you left off'),
              const SizedBox(height: 6),
              Text(
                home.leftOff!.text,
                style: const TextStyle(
                  fontFamily: SoulType.serif,
                  fontSize: 18,
                  height: 1.35,
                  color: SoulColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      home.leftOff!.kind == 'decision'
                          ? 'How did it go?'
                          : 'Say how it is going',
                      style: SoulType.secondary,
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: SoulColors.text3),
                ],
              ),
            ],
          ),
        ),
      ],
      if (home.coming.isNotEmpty) ...[
        const SizedBox(height: 14),
        SoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('coming up'),
              const SizedBox(height: 4),
              for (var i = 0; i < home.coming.length; i++)
                _RowLine(
                  first: i == 0,
                  onTap: () => widget.onCapture(prompt: home.coming[i].said),
                  child: RichText(
                    text: TextSpan(
                      style: SoulType.secondary.copyWith(color: SoulColors.text),
                      children: [
                        TextSpan(
                          text: _dayWord(home.coming[i].on, today),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        TextSpan(text: ' \u00b7 ${home.coming[i].said}'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      if (home.people.isNotEmpty) ...[
        const SizedBox(height: 14),
        SoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('people this week'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final person in home.people)
                    _Chip(
                      text: person.name,
                      onTap: () => widget.onOpenPerson(person.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
      if (home.decisions.isNotEmpty) ...[
        const SizedBox(height: 14),
        SoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Label('what you decided'),
              const SizedBox(height: 4),
              for (var i = 0; i < home.decisions.length; i++)
                _RowLine(
                  first: i == 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        home.decisions[i].chose,
                        style: SoulType.secondary.copyWith(color: SoulColors.text),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: switch (home.decisions[i].felt) {
                                'lighter' => SoulColors.moss,
                                'worse' => SoulColors.clay,
                                'same' => SoulColors.amber,
                                _ => SoulColors.border2,
                              },
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            switch (home.decisions[i].felt) {
                              'lighter' => 'left you lighter',
                              'worse' => 'left you worse',
                              'same' => 'left you about the same',
                              _ => 'not answered yet',
                            },
                            style: SoulType.muted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
      // The week as three sentences, written on Sunday and held all week.
      if (home.week != null) ...[
        const SizedBox(height: 14),
        SoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Label(
                'the week from ${_dateWords(home.week!.from)}, '
                '${_momentLine(home.week!.moments)}',
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < home.week!.lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Text(
                  home.week!.lines[i],
                  style: const TextStyle(
                    fontFamily: SoulType.serif,
                    fontSize: 17,
                    height: 1.35,
                    color: SoulColors.text,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 60),
    ];
  }

  static String _momentLine(int moments) =>
      moments == 1 ? 'one moment' : '$moments moments';

  /// Today, tomorrow, or the weekday, for a date within the next two weeks.
  static String _dayWord(String iso, String today) {
    if (iso == today) return 'Today';
    final day = DateTime.tryParse(iso);
    final now = DateTime.tryParse(today);
    if (day == null || now == null) return iso;
    final days = day.difference(now).inDays;
    if (days == 1) return 'Tomorrow';
    if (days < 7) return _weekdays[day.weekday - 1];
    return '${day.day} ${_months[day.month - 1]}';
  }

  static String _dateWords(String iso) {
    final day = DateTime.tryParse(iso);
    if (day == null) return iso;
    return '${day.day} ${_months[day.month - 1]}';
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
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

/// One of the five tiles: what they said, and whether it has been seen.
///
/// A tile is solid in its section colour once at least one entry has shown
/// it, and outlined until then. The grid reads as the answers on day one and
/// as the evidence later, and the difference between the two is the point.
class _TilesCard extends StatelessWidget {
  const _TilesCard({
    required this.moments,
    required this.tiles,
    required this.opening,
    required this.onOpenTile,
  });

  final int moments;
  final List<HomeTile> tiles;
  final String? opening;
  final ValueChanged<HomeTile> onOpenTile;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final last = i + 1 >= tiles.length;
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _Tile(tile: tiles[i], wide: last, onTap: () => onOpenTile(tiles[i]))),
          if (!last) ...[
            const SizedBox(width: 8),
            Expanded(child: _Tile(tile: tiles[i + 1], onTap: () => onOpenTile(tiles[i + 1]))),
          ],
        ],
      ));
      if (!last) rows.add(const SizedBox(height: 8));
    }

    return SoulCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Label(
              'how you decide, as you told us \u00b7 '
              '${moments == 1 ? 'one moment' : '$moments moments'} this week',
            ),
          ),
          const SizedBox(height: 10),
          ...rows,
          if (opening != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                opening!,
                style: const TextStyle(
                  fontFamily: SoulType.serif,
                  fontSize: 17,
                  height: 1.35,
                  color: SoulColors.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tile, required this.onTap, this.wide = false});

  final HomeTile tile;
  final VoidCallback onTap;
  final bool wide;

  static const _colours = <String, (Color, Color, Color)>{
    // section: (mark, tint, text on tint)
    'timing': (SoulColors.clay, SoulColors.clayLight, SoulColors.clayDark),
    'agency': (SoulColors.amber, Color(0xFFFFF6E0), Color(0xFF8A5A00)),
    'emotion': (SoulColors.violet, Color(0xFFEFEDFB), Color(0xFF3E36A0)),
    'repetition': (SoulColors.moss, Color(0xFFEAF3E6), Color(0xFF2C6320)),
    'readiness': (SoulColors.clay, SoulColors.clayLight, SoulColors.clayDark),
  };

  @override
  Widget build(BuildContext context) {
    final (mark, tint, ink) = _colours[tile.section] ??
        (SoulColors.clay, SoulColors.clayLight, SoulColors.clayDark);
    final seen = tile.seen > 0;
    final title = tile.section == 'readiness' ? 'right now' : tile.section;
    final status = seen
        ? 'showed up in ${tile.seen == 1 ? 'one moment' : '${tile.seen} moments'}'
        : 'not seen yet in what you wrote';

    final glyph = SizedBox(
      width: 56,
      height: 34,
      child: CustomPaint(painter: _SectionGlyph(tile.section, mark, seen)),
    );
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SoulType.muted.copyWith(color: ink, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          tile.answers.join(' \u00b7 '),
          style: SoulType.secondary.copyWith(color: SoulColors.text, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 5),
        Text(status, style: SoulType.muted.copyWith(color: ink, fontSize: 11)),
      ],
    );

    return GestureDetector(
      onTap: seen ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: seen ? tint : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seen ? tint : mark.withValues(alpha: 0.55),
            width: seen ? 1 : 1.2,
          ),
        ),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [glyph, const SizedBox(width: 12), Expanded(child: words)],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [glyph, const SizedBox(height: 4), words],
              ),
      ),
    );
  }
}

/// A small mark per section, echoing the scene each pair of questions was
/// answered with: an orb, a few joined stars, ripples, two arcs, a dial.
class _SectionGlyph extends CustomPainter {
  const _SectionGlyph(this.section, this.colour, this.solid);

  final String section;
  final Color colour;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..color = solid ? colour : colour.withValues(alpha: 0.45);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = colour.withValues(alpha: solid ? 0.45 : 0.3);

    switch (section) {
      case 'timing':
        canvas.drawCircle(c, 15, line);
        canvas.drawCircle(c, 9, fill);
      case 'agency':
        final a = Offset(c.dx - 18, c.dy + 8);
        final b = Offset(c.dx, c.dy - 8);
        final d = Offset(c.dx + 18, c.dy + 4);
        canvas.drawLine(a, b, line);
        canvas.drawLine(b, d, line);
        canvas.drawCircle(a, 3, fill);
        canvas.drawCircle(b, 4, fill);
        canvas.drawCircle(d, 3, fill);
      case 'emotion':
        canvas.drawCircle(c, 16, line);
        canvas.drawCircle(c, 10, line);
        canvas.drawCircle(c, 4.5, fill);
      case 'repetition':
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = solid ? colour : colour.withValues(alpha: 0.45);
        canvas.drawArc(Rect.fromCircle(center: c.translate(0, 8), radius: 18), math.pi, math.pi, false, arc);
        canvas.drawArc(Rect.fromCircle(center: c.translate(0, 8), radius: 11), math.pi, math.pi, false, arc..color = colour.withValues(alpha: solid ? 0.5 : 0.3));
      default:
        final base = c.translate(0, 9);
        canvas.drawArc(Rect.fromCircle(center: base, radius: 17), math.pi, math.pi, false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.28));
        canvas.drawLine(base, base.translate(11, -12), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = solid ? colour : colour.withValues(alpha: 0.5));
    }
  }

  @override
  bool shouldRepaint(_SectionGlyph old) =>
      old.section != section || old.colour != colour || old.solid != solid;
}

/// The people and things around them, drawn from what they have said.
///
/// The person is the dot in the middle. Whoever they have named sits on a
/// ring around them, closer and larger the more they have come up lately,
/// with hairlines out from the middle. It grows with every entry and never
/// rewards anything: it only draws what is already there.
class _MapCard extends StatelessWidget {
  const _MapCard({
    required this.map,
    required this.opening,
    required this.onOpenPerson,
  });

  final HomeMap map;
  final String? opening;
  final ValueChanged<String> onOpenPerson;

  static const _height = 210.0;

  @override
  Widget build(BuildContext context) {
    return SoulCard(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Label('you, and who is around'),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final size = Size(box.maxWidth, _height);
              final placed = _place(map.nodes, size);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (tap) {
                  for (final node in placed) {
                    if ((tap.localPosition - node.at).distance < 26 && node.node.kind == 'person') {
                      onOpenPerson(node.node.id);
                      return;
                    }
                  }
                },
                child: CustomPaint(size: size, painter: _MapPainter(placed, map.edges)),
              );
            },
          ),
          if (opening != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                opening!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: SoulType.serif,
                  fontSize: 17,
                  height: 1.35,
                  color: SoulColors.text,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Heavier nodes on the inner ring, lighter on the outer, spread evenly.
  static List<_Placed> _place(List<HomeNode> nodes, Size size) {
    final centre = Offset(size.width / 2, size.height / 2 + 4);
    final sorted = [...nodes]..sort((a, b) => b.weight.compareTo(a.weight));
    final inner = sorted.take(4).toList();
    final outer = sorted.skip(4).toList();
    final out = <_Placed>[];
    void ring(List<HomeNode> group, double radius, double offset) {
      for (var i = 0; i < group.length; i++) {
        final angle = offset + (i / group.length) * math.pi * 2;
        out.add(_Placed(
          node: group[i],
          at: centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.72),
        ));
      }
    }
    ring(inner, math.min(size.width, 300) * 0.28, -math.pi / 2 + 0.4);
    ring(outer, math.min(size.width, 300) * 0.44, -math.pi / 2 - 0.3);
    return out;
  }
}

class _Placed {
  const _Placed({required this.node, required this.at});
  final HomeNode node;
  final Offset at;
}

class _MapPainter extends CustomPainter {
  const _MapPainter(this.placed, this.edges);

  final List<_Placed> placed;
  final List<HomeEdge> edges;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2 + 4);
    final hair = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = SoulColors.border2;
    final heavy = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFF0997B);

    final maxWeight = placed.fold<int>(1, (m, p) => math.max(m, p.node.weight));
    for (final p in placed) {
      canvas.drawLine(centre, p.at, p.node.weight >= maxWeight && p.node.weight > 1 ? heavy : hair);
    }
    final byId = {for (final p in placed) p.node.id: p.at};
    for (final e in edges) {
      final a = byId[e.from];
      final b = byId[e.to];
      if (a != null && b != null) canvas.drawLine(a, b, hair..color = SoulColors.border);
    }

    canvas.drawCircle(centre, 10, Paint()..color = SoulColors.clay);

    for (final p in placed) {
      final big = p.node.weight >= maxWeight && p.node.weight > 1;
      canvas.drawCircle(
        p.at,
        big ? 8 : 6,
        Paint()..color = big ? const Color(0xFFFFD9C4) : SoulColors.s3,
      );
      canvas.drawCircle(
        p.at,
        big ? 8 : 6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = big ? const Color(0xFFF0997B) : SoulColors.border2,
      );
      final text = TextPainter(
        text: TextSpan(
          text: p.node.name,
          style: const TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 11,
            color: SoulColors.text,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '\u2026',
      )..layout(maxWidth: 90);
      final above = p.at.dy < centre.dy;
      text.paint(
        canvas,
        Offset(
          (p.at.dx - text.width / 2).clamp(2, size.width - text.width - 2),
          above ? p.at.dy - 12 - text.height : p.at.dy + 11,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      !listEquals(old.placed.map((p) => p.node.id).toList(), placed.map((p) => p.node.id).toList()) ||
      old.edges.length != edges.length;
}

/// One row in a list card, with a hairline above every row but the first.
class _RowLine extends StatelessWidget {
  const _RowLine({required this.child, required this.first, this.onTap});

  final Widget child;
  final bool first;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: EdgeInsets.only(top: first ? 6 : 10, bottom: 4),
      child: child,
    );
    final row = first
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Container(height: 1, color: SoulColors.border), body],
          );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: SoulColors.s1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SoulColors.border2),
        ),
        child: Text(text, style: SoulType.secondary.copyWith(color: SoulColors.text, fontSize: 13)),
      ),
    );
  }
}
