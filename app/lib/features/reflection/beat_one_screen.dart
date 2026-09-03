import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import '../capture/speech_field.dart';

/// Screen 5. One line back, under three seconds.
///
/// The line quotes something specific the user just said. If it could be
/// pasted into a different person's entry unchanged, it has failed. There is no
/// question mark on it, because a question demands something and the first line
/// should lower pressure rather than add to it.
class BeatOneScreen extends StatefulWidget {
  const BeatOneScreen({
    super.key,
    required this.transcript,
    required this.line,
    required this.timeOfDay,
    required this.onDone,
    this.spokenSeconds,
    this.underneath,
    this.question,
    this.loadingQuestion = false,
  });

  final String transcript;
  final String line;
  final int? spokenSeconds;
  final String timeOfDay;

  /// The fuller reading, when it has arrived. underneath is one hedged
  /// sentence, question is the one thing to sit with. Both null until the
  /// Mirror answers, and the card shows a thin line while it thinks.
  final String? underneath;
  final String? question;
  final bool loadingQuestion;

  /// Done. answer is yes, no or null, and said is whatever they wrote or
  /// spoke into the box, which may be empty.
  final void Function({bool? answer, required String said}) onDone;

  @override
  State<BeatOneScreen> createState() => _BeatOneScreenState();
}

class _BeatOneScreenState extends State<BeatOneScreen> {
  final _said = TextEditingController();
  bool? _answer;

  @override
  void dispose() {
    _said.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    return Screen(
      body: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Label(
              widget.spokenSeconds == null
                  ? 'in your words'
                  : 'you spoke for ${widget.spokenSeconds} seconds',
            ),
            Label(widget.timeOfDay),
          ],
        ),
        const SizedBox(height: 18),
        Quote(widget.transcript),
        const SizedBox(height: 28),
        Text(
          widget.line,
          style: const TextStyle(
            fontFamily: SoulType.serif,
            fontSize: 21,
            height: 1.35,
            letterSpacing: -0.21,
            color: SoulColors.text,
          ),
        ),
        const SizedBox(height: 28),
        // The question, on the tinted card because it is the thing waiting
        // for them. While it is on its way, a thin line says so and nothing
        // else changes.
        if (widget.loadingQuestion)
          const _ThinkingLine()
        else if (question != null) ...[
          SoulCard(
            background: SoulColors.s2,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Label('one question'),
                const SizedBox(height: 8),
                if (widget.underneath != null) ...[
                  Text(widget.underneath!, style: SoulType.secondary),
                  const SizedBox(height: 10),
                ],
                Text(question, style: SoulType.lead),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Pill('Yes', on: _answer == true, onTap: () => setState(() => _answer = true)),
                    const SizedBox(width: 8),
                    _Pill('No', on: _answer == false, onTap: () => setState(() => _answer = false)),
                  ],
                ),
                const SizedBox(height: 14),
                SpeechField(controller: _said),
              ],
            ),
          ),
        ],
      ],
      footer: SoulButton(
        'Done',
        kind: SoulButtonKind.filled,
        onPressed: () => widget.onDone(answer: _answer, said: _said.text.trim()),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {required this.on, required this.onTap});
  final String text;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: on ? SoulColors.clay : SoulColors.s1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: on ? SoulColors.clay : SoulColors.border2),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: SoulType.sans,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: on ? Colors.white : SoulColors.text,
          ),
        ),
      ),
    );
  }
}

/// A thin line under the reflection while the question is on its way.
class _ThinkingLine extends StatelessWidget {
  const _ThinkingLine();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Label('one question is on its way'),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: const LinearProgressIndicator(
            minHeight: 2,
            color: SoulColors.clay,
            backgroundColor: SoulColors.s3,
          ),
        ),
      ],
    );
  }
}
