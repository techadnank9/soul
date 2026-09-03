import 'package:flutter/material.dart';
import '../../api/client.dart';
import '../../api/models.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// One reflection, and everything behind it.
///
/// The returning tab tells a user to keep doing something or to stop doing
/// it. This is the screen that has to exist for that to be fair: the entries
/// the claim was built from, in their own words, with the dates, and what they
/// decided about it afterwards.
///
/// Nothing here is generated except the one line at the top, which is the same
/// line the list showed. Everything under it is the user's own record.
class ReflectionScreen extends StatefulWidget {
  const ReflectionScreen({
    super.key,
    required this.api,
    required this.theme,
    required this.onBack,
  });

  final SoulApi api;
  final String theme;
  final VoidCallback onBack;

  @override
  State<ReflectionScreen> createState() => _ReflectionScreenState();
}

class _ReflectionScreenState extends State<ReflectionScreen> {
  ReflectionView? _view;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _view = null;
      _failed = false;
    });
    try {
      final view = await widget.api.reflection(widget.theme);
      if (mounted) setState(() => _view = view);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = _view;
    final mark = switch (view?.verdict) {
      'good' => SoulColors.moss,
      'bad' => SoulColors.clay,
      _ => SoulColors.border2,
    };

    return Screen(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      body: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.chevron_left,
                  size: 24, color: SoulColors.text3),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.theme,
                style: SoulType.heading.copyWith(fontSize: 24),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (_failed) ...[
          const Text('Not loaded', style: SoulType.heading),
          const SizedBox(height: 14),
          const Text(
            'The app could not reach this just now. What you wrote is still '
            'there.',
            style: SoulType.secondary,
          ),
          const SizedBox(height: 22),
          SoulButton('Try again', onPressed: _load),
        ] else if (view == null) ...[
          const SizedBox(height: 80),
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
          if (view.line.isNotEmpty)
            SoulCard(
              background: view.verdict == 'good'
                  ? const Color(0xFFF0F4E9)
                  : SoulColors.clayLight,
              borderColor: mark.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration:
                            BoxDecoration(color: mark, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Label(view.verdict == 'good'
                          ? 'worth keeping'
                          : view.verdict == 'bad'
                              ? 'worth stopping'
                              : 'still forming'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(view.line, style: SoulType.lead),
                  const SizedBox(height: 10),
                  // Where the claim came from, said plainly. A user is owed
                  // the difference between what they told the app and what the
                  // app worked out on its own.
                  Label(view.source == 'outcomes'
                      ? 'from how you said it went'
                      : 'from what you have written'),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Label(view.times == 1 ? 'once' : '${view.times} times, newest first'),
          const SizedBox(height: 12),
          for (final entry in view.entries) ...[
            SoulCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Label(_when(entry.date)),
                  const SizedBox(height: 8),
                  Text(entry.text, style: SoulType.field),
                  if (entry.feeling != null) ...[
                    const SizedBox(height: 6),
                    Label(entry.feeling!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (view.decisions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Label('what you decided about it'),
            const SizedBox(height: 12),
            for (final decision in view.decisions) ...[
              SoulCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(decision.chose, style: SoulType.lead),
                    const SizedBox(height: 6),
                    Label(switch (decision.felt) {
                      'lighter' => 'you said it left you lighter',
                      'worse' => 'you said it left you worse',
                      'same' => 'you said it was the same',
                      _ => 'not answered yet',
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 60),
        ],
      ],
    );
  }

  /// The date as a person would say it, from YYYY-MM-DD.
  static String _when(String date) {
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

    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return '${parsed.day} ${months[parsed.month - 1]}';
  }
}
