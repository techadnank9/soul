import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'patterns_screen.dart' show standingWord;

/// One pattern they said fits.
///
/// Their words for it, where they say it stands, the moments it was found
/// in, and a way to take it down. Everything on this screen is theirs to
/// change, which is the point: they are the one who said yes to it, so they
/// are the one who says what it is now. Decision 298.
///
/// The theme is not editable. It is the word the counting and the exclusion
/// run on, and free text there is decision 259 again. What they change is
/// the sentence they read.
class ConfirmedPatternScreen extends StatefulWidget {
  const ConfirmedPatternScreen({
    super.key,
    required this.api,
    required this.pattern,
    required this.onBack,
  });

  final SoulApi api;
  final ConfirmedPattern pattern;
  final VoidCallback onBack;

  @override
  State<ConfirmedPatternScreen> createState() => _ConfirmedPatternScreenState();
}

class _ConfirmedPatternScreenState extends State<ConfirmedPatternScreen> {
  late final _said = TextEditingController(text: widget.pattern.said);
  late String? _standing = widget.pattern.standing;
  List<PatternMoment>? _moments;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _loadMoments();
  }

  @override
  void dispose() {
    _said.dispose();
    super.dispose();
  }

  Future<void> _loadMoments() async {
    try {
      final moments = await widget.api.patternMoments(widget.pattern.id);
      if (mounted) setState(() => _moments = moments);
    } catch (_) {
      if (mounted) setState(() => _moments = const []);
    }
  }

  Future<void> _pickStanding(String standing) async {
    setState(() {
      _standing = standing;
      _working = true;
    });
    try {
      await widget.api.setPatternStanding(widget.pattern.id, standing);
      widget.api.event('pattern_standing_set', {'standing': standing});
    } catch (_) {
      // Left as they tapped it. The next open reads the server again.
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _save() async {
    final said = _said.text.trim();
    if (said.isEmpty || said == widget.pattern.said) return widget.onBack();

    setState(() => _working = true);
    try {
      await widget.api.rewordPattern(widget.pattern.id, said);
      widget.api.event('pattern_reworded');
      widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _takeDown() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: SoulColors.bg,
        title: Text('Take this down?', style: SoulType.lead),
        content: Text(
          'It stops being something I hold about you. The moments behind it '
          'stay yours either way.',
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
              'Take it down',
              style: SoulType.secondary.copyWith(color: SoulColors.clayDark),
            ),
          ),
        ],
      ),
    );

    if (sure != true) return;
    setState(() => _working = true);
    try {
      await widget.api.takeDownPattern(widget.pattern.id);
      widget.api.event('pattern_taken_down');
      widget.onBack();
    } catch (_) {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moments = _moments;

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
        Label(
          widget.pattern.times == 1
              ? 'seen in one moment'
              : 'seen in ${widget.pattern.times} moments',
        ),
        const SizedBox(height: 10),
        SoulField(controller: _said, maxLines: 4),
        const SizedBox(height: 10),
        Text(
          'Here is how I would put it. Change anything that does not sound '
          'like you.',
          style: SoulType.muted,
        ),
        const SizedBox(height: 26),
        const Label('where is it now'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in const [
              ('still_true', 'Still true'),
              ('changing', 'Changing'),
              ('does_not_fit', 'Does not fit any more'),
            ])
              _Choice(
                label: choice.$2,
                on: _standing == choice.$1,
                onTap: _working ? null : () => _pickStanding(choice.$1),
              ),
          ],
        ),
        if (standingWord(_standing) != null) ...[
          const SizedBox(height: 10),
          Text(
            'You said this is ${standingWord(_standing)}. That is what stands, '
            'whatever I would have said.',
            style: SoulType.muted,
          ),
        ],
        const SizedBox(height: 26),
        const Label('the moments behind it'),
        const SizedBox(height: 10),
        if (moments == null)
          Text('Reading.', style: SoulType.muted)
        else if (moments.isEmpty)
          Text('They are not here any more.', style: SoulType.muted)
        else
          for (final moment in moments) ...[
            SoulCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_on(moment.at), style: SoulType.muted),
                  const SizedBox(height: 6),
                  Text(moment.said, style: SoulType.secondary),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 16),
        SoulButton(
          'Take this down',
          kind: SoulButtonKind.ghost,
          onPressed: _working ? null : _takeDown,
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

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.on, this.onTap});

  final String label;
  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? SoulColors.clayLight : Colors.transparent,
          border: Border.all(
            color: on ? SoulColors.clayDark : SoulColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: SoulType.secondary.copyWith(
            color: on ? SoulColors.clayDark : SoulColors.text2,
          ),
        ),
      ),
    );
  }
}
