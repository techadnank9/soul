import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 6. The Mirror, only if asked.
///
/// Three parts, all phrased so they can be rejected: what may be pulling
/// against itself, what might sit underneath, and one question. Then the
/// decision field.
///
/// The keyboard is handled by hand rather than by resizing the scaffold.
/// Resizing shrinks the card and reflows the reflection while the user is
/// still reading it.
class MirrorScreen extends StatefulWidget {
  const MirrorScreen({
    super.key,
    required this.tension,
    required this.underneath,
    required this.question,
    required this.offered,
    required this.onHold,
    required this.onNothingYet,
  });

  final String tension;
  final String underneath;
  final String question;

  /// What the Mirror suggested. Stored separately from what the user writes,
  /// because the gap between the two is the most interesting data in the system.
  final String offered;

  final ValueChanged<String> onHold;
  final VoidCallback onNothingYet;

  @override
  State<MirrorScreen> createState() => _MirrorScreenState();
}

class _MirrorScreenState extends State<MirrorScreen> {
  late final _controller = TextEditingController(text: widget.offered);
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const Label('what may be pulling against itself'),
        const SizedBox(height: 6),
        Text(widget.tension, style: SoulType.lead),
        const SizedBox(height: 18),
        const Label('what might sit underneath'),
        const SizedBox(height: 6),
        Text(widget.underneath, style: SoulType.lead),
        const SizedBox(height: 18),
        Inset(label: 'one question', body: widget.question),
        const SizedBox(height: 18),
        const Rule(),
        const SizedBox(height: 18),
        const Text(
          'Is there something you might do about this?',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 10),
        SoulField(
          controller: _controller,
          focusNode: _focus,
          hint: 'What you might do',
        ),
        const SizedBox(height: 14),
        ButtonRow(
          children: [
            SoulButton(
              'Hold it',
              kind: SoulButtonKind.filled,
              onPressed: () {
                _focus.unfocus();
                widget.onHold(_controller.text.trim());
              },
            ),
            SoulButton(
              'Nothing yet',
              onPressed: () {
                _focus.unfocus();
                widget.onNothingYet();
              },
            ),
          ],
        ),
      ],
    );
  }
}
