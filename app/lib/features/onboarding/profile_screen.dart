import 'package:flutter/material.dart';
import '../../data/device_location.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'baseline_answering.dart' show ListChoices;
import 'profile_fields.dart';

/// What a user gave at first run. Every field is optional, because every
/// question can be skipped and a half answered profile is a real state.
class Profile {
  const Profile({
    this.displayName,
    this.ageBand,
    this.gender,
    this.region,
    this.latitude,
    this.longitude,
    this.place,
  });

  final String? displayName;
  final String? ageBand;
  final String? gender;
  final String? region;

  /// Present only if the user shared their location. The region is derived
  /// from these on the server, so both are never sent as a disagreement.
  final double? latitude;
  final double? longitude;

  /// Where the coordinates are, in words, from the phone.
  final String? place;

  Profile copyWith({
    String? displayName,
    String? ageBand,
    String? gender,
    String? region,
    double? latitude,
    double? longitude,
    String? place,
  }) =>
      Profile(
        displayName: displayName ?? this.displayName,
        ageBand: ageBand ?? this.ageBand,
        gender: gender ?? this.gender,
        region: region ?? this.region,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        place: place ?? this.place,
      );

  bool get isEmpty =>
      displayName == null &&
      ageBand == null &&
      gender == null &&
      region == null &&
      latitude == null;

  Map<String, Object?> toJson() => {
        'displayName': ?displayName,
        'ageBand': ?ageBand,
        'gender': ?gender,
        'region': ?region,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'place': ?place,
      };
}

/// Four questions, asked one at a time, before the baseline set.
///
/// Every one of them can be skipped and the app still works. That is the test
/// this screen has to pass: nothing here is a gate, because a user who does
/// not want to tell us their age should still be able to say what happened
/// today.
///
/// What is asked is bounded on purpose. A first name and not a full one, a
/// band and not a birthdate, a region and not a place. These are children, and
/// the answer to what else could we hold is almost always nothing.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onFinished, this.onBack});

  /// The screen before this one. The chevron on the first question goes
  /// there, so nothing in first run is a door that only opens one way.
  final VoidCallback? onBack;

  final ValueChanged<Profile> onFinished;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

enum _Step { name, age, gender, where }

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();

  Profile _profile = const Profile();
  int _index = 0;
  int? _pressed;
  bool _leaving = false;
  bool _advancing = false;
  bool _locating = false;
  bool _refused = false;
  bool _asked = false;

  _Step get _step => _Step.values[_index];

  bool get _hasName => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // The Continue button turns on when there is something to continue with,
    // so it rebuilds on every keystroke.
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    super.dispose();
  }

  /// Chosen, held for a beat so the choice is felt, then the next question.
  /// The same timing as the baseline set, so first run has one rhythm rather
  /// than two.
  Future<void> _advance({int? pressed}) async {
    // Closed synchronously. _leaving is only set after the pause below, so a
    // second tap inside those 260 milliseconds used to pass the guard and
    // advance twice, skipping a question.
    if (_advancing) return;
    _advancing = true;

    if (pressed != null) {
      setState(() => _pressed = pressed);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
    }

    setState(() => _leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    if (_index == _Step.values.length - 1) {
      widget.onFinished(_profile);
      return;
    }

    setState(() {
      _index++;
      _pressed = null;
      _leaving = false;
      _advancing = false;
    });

    // The where question asks the device the moment it appears rather than
    // waiting to be pressed. Once only: coming back to this question does not
    // ask again, because a user who said no should not be asked twice by
    // the act of tapping back.
    if (_step == _Step.where && !_asked) await _useMyLocation();
  }

  void _back() {
    if (_index == 0) {
      widget.onBack?.call();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _index--;
      _leaving = false;
      _advancing = false;
      // The earlier answer comes back highlighted rather than blank, because a
      // question that forgets what you told it looks broken.
      _pressed = _chosenAt(_Step.values[_index]);
    });
  }

  /// What is stored for a step, as an index into its options.
  int? _chosenAt(_Step step) {
    int? indexOf(List<Choice> among, String? key) {
      if (key == null) return null;
      final at = among.indexWhere((choice) => choice.key == key);
      return at < 0 ? null : at;
    }

    return switch (step) {
      _Step.name => null,
      _Step.age => indexOf(ageBands, _profile.ageBand),
      _Step.gender => indexOf(genders, _profile.gender),
      _Step.where => indexOf(regions, _profile.region),
    };
  }

  /// Asks the device where the user is.
  ///
  /// The region is not chosen here. The coordinates go to the server and the
  /// region and timezone are derived from them there, so a measured location
  /// and a picked one cannot end up as two different answers.
  ///
  /// Refusal is not an error and is not treated as one. The list stays on the
  /// screen and the question is still answerable.
  Future<void> _useMyLocation() async {
    _asked = true;
    setState(() => _locating = true);

    // Which question asked. A fix can take ten seconds, and by then the
    // user may have picked a region themselves and moved on. Landing that
    // answer late would either move the screen under their finger or overwrite
    // what they chose.
    final asking = _index;

    final where = await currentLocation();
    if (!mounted || _index != asking) return;

    if (where == null) {
      setState(() {
        _locating = false;
        _refused = true;
      });
      return;
    }

    final place = await placeName(where.latitude, where.longitude);
    if (!mounted || _index != asking) return;
    _profile = _profile.copyWith(
      latitude: where.latitude,
      longitude: where.longitude,
      place: place,
    );
    setState(() => _locating = false);
    await _advance();
  }

  void _takeName() {
    final given = _name.text.trim();
    if (given.isEmpty) return;

    FocusScope.of(context).unfocus();
    _profile = _profile.copyWith(displayName: given);
    _advance();
  }

  String get _question => switch (_step) {
        _Step.name => 'What should we call you?',
        _Step.age => 'How old are you?',
        _Step.gender => 'What is your gender?',
        _Step.where => 'Where are you?',
      };

  /// Why the question is being asked, where the reason is not obvious. A
  /// user is owed this more than an adult is, not less.
  String? get _because => switch (_step) {
        _Step.name => 'A first name is plenty. It is what the app calls you.',
        _Step.where => 'So the app comes back to you in your afternoon, '
            'not in someone else\'s.',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: SoulColors.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: _index == 0 && widget.onBack == null
                          ? null
                          : IconButton(
                              onPressed: _back,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.chevron_left,
                                  size: 24, color: SoulColors.text3),
                            ),
                    ),
                    Expanded(
                      child: _Progress(done: _index, of: _Step.values.length),
                    ),
                    // The bar says how far along this is without counting it
                    // out. Four questions do not need a scoreboard.
                    const SizedBox(width: 34),
                  ],
                ),
                const SizedBox(height: 34),
                AnimatedOpacity(
                  opacity: _leaving ? 0 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _question,
                        textAlign: TextAlign.center,
                        style: SoulType.heading.copyWith(fontSize: 27),
                      ),
                      if (_because != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _because!,
                          textAlign: TextAlign.center,
                          style: SoulType.secondary.copyWith(
                            fontFamily: SoulType.serif,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                            color: SoulColors.text3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: _leaving ? 0 : 1,
                    duration: const Duration(milliseconds: 140),
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: switch (_step) {
                        _Step.name => _Name(
                            controller: _name,
                            onDone: _takeName,
                          ),
                        _Step.age => _ChoiceList(
                            among: ageBands,
                            chosen: _pressed,
                            onChoose: (i) {
                              _profile =
                                  _profile.copyWith(ageBand: ageBands[i].key);
                              _advance(pressed: i);
                            },
                          ),
                        _Step.gender => ListChoices(
                            options: [for (final g in genders) g.label],
                            chosen: _pressed,
                            onChoose: (i) {
                              _profile =
                                  _profile.copyWith(gender: genders[i].key);
                              _advance(pressed: i);
                            },
                          ),
                        _Step.where => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SoulButton(
                                _locating
                                    ? 'Looking'
                                    : _refused
                                        ? 'Try my location again'
                                        : 'Use my location',
                                kind: SoulButtonKind.filled,
                                onPressed: _locating ? null : _useMyLocation,
                              ),
                              if (_refused) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'The phone did not give a location. '
                                  'Pick from the list instead.',
                                  textAlign: TextAlign.center,
                                  style: SoulType.muted,
                                ),
                              ],
                              const SizedBox(height: 14),
                              const Row(
                                children: [
                                  Expanded(child: Rule()),
                                  Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    child: Label('or pick one'),
                                  ),
                                  Expanded(child: Rule()),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: _ChoiceList(
                                  among: regions,
                                  chosen: _pressed,
                                  onChoose: (i) {
                                    _profile = _profile.copyWith(
                                        region: regions[i].key);
                                    _advance(pressed: i);
                                  },
                                ),
                              ),
                            ],
                          ),
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  // No skip, and no Continue that walks past an empty field.
                  // A button that advances with nothing in it is a skip button
                  // wearing another word.
                  child: _step == _Step.name
                      ? AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _hasName ? 1 : 0.4,
                          child: SoulButton(
                            'Continue',
                            kind: SoulButtonKind.filled,
                            onPressed: _hasName ? _takeName : null,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Name extends StatelessWidget {
  const _Name({required this.controller, required this.onDone});

  final TextEditingController controller;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Deliberately not wrapped in Enter. Enter keys its animation on the
          // child's identity hash, and this screen rebuilds on every keystroke
          // to drive the Continue button, so the field would be destroyed and
          // rebuilt per character: focus lost, animation replayed, and the
          // keyboard's composing region thrown away mid word.
          TextField(
              controller: controller,
              autofocus: true,
              textAlign: TextAlign.center,
              style: SoulType.field.copyWith(fontSize: 24),
              cursorColor: SoulColors.clay,
              maxLength: 40,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onDone(),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: SoulColors.s1,
                hintText: 'First name',
                hintStyle: SoulType.field
                    .copyWith(fontSize: 24, color: SoulColors.text3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: SoulColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: SoulColors.clay, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A long question, answered from a list.
///
/// Four options get the colour tiles. Six and sixteen do not fit as tiles on a
/// small phone without either shrinking them or running off the bottom, so the
/// age bands and the regions scroll instead.
class _ChoiceList extends StatelessWidget {
  const _ChoiceList({
    required this.among,
    required this.chosen,
    required this.onChoose,
  });

  final List<Choice> among;
  final int? chosen;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // Room under the last region for the skip button, which floats over
      // this list rather than sitting below it.
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: among.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final picked = chosen == i;
        return SoulCard(
          onTap: () => onChoose(i),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          background: picked ? SoulColors.clay : SoulColors.s1,
          child: Text(
            among[i].label,
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 16,
              fontWeight: picked ? FontWeight.w500 : FontWeight.w400,
              color: picked ? Colors.white : SoulColors.text,
            ),
          ),
        );
      },
    );
  }
}

/// One segment per question, filling as they are answered. The same bar the
/// baseline set uses, so first run reads as one thing of a known length.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.of});
  final int done;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 4,
              decoration: BoxDecoration(
                color: i <= done ? SoulColors.clay : SoulColors.s3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
