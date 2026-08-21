import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 8. How it went, days later.
///
/// Neutral wording. The outcome is stored either way, including when the
/// student ignores the check back, because an ignore is an answer too.
class OutcomeScreen extends StatefulWidget {
  const OutcomeScreen({
    super.key,
    required this.decision,
    required this.onDone,
    this.observation,
  });

  final String decision;
  final String? observation;

  /// What happened in their words, and how it left them. Either can be null:
  /// a student who opens this and says nothing has still answered, and the
  /// outcome is stored either way.
  final void Function(String? happened, String? felt) onDone;

  @override
  State<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends State<OutcomeScreen> {
  final _controller = TextEditingController();
  String? _felt;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const Label('you were holding this'),
        const SizedBox(height: 6),
        Text(
          widget.decision,
          style: const TextStyle(
            fontFamily: SoulType.serif,
            fontSize: 18,
            height: 1.35,
            color: SoulColors.text2,
          ),
        ),
        const SizedBox(height: 24),
        const Rule(),
        const SizedBox(height: 18),
        // Not "you did it". The wording is neutral on purpose: a student who
        // did not do it has still answered, and a question that assumes they
        // did turns the check back into a test they can fail.
        const Text('What happened?', style: SoulType.lead),
        const SizedBox(height: 14),
        SoulField(
          controller: _controller,
          hint: 'Whatever happened, or did not',
        ),
        const SizedBox(height: 24),
        const Text('And afterwards?', style: SoulType.lead),
        const SizedBox(height: 14),
        ButtonRow(
          children: [
            for (final option in ['Lighter', 'Same', 'Worse'])
              SoulButton(
                option,
                kind: _felt == option
                    ? SoulButtonKind.filled
                    : SoulButtonKind.outline,
                onPressed: () => setState(() => _felt = option),
              ),
          ],
        ),
        if (widget.observation != null) ...[
          const SizedBox(height: 24),
          Inset(body: widget.observation!),
        ],
      ],
      footer: SoulButton(
        'Done',
        kind: SoulButtonKind.filled,
        onPressed: () => widget.onDone(
          _controller.text.trim().isEmpty ? null : _controller.text.trim(),
          _felt?.toLowerCase(),
        ),
      ),
    );
  }
}
