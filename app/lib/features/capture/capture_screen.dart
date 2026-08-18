import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 3. Voice or text, on the same screen, at the same weight.
///
/// Typing is not a fallback. Recognition on children's voices is materially
/// worse than on adults, and worst for students from non English speaking
/// homes, so the students served least well by the mic are exactly the ones who
/// need the other path to look like a real choice.
///
/// Nothing records yet. The mic gesture is wired to the same place the typed
/// path goes, so the shape of the screen can be judged before task 3.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.onSubmitted,
    this.onSkip,
    this.prompt = 'What is going on with you lately?',
    this.note = 'Anything. A few words is enough.',
    this.opener = 'to begin',
  });

  final ValueChanged<String> onSubmitted;
  final VoidCallback? onSkip;
  final String prompt;
  final String note;
  final String opener;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _controller = TextEditingController();
  bool _holding = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final typing = _controller.text.trim().isNotEmpty;

    return Screen(
      body: [
        Label(widget.opener),
        const SizedBox(height: 14),
        Text(widget.prompt, style: SoulType.heading),
        const SizedBox(height: 14),
        Text(widget.note, style: SoulType.secondary),
        const SizedBox(height: 24),
        SoulField(
          controller: _controller,
          hint: 'Type it here',
        ),
        const SizedBox(height: 32),
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTapDown: (_) => setState(() => _holding = true),
                onTapUp: (_) => setState(() => _holding = false),
                onTapCancel: () => setState(() => _holding = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _holding ? SoulColors.clay : SoulColors.s2,
                    border: Border.all(
                      color: _holding ? SoulColors.clay : SoulColors.border2,
                    ),
                  ),
                  child: Icon(
                    Icons.mic_none,
                    size: 28,
                    color: _holding ? SoulColors.bg : SoulColors.text2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Label('hold to speak'),
            ],
          ),
        ),
      ],
      footer: Column(
        children: [
          if (typing)
            SoulButton('Send', kind: SoulButtonKind.filled, onPressed: _send),
          if (widget.onSkip != null) ...[
            const SizedBox(height: 4),
            SoulButton('Skip for now',
                kind: SoulButtonKind.ghost, onPressed: widget.onSkip),
          ],
        ],
      ),
    );
  }
}
