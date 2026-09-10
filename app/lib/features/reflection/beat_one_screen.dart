import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    this.fallback = false,
    this.proposal,
    this.onPatternAnswer,
    this.onTouched,
    this.onLookAgain,
  });

  final String transcript;
  final String line;
  final int? spokenSeconds;
  final String timeOfDay;

  /// The fuller reading, when it has arrived. underneath is one hedged
  /// sentence, question is the one thing to sit with. Both null until the
  /// Mirror answers, and the card shows a thin line while it thinks. A
  /// question can arrive with nothing underneath it when the reading did
  /// not come in time.
  final String? underneath;
  final String? question;
  final bool loadingQuestion;

  /// The question shown is the one asked when the reading did not arrive,
  /// rather than one written for this entry.
  final bool fallback;

  /// A pattern the reading brought back, in words, when this came up
  /// before. Null when nothing did.
  final String? proposal;

  /// The answer to the proposal, as the server names it: fits or
  /// not_the_same.
  final ValueChanged<String>? onPatternAnswer;

  /// The first time a pill is tapped or a word is typed. After this a late
  /// reading must not replace what is on the card.
  final VoidCallback? onTouched;

  /// One more try at the reading, offered under a fallback question and
  /// withdrawn once it has been taken.
  final VoidCallback? onLookAgain;

  /// Done. answer is yes, no or null, and said is whatever they wrote or
  /// spoke into the box, which may be empty.
  final void Function({bool? answer, required String said}) onDone;

  @override
  State<BeatOneScreen> createState() => _BeatOneScreenState();
}

class _BeatOneScreenState extends State<BeatOneScreen> {
  final _said = TextEditingController();
  bool? _answer;

  /// Whether the person has been told the pattern arrived. Once, whichever
  /// way it lands.
  bool _nudged = false;

  /// Whether the proposal has been answered, so the pills can go.
  bool _patternAnswered = false;

  bool _touched = false;

  @override
  void initState() {
    super.initState();
    _said.addListener(_onTyped);
    _nudgeIfPattern();
  }

  @override
  void didUpdateWidget(BeatOneScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question == null && widget.question != null) {
      _nudgeIfPattern();
    }
  }

  @override
  void dispose() {
    _said.removeListener(_onTyped);
    _said.dispose();
    super.dispose();
  }

  void _nudgeIfPattern() {
    if (_nudged || widget.question == null || widget.proposal == null) return;
    _nudged = true;
    HapticFeedback.lightImpact();
  }

  void _onTyped() {
    if (_said.text.isNotEmpty) _touch();
  }

  void _touch() {
    if (_touched) return;
    _touched = true;
    widget.onTouched?.call();
  }

  void _pick(bool answer) {
    _touch();
    setState(() => _answer = answer);
  }

  void _answerPattern(String answer) {
    setState(() => _patternAnswered = true);
    widget.onPatternAnswer?.call(answer);
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final proposal = widget.proposal;
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
        // else changes. Once there is a question the card stays, whatever
        // else is still being looked for.
        if (question == null && widget.loadingQuestion)
          const _ThinkingLine()
        else if (question != null) ...[
          SoulCard(
            background: SoulColors.s2,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (proposal != null) ...[
                  Label(_patternAnswered ? 'noted' : 'this came up before'),
                  const SizedBox(height: 8),
                  Text(
                    proposal,
                    style: SoulType.lead.copyWith(color: SoulColors.clayDark),
                  ),
                  if (!_patternAnswered) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _Pill('It fits',
                            on: false,
                            onTap: () => _answerPattern('fits')),
                        const SizedBox(width: 8),
                        _Pill('Not the same',
                            on: false,
                            onTap: () => _answerPattern('not_the_same')),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                ],
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
                    _Pill('Yes', on: _answer == true, onTap: () => _pick(true)),
                    const SizedBox(width: 8),
                    _Pill('No', on: _answer == false, onTap: () => _pick(false)),
                  ],
                ),
                const SizedBox(height: 14),
                SpeechField(controller: _said),
              ],
            ),
          ),
          if (widget.fallback && widget.onLookAgain != null) ...[
            const SizedBox(height: 8),
            SoulButton(
              'Look closer again',
              kind: SoulButtonKind.ghost,
              onPressed: widget.onLookAgain,
            ),
          ],
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
