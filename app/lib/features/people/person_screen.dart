import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// One person, and everything the app holds about them.
///
/// The order on this page is deliberate. What the user can change comes
/// first, then what the app worked out, then their own words underneath. A
/// user reading about somebody they know should reach the edit and the
/// delete before they reach our description of the relationship.
///
/// Everything under the profile is the user's own entries, unedited. The
/// only sentence on this page we wrote is the profile itself, and it says so.
class PersonScreen extends StatefulWidget {
  const PersonScreen({
    super.key,
    required this.api,
    required this.personId,
    required this.onBack,
  });

  final SoulApi api;
  final String personId;
  final VoidCallback onBack;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  PersonView? _person;
  bool _failed = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _person = null;
      _failed = false;
    });
    try {
      final person = await widget.api.person(widget.personId);
      if (mounted) setState(() => _person = person);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _edit(String field, String? current) async {
    final given = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SoulColors.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) => _EditSheet(
        question: switch (field) {
          'name' => 'What do you call them?',
          'relation' => 'Who are they to you?',
          _ => 'How would you reach them?',
        },
        hint: switch (field) {
          'name' => 'Their name',
          'relation' => 'A friend at school',
          _ => 'A number, a class, wherever you find them',
        },
        initial: current ?? '',
      ),
    );

    if (given == null || !mounted) return;

    try {
      await widget.api.editPerson(
        widget.personId,
        name: field == 'name' ? given : null,
        relation: field == 'relation' ? given : null,
        reach: field == 'reach' ? given : null,
      );
    } catch (_) {
      // Nothing said. The reload underneath shows what is actually stored.
    }
    if (mounted) await _load();
  }

  Future<void> _forget() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: SoulColors.bg,
        title: Text('Remove ${_person?.name ?? 'them'}?',
            style: SoulType.heading.copyWith(fontSize: 22)),
        content: const Text(
          'Everything the app holds about them goes. What you wrote stays '
          'yours, and stays where it is.',
          style: SoulType.secondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Keep them',
                style: TextStyle(
                    fontFamily: SoulType.sans, color: SoulColors.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Remove',
                style: TextStyle(
                    fontFamily: SoulType.sans, color: SoulColors.clay)),
          ),
        ],
      ),
    );

    if (sure != true || !mounted) return;

    try {
      await widget.api.forgetPerson(widget.personId);
      if (mounted) setState(() => _gone = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = _person;

    if (_gone) {
      return Screen(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        body: [
          _Back(onBack: widget.onBack),
          const SizedBox(height: 40),
          const Text('Removed', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'They are not listed any more. What you wrote is where it was.',
            style: SoulType.secondary,
          ),
        ],
        footer: SoulButton('Done',
            kind: SoulButtonKind.filled, onPressed: widget.onBack),
      );
    }

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      body: [
        _Back(onBack: widget.onBack),
        if (_failed) ...[
          const SizedBox(height: 30),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach this just now.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          SoulButton('Try again', onPressed: _load),
        ] else if (person == null) ...[
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
        ] else ...[
          const SizedBox(height: 8),
          Text(person.name, style: SoulType.heading),
          const SizedBox(height: 6),
          Label(person.mentions == 1
              ? 'came up once'
              : 'came up ${person.mentions} times'),
          const SizedBox(height: 20),
          SoulCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                _Field(
                  label: 'Name',
                  value: person.name,
                  onTap: () => _edit('name', person.name),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Rule(),
                ),
                _Field(
                  label: 'To you',
                  value: person.relation,
                  onTap: () => _edit('relation', person.relation),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Rule(),
                ),
                _Field(
                  label: 'Reaching them',
                  value: person.reach,
                  onTap: () => _edit('reach', person.reach),
                ),
              ],
            ),
          ),
          if (person.profile != null && person.profile!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Inset(
              // Said plainly, because the difference between what the user
              // wrote and what the app wrote about somebody else is the thing
              // they are most owed on this page.
              label: 'what the app made of it',
              body: person.profile!,
            ),
          ],
          const SizedBox(height: 22),
          const Label('where they come up, in your words'),
          const SizedBox(height: 12),
          for (final said in person.said) ...[
            SoulCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(_when(said.at)),
                  const SizedBox(height: 8),
                  Text(said.text, style: SoulType.field),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          SoulButton('Remove them', onPressed: _forget),
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  static String _when(String iso) {
    const months = [
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

    final at = DateTime.tryParse(iso)?.toLocal();
    if (at == null) return '';
    return '${at.day} ${months[at.month - 1]}';
  }
}

class _Back extends StatelessWidget {
  const _Back({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        onPressed: onBack,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.chevron_left, size: 24, color: SoulColors.text3),
      ),
    );
  }
}

/// One editable line. Anything the user sets here is theirs and a later
/// profile run leaves it alone.
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, required this.onTap});

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final given = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            SizedBox(width: 108, child: Label(label)),
            Expanded(
              child: Text(
                given ? value! : 'not said',
                style: given
                    ? SoulType.lead
                    : SoulType.lead.copyWith(color: SoulColors.text3),
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: SoulColors.text3),
          ],
        ),
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({
    required this.question,
    required this.hint,
    required this.initial,
  });

  final String question;
  final String hint;
  final String initial;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
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
          Text(widget.question, style: SoulType.lead),
          const SizedBox(height: 14),
          SoulField(
            controller: _controller,
            hint: widget.hint,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          SoulButton(
            'Save',
            kind: SoulButtonKind.filled,
            onPressed: () =>
                Navigator.of(context).pop(_controller.text.trim()),
          ),
        ],
      ),
    );
  }
}
