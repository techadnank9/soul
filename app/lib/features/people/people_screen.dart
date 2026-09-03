import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'person_screen.dart';

/// The people tab.
///
/// Everybody the user has named, most recently mentioned first. The names
/// are theirs: mum is mum and Mr Hale is Mr Hale, because that is what they
/// called them.
///
/// This tab holds records about people who are not users of this app. What
/// keeps that defensible is on the page behind each row: the user can
/// rename anybody, write their own note about them, and delete them outright.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.api, this.revision = 0});

  final SoulApi api;

  /// Changes when an entry lands, because a new entry can name somebody new.
  final int revision;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<PersonRow>? _people;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PeopleScreen old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision) _load();
  }

  Future<void> _load() async {
    setState(() {
      _people = null;
      _failed = false;
    });
    try {
      final people = await widget.api.people();
      if (mounted) setState(() => _people = people);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(PersonRow person) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => PersonScreen(
          api: widget.api,
          personId: person.id,
          onBack: () => Navigator.of(page).pop(),
        ),
      ),
    );
    // They may have renamed somebody or removed them entirely.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final people = _people;

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      body: [
        const Text('People', style: SoulType.heading),
        const SizedBox(height: 6),
        Label(switch (people) {
          null => 'reading them back',
          [] => 'nobody yet',
          _ => people.length == 1
              ? 'one person you have written about'
              : '${people.length} people you have written about',
        }),
        const SizedBox(height: 18),
        if (_failed) ...[
          const SizedBox(height: 30),
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach this just now. What you wrote is still '
            'there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          SoulButton('Try again', onPressed: _load),
        ] else if (people == null) ...[
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
        ] else if (people.isEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'When you name someone in what you say, they show up here.',
            style: SoulType.secondary,
          ),
        ] else ...[
          for (final person in people) ...[
            SoulCard(
              onTap: () => _open(person),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            fontFamily: SoulType.serif,
                            fontSize: 20,
                            color: SoulColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Label([
                          if (person.relation != null &&
                              person.relation!.isNotEmpty)
                            person.relation!,
                          person.mentions == 1
                              ? 'once'
                              : '${person.mentions} times',
                        ].join(', ')),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 20, color: SoulColors.text3),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 60),
        ],
      ],
    );
  }
}
