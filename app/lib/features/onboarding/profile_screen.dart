import 'package:flutter/material.dart';
import '../../data/device_location.dart';
import '../../theme/soul_theme.dart';
import 'onboarding_kit.dart';
import 'profile_fields.dart';
import 'world_map.dart';

/// What a user gave at first run. Every field is optional in the type,
/// because the profile tab can empty any of them later and a half held
/// profile is a real state.
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

/// The four profile questions, one per screen, before the baseline set.
///
/// What is asked is bounded on purpose. A first name and not a full one, a
/// band and not a birthdate, a region and not a place. These are children,
/// and the answer to what else could we hold is almost always nothing.
///
/// Each one is a question inside the first run flow, which owns the
/// progress bar, the back chevron and the transition between them. The
/// screen here is only the question, its options and its continue.
enum ProfileStep { name, age, gender, where }

/// One profile question. Continue is dim until there is an answer, because
/// every question in first run is answered: see FLOW.md.
class ProfileQuestion extends StatelessWidget {
  const ProfileQuestion({
    super.key,
    required this.step,
    required this.profile,
    required this.onChanged,
    required this.onContinue,
    this.askDeviceForLocation = false,
    this.onAskedDevice,
  });

  final ProfileStep step;
  final Profile profile;
  final ValueChanged<Profile> onChanged;
  final VoidCallback onContinue;

  /// Whether the where question should ask the phone the moment it appears.
  /// Once only: the flow turns this off after the first ask, so coming back
  /// to the question does not ask twice.
  final bool askDeviceForLocation;
  final VoidCallback? onAskedDevice;

  @override
  Widget build(BuildContext context) {
    return switch (step) {
      ProfileStep.name => _NameQuestion(
          profile: profile,
          onChanged: onChanged,
          onContinue: onContinue,
        ),
      ProfileStep.age => _WheelQuestion(
          eyebrow: 'About you',
          title: 'How old are you?',
          helper: 'A band, not a birthday.',
          options: ageBands,
          chosen: profile.ageBand,
          // A wheel always shows some value. The one it shows untouched is
          // the first adult band, never a minor's, so nothing is recorded
          // about a child by a person who scrolled past without reading.
          fallback: '18_24',
          onChoose: (key) => onChanged(profile.copyWith(ageBand: key)),
          onContinue: onContinue,
        ),
      ProfileStep.gender => _ChoiceQuestion(
          eyebrow: 'About you',
          title: 'What is your gender?',
          options: genders,
          chosen: profile.gender,
          onChoose: (key) => onChanged(profile.copyWith(gender: key)),
          onContinue: onContinue,
        ),
      ProfileStep.where => _WhereQuestion(
          profile: profile,
          onChanged: onChanged,
          onContinue: onContinue,
          askOnAppear: askDeviceForLocation,
          onAsked: onAskedDevice,
        ),
    };
  }
}

class _NameQuestion extends StatefulWidget {
  const _NameQuestion({
    required this.profile,
    required this.onChanged,
    required this.onContinue,
  });

  final Profile profile;
  final ValueChanged<Profile> onChanged;
  final VoidCallback onContinue;

  @override
  State<_NameQuestion> createState() => _NameQuestionState();
}

class _NameQuestionState extends State<_NameQuestion> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.displayName ?? '');
  final _focus = FocusNode();

  String get _trimmed => _name.text.trim();

  @override
  void initState() {
    super.initState();
    // The Continue button turns on when there is something to continue with,
    // so it rebuilds on every keystroke.
    _name.addListener(() => setState(() {}));
    // After the slide in, not during it, so the keyboard does not fight the
    // transition for the screen.
    Future<void>.delayed(const Duration(milliseconds: 380), () {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _take() {
    if (_trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    widget.onChanged(widget.profile.copyWith(displayName: _trimmed));
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return QuestionScaffold(
      eyebrow: 'About you',
      title: 'What should we call you?',
      ctaTitle: 'Continue',
      ctaEnabled: _trimmed.isNotEmpty,
      onContinue: _take,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: NameField(
          controller: _name,
          focusNode: _focus,
          onSubmitted: _take,
        ),
      ),
    );
  }
}

/// A single choice from a wheel. The native picker engine, the same one
/// behind every system date and time wheel, with the inertia and the snap
/// Apple has tuned for years; a hand built wheel brings its own momentum
/// bugs. The bands are short and ordered, which is what a wheel is for.
///
/// A wheel always shows a value, so the continue is live from the start and
/// the value it shows untouched is the fallback the caller names.
class _WheelQuestion extends StatefulWidget {
  const _WheelQuestion({
    required this.eyebrow,
    required this.title,
    this.helper,
    required this.options,
    required this.chosen,
    required this.fallback,
    required this.onChoose,
    required this.onContinue,
  });

  final String eyebrow;
  final String title;
  final String? helper;
  final List<Choice> options;
  final String? chosen;
  final String fallback;
  final ValueChanged<String?> onChoose;
  final VoidCallback onContinue;

  @override
  State<_WheelQuestion> createState() => _WheelQuestionState();
}

class _WheelQuestionState extends State<_WheelQuestion> {
  late final FixedExtentScrollController _wheel;

  int _indexOf(String? key) {
    final at = widget.options.indexWhere((c) => c.key == key);
    return at < 0 ? 0 : at;
  }

  @override
  void initState() {
    super.initState();
    final start = widget.chosen ?? widget.fallback;
    _wheel = FixedExtentScrollController(initialItem: _indexOf(start));
    if (widget.chosen == null) {
      // What the wheel shows is what continue sends, so it is recorded from
      // the first frame rather than only once the wheel has been turned,
      // and it is read off the wheel itself so the two cannot disagree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final at = _wheel.hasClients ? _wheel.selectedItem : _indexOf(widget.fallback);
        widget.onChoose(widget.options[at.clamp(0, widget.options.length - 1)].key);
      });
    }
  }

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return QuestionScaffold(
      eyebrow: widget.eyebrow,
      title: widget.title,
      helper: widget.helper,
      ctaTitle: 'Continue',
      ctaEnabled: widget.chosen != null,
      onContinue: widget.onContinue,
      centered: true,
      child: SizedBox(
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The same engine as the system wheel, laid flatter: the
            // default cylinder shrinks and thins the rows above and below
            // the middle until they cannot be read, and a wheel of six
            // should be readable end to end.
            ListWheelScrollView.useDelegate(
              controller: _wheel,
              itemExtent: 48,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 2.4,
              perspective: 0.0015,
              overAndUnderCenterOpacity: 0.45,
              onSelectedItemChanged: (i) => widget.onChoose(widget.options[i].key),
              childDelegate: ListWheelChildListDelegate(
                children: [
                  for (final option in widget.options)
                    Center(
                      child: Text(
                        option.label,
                        style: const TextStyle(
                          fontFamily: SoulType.serif,
                          fontSize: 24,
                          color: SoulColors.text,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Drawn over the rows, so it is an outline. A filled band hid
            // the very value it was meant to mark.
            IgnorePointer(
              child: Container(
                height: 48,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: SoulColors.clay, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single choice from a short list. Tapping the chosen one again clears
/// it, so a mis tap is recoverable without leaving the screen.
class _ChoiceQuestion extends StatelessWidget {
  const _ChoiceQuestion({
    required this.eyebrow,
    required this.title,
    required this.options,
    required this.chosen,
    required this.onChoose,
    required this.onContinue,
  });

  final String eyebrow;
  final String title;
  final List<Choice> options;
  final String? chosen;
  final ValueChanged<String?> onChoose;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return QuestionScaffold(
      eyebrow: eyebrow,
      title: title,
      ctaTitle: 'Continue',
      ctaEnabled: chosen != null,
      onContinue: onContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            OptionRow(
              label: options[i].label,
              selected: chosen == options[i].key,
              dimmed: chosen != null && chosen != options[i].key,
              onTap: () =>
                  onChoose(chosen == options[i].key ? null : options[i].key),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where they are. The world to tap, the phone to ask, or nothing to say.
///
/// Nouvel's first onboarding, rebuilt: the whole world first, divided into
/// continents; a tap zooms to a continent, a second tap picks the country.
/// Under the map, a line to ask the phone, and a smaller one for somebody
/// who would rather not say. The list of sixteen regions the server knows
/// is unchanged. A tapped country stores as the region it belongs to, with
/// the country's own name shown back, and the three countries that span
/// several regions open a second pick for the zone.
///
/// The region is not chosen when the phone answers. The coordinates go to
/// the server and the region and timezone are derived from them there, so a
/// measured location and a picked one cannot end up as two different
/// answers. Refusal is not an error: the map stays and the question is
/// still answerable.
class _WhereQuestion extends StatefulWidget {
  const _WhereQuestion({
    required this.profile,
    required this.onChanged,
    required this.onContinue,
    required this.askOnAppear,
    this.onAsked,
  });

  final Profile profile;
  final ValueChanged<Profile> onChanged;
  final VoidCallback onContinue;
  final bool askOnAppear;
  final VoidCallback? onAsked;

  @override
  State<_WhereQuestion> createState() => _WhereQuestionState();
}

enum _Locating { idle, asking, refused, found }

class _WhereQuestionState extends State<_WhereQuestion> with WidgetsBindingObserver {
  _Locating _locating = _Locating.idle;

  /// Set when Settings was opened from here, so the phone is asked again
  /// the moment the app comes back, without another tap.
  bool _wentToSettings = false;
  Continent? _continent;
  CountryShape? _country;
  bool _skipped = false;

  /// A country whose zones are being asked for, while the sheet is up.
  CountryShape? _zoning;

  bool get _located => widget.profile.latitude != null;
  bool get _answered => _located || widget.profile.region != null || _skipped;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.askOnAppear) {
      widget.onAsked?.call();
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wentToSettings) {
      _wentToSettings = false;
      _useMyLocation();
    }
  }

  /// The line under the map. Asks the phone, or, once the phone has said
  /// no, opens the switch that says no so it can be turned back on.
  Future<void> _onLocationTap() async {
    if (_locating == _Locating.asking) return;
    if (_locating == _Locating.refused) {
      _wentToSettings = true;
      await openLocationSettings();
      return;
    }
    await _useMyLocation();
  }

  Future<void> _useMyLocation() async {
    if (!mounted || _locating == _Locating.asking) return;
    setState(() => _locating = _Locating.asking);

    final where = await currentLocation();
    if (!mounted) return;
    if (where == null) {
      setState(() => _locating = _Locating.refused);
      return;
    }

    final place = await placeName(where.latitude, where.longitude);
    if (!mounted) return;
    setState(() {
      _locating = _Locating.found;
      _skipped = false;
      _country = null;
      _zoning = null;
    });
    widget.onChanged(Profile(
      displayName: widget.profile.displayName,
      ageBand: widget.profile.ageBand,
      gender: widget.profile.gender,
      latitude: where.latitude,
      longitude: where.longitude,
      place: place,
    ));
    // The phone answered, so the question is answered. On, as the first
    // flow did, rather than a continue for something already settled.
    widget.onContinue();
  }

  /// A picked region replaces the phone's answer, so the two are never
  /// sent together as a disagreement.
  void _store(String region) {
    widget.onChanged(Profile(
      displayName: widget.profile.displayName,
      ageBand: widget.profile.ageBand,
      gender: widget.profile.gender,
      region: region,
    ));
  }

  void _onWorldTap(CountryShape shape) {
    final continent = WorldMapGeometry.continentOf(shape);
    if (continent == Continent.antarctica) return;
    setState(() => _continent = continent);
  }

  void _onCountryTap(CountryShape shape) {
    final zones = zonesByCountry[shape.iso3];
    setState(() {
      _country = shape;
      _skipped = false;
      _zoning = zones == null ? null : shape;
    });
    if (zones == null) _store(regionByCountry[shape.iso3] ?? 'elsewhere');
  }

  void _pickZone(Choice zone) {
    setState(() => _zoning = null);
    _store(zone.key);
  }

  void _preferNotToSay() {
    setState(() {
      _skipped = true;
      _country = null;
      _zoning = null;
    });
    _store('elsewhere');
    widget.onContinue();
  }

  String get _breadcrumb {
    if (_skipped) return 'Prefer not to say';
    if (_located) return widget.profile.place ?? 'Your location';
    final country = _country;
    final region = widget.profile.region;
    if (country == null) return labelFor(regions, region) ?? ' ';
    final zones = zonesByCountry[country.iso3];
    if (zones != null && region != null) {
      final zone = labelFor(zones, region);
      return zone == null ? country.name : '${country.name}, ${zone.toLowerCase()}';
    }
    return country.name;
  }

  String get _locationLabel => switch (_locating) {
        _Locating.asking => 'Finding you',
        _Locating.refused => 'Location is off. Tap to turn it on in Settings, or tap the map.',
        _ => 'Use my current location',
      };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        QuestionScaffold(
          eyebrow: 'About you',
          title: 'Where are you?',
          helper: 'So the app comes back to you in your afternoon, not in '
              'someone else\'s.',
          ctaTitle: 'Continue',
          ctaEnabled: _answered,
          onContinue: widget.onContinue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 22,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _continent == null ? 1 : 0,
                  child: const Text(
                    'Tap a region to begin',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: SoulType.serif, fontSize: 16, color: SoulColors.text3),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // The map aspect fits its 360 by 143 span, and at this height
              // it fills the width with no dead band above or below.
              SizedBox(height: 150, child: _map()),
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _onLocationTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me_outlined, size: 14, color: SoulColors.clay),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _locationLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: SoulColors.clay,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!_answered) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _preferNotToSay,
                  child: const Text(
                    'Prefer not to say',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: SoulType.sans, fontSize: 13, color: SoulColors.text3),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _breadcrumb,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: SoulType.serif, fontSize: 18, color: SoulColors.text2),
              ),
            ],
          ),
        ),
        if (_zoning != null) _zoneSheet(_zoning!),
      ],
    );
  }

  Widget _map() {
    return FutureBuilder<List<CountryShape>>(
      future: WorldMapData.load(),
      builder: (context, snapshot) {
        final shapes = snapshot.data;
        if (shapes == null) return const SizedBox.shrink();
        final byContinent = <Continent, List<CountryShape>>{};
        for (final shape in shapes) {
          byContinent.putIfAbsent(WorldMapGeometry.continentOf(shape), () => []).add(shape);
        }
        final continent = _continent;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: continent == null
              ? Stack(
                  key: const ValueKey('world'),
                  children: [
                    WorldMapView(shapes: shapes, region: MapRegion.world, onSelect: _onWorldTap),
                    IgnorePointer(child: _continentLabels(byContinent)),
                  ],
                )
              : Stack(
                  key: ValueKey(continent),
                  children: [
                    WorldMapView(
                      shapes: byContinent[continent] ?? const [],
                      region: WorldMapGeometry.boundingRegion(byContinent[continent] ?? const []),
                      highlighted: _country?.iso3,
                      onSelect: _onCountryTap,
                    ),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: GestureDetector(
                        onTap: () => setState(() => _continent = null),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: SoulColors.s1,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: SoulColors.shade, blurRadius: 8, offset: Offset(0, 2))],
                          ),
                          child: const Icon(Icons.chevron_left, size: 18, color: SoulColors.text2),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _continentLabels(Map<Continent, List<CountryShape>> byContinent) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return Stack(
        children: [
          for (final entry in byContinent.entries)
            if (entry.key != Continent.antarctica && entry.value.isNotEmpty)
              Builder(builder: (context) {
                final c = WorldMapGeometry.averageCentroid(entry.value);
                final at = WorldMapGeometry.project(c.$1, c.$2, size, MapRegion.world);
                return Positioned(
                  left: at.dx - 50,
                  top: at.dy - 9,
                  width: 100,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: SoulColors.bg.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.key.label,
                        style: const TextStyle(
                          fontFamily: SoulType.sans,
                          fontSize: 9,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                          color: SoulColors.text2,
                        ),
                      ),
                    ),
                  ),
                );
              }),
        ],
      );
    });
  }

  /// The second pick, for a country that spans several regions. A card
  /// from the bottom, the way the first flow's picker sheet came up.
  Widget _zoneSheet(CountryShape country) {
    final zones = zonesByCountry[country.iso3] ?? const <Choice>[];
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, (1 - t) * 40), child: child),
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: SoulColors.s1,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [BoxShadow(color: SoulColors.shade, blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() {
                      _zoning = null;
                      _country = null;
                    }),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.chevron_left, size: 22, color: SoulColors.text3),
                    ),
                  ),
                  Text(
                    'Which part of ${country.name}?',
                    style: SoulType.heading.copyWith(fontSize: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < zones.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                OptionRow(
                  label: zones[i].label,
                  selected: widget.profile.region == zones[i].key,
                  onTap: () => _pickZone(zones[i]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
