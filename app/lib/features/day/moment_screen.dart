import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// One moment, opened.
///
/// The day shows a card with the first of it. This is the whole of what they
/// wrote, theirs to change and theirs to take back. Decision 300.
///
/// Changing the words is not cosmetic. Everything read out of a moment is
/// read again from the new ones, so a name taken out here stops being in the
/// tags and stops being in the vector that finds this entry months later.
class MomentScreen extends StatefulWidget {
  const MomentScreen({
    super.key,
    required this.api,
    required this.entry,
    required this.onBack,
    required this.onChanged,
  });

  final SoulApi api;
  final DayEntry entry;
  final VoidCallback onBack;

  /// Called after a change lands, so the day reads itself again.
  final VoidCallback onChanged;

  @override
  State<MomentScreen> createState() => _MomentScreenState();
}

class _MomentScreenState extends State<MomentScreen> {
  late final _said = TextEditingController(text: widget.entry.text);
  bool _working = false;
  bool _touched = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    _said.addListener(() {
      if (!_touched) setState(() => _touched = true);
    });
  }

  @override
  void dispose() {
    _said.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final said = _said.text.trim();
    if (said.isEmpty) {
      setState(() => _note = 'A moment cannot be emptied. Delete it instead.');
      return;
    }
    if (said == widget.entry.text.trim()) return widget.onBack();

    setState(() {
      _working = true;
      _note = null;
    });
    try {
      await widget.api.rewordEntry(widget.entry.id, said);
      widget.api.event('entry_reworded');
      widget.onChanged();
      widget.onBack();
    } catch (error) {
      widget.api.event('entry_reword_failed', {
        'error': error.runtimeType.toString(),
        'status': error is SoulApiException ? error.status : null,
      });
      if (mounted) {
        setState(() {
          _working = false;
          _note = 'That did not save. Try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: SoulColors.bg,
        title: Text('Delete this moment?', style: SoulType.lead),
        content: Text(
          'The moment goes, and so does anything I only knew because of it. '
          'This cannot be undone.',
          style: SoulType.secondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text('Keep it', style: SoulType.secondary),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(
              'Delete it',
              style: SoulType.secondary.copyWith(color: SoulColors.clayDark),
            ),
          ),
        ],
      ),
    );

    if (sure != true) return;

    setState(() => _working = true);
    try {
      await widget.api.forgetEntry(widget.entry.id);
      widget.api.event('entry_forgotten');
    } catch (error) {
      widget.api.event('entry_forget_failed', {
        'error': error.runtimeType.toString(),
        'status': error is SoulApiException ? error.status : null,
      });
    }
    widget.onChanged();
    widget.onBack();
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
        const Label('what you wrote'),
        const SizedBox(height: 10),
        SoulField(controller: _said, maxLines: null),
        if (widget.entry.feeling != null) ...[
          const SizedBox(height: 14),
          Label(widget.entry.feeling!),
        ],
        const SizedBox(height: 10),
        Text(
          'These are your words. Change them and I will read this moment '
          'again from the new ones.',
          style: SoulType.muted,
        ),
        if (_note != null) ...[
          const SizedBox(height: 10),
          Text(_note!, style: SoulType.secondary),
        ],
        const SizedBox(height: 30),
        SoulButton(
          'Delete this moment',
          kind: SoulButtonKind.ghost,
          onPressed: _working ? null : _delete,
        ),
      ],
      footer: SoulButton(
        _touched ? 'Save it this way' : 'Done',
        kind: SoulButtonKind.filled,
        onPressed: _working ? null : (_touched ? _save : widget.onBack),
      ),
    );
  }
}
