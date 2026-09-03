import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../data/device_location.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import '../onboarding/profile_fields.dart';

/// The profile tab.
///
/// It shows exactly what the app holds about a user and nothing it has been
/// told to hold and does not. Every line here is changeable and every line can
/// be emptied back to nothing, because a user who gave an answer at first
/// run and regrets it should not have to ask anyone.
///
/// The list of what is not held is on the screen on purpose. A child being
/// asked their age by an app is owed the other half of that sentence.
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key, required this.api});

  final SoulApi api;

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Map<String, dynamic>? _held;
  bool _failed = false;

  /// Shown under the rows when something did not work. Never an error code,
  /// and never left on the screen after the thing works.
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final held = await widget.api.profileHeld();
      if (mounted) {
        setState(() {
          _held = held;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Optimistic. The row shows the new answer straight away, because a user
  /// changing their own name should not watch a spinner to do it. A failed
  /// write is corrected by the reload underneath.
  Future<void> _change(String field, String? value) async {
    setState(() => _held = {...?_held, field: value});
    try {
      await widget.api.profile({field: value});
    } catch (_) {
      // Nothing said. The next load shows what is actually stored.
    }
    await _load();
  }

  /// Coordinates move together or not at all, so they get their own writer.
  Future<void> _changeLocation(
    double? latitude,
    double? longitude, {
    String? place,
  }) async {
    setState(() => _held = {
          ...?_held,
          'latitude': latitude,
          'longitude': longitude,
        });
    try {
      await widget.api.profile({
        'latitude': latitude,
        'longitude': longitude,
        'place': place,
      });
    } catch (_) {
      // Nothing said. The reload underneath shows what is actually stored.
    }
    await _load();
  }

  Future<void> _shareLocation() async {
    final where = await currentLocation();
    if (!mounted) return;

    if (where == null) {
      // Refused, switched off, or timed out. Saying nothing here left a button
      // that looked broken.
      setState(() => _note = 'The phone did not give a location.');
      return;
    }

    setState(() => _note = null);
    final place = await placeName(where.latitude, where.longitude);
    await _changeLocation(where.latitude, where.longitude, place: place);
  }

  String? get _name => _held?['displayName'] as String?;

  /// Where the person is, as they would say it: the place the phone named,
  /// or the broad region when the phone could not, never coordinates.
  String? get _position {
    final place = _held?['place'] as String?;
    if (place != null && place.isNotEmpty) return place;
    final latitude = (_held?['latitude'] as num?)?.toDouble();
    final longitude = (_held?['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return null;
    return labelFor(regions, _held?['region'] as String?) ?? 'Shared';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Screen(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        body: [
          const SizedBox(height: 40),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach your profile just now. It is still there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          // Without this the tab is dead for the life of the app: one failed
          // load and the only way back is to quit and reopen.
          SoulButton('Try again', onPressed: _load),
        ],
      );
    }

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: [
        const Text('Profile', style: SoulType.heading),
        const SizedBox(height: 6),
        Label(_name ?? 'what the app holds'),
        const SizedBox(height: 18),
        SoulCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            children: [
              _Row(
                label: 'Name',
                value: _name,
                onTap: () => _editName(context),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Rule(),
              ),
              _Row(
                label: 'Age',
                value: labelFor(ageBands, _held?['ageBand'] as String?),
                onTap: () => _pick(context, 'ageBand', 'How old are you?', ageBands),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Rule(),
              ),
              _Row(
                label: 'Gender',
                value: labelFor(genders, _held?['gender'] as String?),
                onTap: () => _pick(context, 'gender', 'What is your gender?', genders),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Rule(),
              ),
              // The place decides the zone, and the zone decides the hour a
              // check back arrives, so it is shown under the place.
              _Row(
                label: 'Location',
                value: _position,
                note: _held?['timezone'] as String?,
                onTap: () => _location(context),
              ),
            ],
          ),
        ),
        if (_note != null) ...[
          const SizedBox(height: 12),
          Text(_note!, style: SoulType.muted),
        ],
        const SizedBox(height: 20),
        const SizedBox(height: 24),
        // Log out forgets this phone's session. The account stays, and
        // signing in with the same Apple account or email brings it back.
        SoulButton(
          'Log out',
          onPressed: () => _logOut(context),
        ),
        const SizedBox(height: 90),
      ],
    );
  }

  Future<void> _logOut(BuildContext context) async {
    widget.api.event('logged_out');
    await clearSessionToken();
    await clearFirstRunDone();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/start', (_) => false);
  }

  Future<void> _editName(BuildContext context) async {
    final given = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SoulColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _NameSheet(initial: _name ?? ''),
    );

    if (given == null) return;
    await _change('displayName', given.isEmpty ? null : given);
  }

  /// Share it or forget it. There is no halfway, because a position held at
  /// lower precision is still a position held.
  Future<void> _location(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SoulColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your location sets your region and the hour the app comes '
                'back to you.',
                style: SoulType.lead,
              ),
              const SizedBox(height: 18),
              SoulButton(
                _position == null ? 'Share it' : 'Share it again',
                kind: SoulButtonKind.filled,
                onPressed: () => Navigator.of(sheet).pop('share'),
              ),
              if (_position != null) ...[
                const SizedBox(height: 8),
                SoulButton(
                  'Forget it',
                  onPressed: () => Navigator.of(sheet).pop('forget'),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (choice == 'share') await _shareLocation();
    if (choice == 'forget') await _changeLocation(null, null);
  }

  Future<void> _pick(
    BuildContext context,
    String field,
    String question,
    List<Choice> among,
  ) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SoulColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
                child: Text(question, style: SoulType.lead),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
                  itemCount: among.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => SoulCard(
                    onTap: () => Navigator.of(sheet).pop(among[i].key),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    child: Text(among[i].label, style: SoulType.lead),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                child: SoulButton(
                  'Leave it empty',
                  kind: SoulButtonKind.ghost,
                  // An empty string comes back as a cleared answer. Null means
                  // the sheet was dismissed and nothing changes.
                  onPressed: () => Navigator.of(sheet).pop(''),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (chosen == null) return;
    await _change(field, chosen.isEmpty ? null : chosen);
  }
}

/// One held field. The value is the user's answer, or a plain statement
/// that there is not one. Never a dash and never a blank.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    required this.onTap,
    this.note,
  });

  final String label;
  final String? value;
  final String? note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The row reads. The pencil edits. A row that opened an editor on any
    // touch turned reading the profile into a minefield.
    return Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(width: 78, child: Label(label)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value ?? 'not given',
                    style: value == null
                        ? SoulType.lead.copyWith(color: SoulColors.text3)
                        : SoulType.lead,
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(note!, style: SoulType.muted),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onTap,
              icon: const Icon(Icons.edit_outlined, size: 20, color: SoulColors.text3),
              tooltip: 'Change',
            ),
          ],
        ),
    );
  }
}

/// The name sheet owns its controller and disposes it with itself.
///
/// The controller cannot be disposed by the screen that opened the sheet. The
/// field is still mounted while the sheet animates away, and disposing a
/// controller something is still listening to trips an assertion and takes the
/// app down with it.
class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.initial});
  final String initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('What should we call you?', style: SoulType.lead),
          const SizedBox(height: 14),
          SoulField(controller: _controller, hint: 'First name', autofocus: true),
          const SizedBox(height: 16),
          SoulButton(
            'Save',
            kind: SoulButtonKind.filled,
            onPressed: () =>
                Navigator.of(context).pop(_controller.text.trim()),
          ),
          const SizedBox(height: 4),
          // Emptying is a real answer, not a cancel. The row goes back to
          // nothing and the column goes back to null.
          SoulButton(
            'Leave it empty',
            kind: SoulButtonKind.ghost,
            onPressed: () => Navigator.of(context).pop(''),
          ),
        ],
      ),
    );
  }
}
