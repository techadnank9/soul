import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Everything the app holds about somebody, open, in one place.
///
/// The product says every claim traces back to a moment the person can see
/// and delete. This is where they see it. Each line is a fact in their own
/// register, the moments it was read out of are under it, and both can go.
///
/// Nothing here is a summary of them. A line they would not say is a line
/// they can rewrite, and the app then says it their way from then on,
/// because what this holds is only worth holding if it is true to them.
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key, required this.api, required this.onBack});

  final SoulApi api;
  final VoidCallback onBack;

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  List<HeldFact>? _facts;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final facts = await widget.api.memory();
      if (!mounted) return;
      setState(() {
        _facts = facts;
        _failed = false;
      });
    } catch (error) {
      widget.api.event('memory_failed', {
        'error': error.runtimeType.toString(),
        'status': error is SoulApiException ? error.status : null,
      });
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _open(HeldFact fact) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (page) => _FactScreen(
          api: widget.api,
          fact: fact,
          onBack: () => Navigator.of(page).pop(),
        ),
      ),
    );
    // Whatever they did in there, the list is read again rather than patched
    // by hand. Deleting one moment can retire a fact that is not the one
    // they opened, and a list that quietly disagrees with the server is
    // worse than a second read.
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final facts = _facts;

    return Screen(
      body: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBack,
          child: const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Label('back'),
          ),
        ),
        Text('What I hold', style: SoulType.heading),
        const SizedBox(height: 10),
        Text(
          'Read out of what you wrote. Change the wording of any of it, or '
          'take it away.',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 22),
        if (_failed)
          Text('That did not load. Go back and open it again.',
              style: SoulType.secondary)
        else if (facts == null)
          Text('Reading.', style: SoulType.muted)
        else if (facts.isEmpty)
          Text(
            'Nothing yet. This fills from what you write, a line at a time.',
            style: SoulType.secondary,
          )
        else
          for (final fact in facts) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _open(fact),
              child: SoulCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fact.sentence, style: SoulType.lead),
                    const SizedBox(height: 8),
                    Text(
                      fact.moments.length == 1
                          ? 'from one moment'
                          : 'from ${fact.moments.length} moments',
                      style: SoulType.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

/// One fact, its words, and the moments it came from.
class _FactScreen extends StatefulWidget {
  const _FactScreen({
    required this.api,
    required this.fact,
    required this.onBack,
  });

  final SoulApi api;
  final HeldFact fact;
  final VoidCallback onBack;

  @override
  State<_FactScreen> createState() => _FactScreenState();
}

class _FactScreenState extends State<_FactScreen> {
  late final _said = TextEditingController(text: widget.fact.sentence);
  late List<PatternMoment> _moments = widget.fact.moments;
  bool _working = false;
  bool _gone = false;

  @override
  void dispose() {
    _said.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final said = _said.text.trim();
    if (said.isEmpty || said == widget.fact.sentence) return widget.onBack();

    setState(() => _working = true);
    try {
      await widget.api.rewordFact(widget.fact.id, said);
      widget.api.event('fact_reworded');
      widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _drop() async {
    if (!await _sure(
      'Take this away?',
      'It stops being something I hold about you. What you wrote stays '
          'yours either way.',
      'Take it away',
    )) {
      return;
    }

    setState(() => _working = true);
    try {
      await widget.api.dropFact(widget.fact.id);
      widget.api.event('fact_dropped');
      widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _forget(PatternMoment moment) async {
    if (!await _sure(
      'Delete this moment?',
      'The moment goes, and so does anything I only knew because of it. '
          'This cannot be undone.',
      'Delete it',
    )) {
      return;
    }

    setState(() => _working = true);
    try {
      await widget.api.forgetEntry(moment.entryId);
      widget.api.event('entry_forgotten');
      if (!mounted) return;
      final left = [..._moments]..removeWhere((m) => m.entryId == moment.entryId);
      setState(() {
        _moments = left;
        _working = false;
        // The fact stood on that moment alone, so the server has retired it
        // and there is nothing left on this screen to be about.
        _gone = left.isEmpty;
      });
      if (_gone) widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _sure(String title, String body, String yes) async {
    final said = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: SoulColors.bg,
        title: Text(title, style: SoulType.lead),
        content: Text(body, style: SoulType.secondary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Keep it', style: SoulType.secondary),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(yes,
                style: SoulType.secondary.copyWith(color: SoulColors.clayDark)),
          ),
        ],
      ),
    );
    return said ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBack,
          child: const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Label('back'),
          ),
        ),
        const Label('how I would say it'),
        const SizedBox(height: 8),
        SoulField(controller: _said, maxLines: 4),
        const SizedBox(height: 10),
        Text(
          'Change anything that does not sound like you. I will say it your '
          'way from now on.',
          style: SoulType.muted,
        ),
        const SizedBox(height: 26),
        const Label('where it came from'),
        const SizedBox(height: 10),
        for (final moment in _moments) ...[
          SoulCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_on(moment.at), style: SoulType.muted),
                const SizedBox(height: 6),
                Text(moment.said, style: SoulType.secondary),
                const SizedBox(height: 12),
                SoulButton(
                  'Delete this moment',
                  kind: SoulButtonKind.ghost,
                  onPressed: _working ? null : () => _forget(moment),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 10),
        SoulButton(
          'Take this away',
          kind: SoulButtonKind.ghost,
          onPressed: _working ? null : _drop,
        ),
      ],
      footer: SoulButton(
        'Save it this way',
        kind: SoulButtonKind.filled,
        onPressed: _working ? null : _save,
      ),
    );
  }

  static String _on(DateTime at) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${at.day} ${months[at.month - 1]}';
  }
}
