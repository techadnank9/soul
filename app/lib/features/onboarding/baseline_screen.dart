import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'baseline.dart';
import 'baseline_scenes.dart';

/// One question of the baseline set, answered by a movement.
///
/// Ten questions across five sections, asked once at first run. The purpose
/// is pattern awareness and readiness, not diagnosis and not treatment.
/// Nothing here is scored, nothing is shown back as a result, and no answer
/// produces a label for the user.
///
/// Each question has its own scene, from baseline_scenes.dart, and no two
/// are alike: a light dragged to a corner, an answer sunk in a pond, a wall
/// pushed over. There is no continue on a question being answered for the
/// first time. A scene settles once the person has chosen and the next
/// question follows on its own, the way Nouvel's first onboarding did it,
/// because a button after a movement is a form again.
///
/// A question being seen a second time is different. Its scene is settled
/// and does not take another movement, so coming back to one left nothing
/// to do and no way on. There are two controls under it in that case: one
/// to move on with the answer that is there, and one to take it back, which
/// hands the scene a clean slate and lets it be answered again.
///
/// The section mark is the eyebrow, a dot in the section's colour and its
/// name, so moving from one part of the set to another is seen without
/// being announced. Nothing on this screen praises the user, congratulates
/// them, or tells them what an answer means.
class BaselineQuestionView extends StatefulWidget {
  const BaselineQuestionView({
    super.key,
    required this.index,
    required this.answer,
    required this.onChanged,
    required this.onContinue,
  });

  final int index;

  /// The chosen option, as an index into the question's options, or null.
  final int? answer;
  final ValueChanged<int?> onChanged;
  final VoidCallback onContinue;

  @override
  State<BaselineQuestionView> createState() => _BaselineQuestionViewState();
}

class _BaselineQuestionViewState extends State<BaselineQuestionView> {
  /// Closed for the length of the slide in, so a finger still moving from
  /// the last question cannot answer this one by accident.
  bool _canAnswer = false;
  bool _advancing = false;

  /// Whether the answer was taken back on this visit. It only changes the
  /// key, so the scene is built again with nothing settled in it.
  bool _cleared = false;

  /// Answered before this visit, which is the only case that needs a way
  /// forward that is not a movement.
  late final bool _returning = widget.answer != null;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _canAnswer = true);
    });
  }

  void _select(int option) {
    if (_advancing) return;
    _advancing = true;
    widget.onChanged(option);
    // The scene has already settled by the time it reports. A short hold
    // so the settled state is seen, then on.
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) widget.onContinue();
    });
  }

  /// Takes the answer back and hands the scene a fresh state to be answered
  /// in. The key below changes with it, which is what makes the scene forget
  /// what it had settled on.
  void _change() {
    widget.onChanged(null);
    setState(() => _cleared = true);
  }

  Widget _scene(BaselineQuestion question) {
    final options = question.options;
    final answer = widget.answer;
    return switch (question.style) {
      Answering.orb => FieldScene(options: options, answer: answer, onSelect: _select),
      Answering.list => PondScene(options: options, answer: answer, onSelect: _select),
      Answering.constellation => StonesScene(options: options, answer: answer, onSelect: _select),
      Answering.stack => BeamScene(options: options, answer: answer, onSelect: _select),
      Answering.ripples => WeightScene(options: options, answer: answer, onSelect: _select),
      Answering.deck => DeckScene(options: options, answer: answer, onSelect: _select),
      Answering.scale => SunriseScene(options: options, answer: answer, onSelect: _select),
      Answering.blank => SentenceScene(
          options: options,
          answer: answer,
          onSelect: _select,
          lead: question.lead ?? question.text,
        ),
      Answering.dial => WarmthScene(options: options, answer: answer, onSelect: _select),
      Answering.words => BloomScene(options: options, answer: answer, onSelect: _select, colours: baselineColours),
    };
  }

  @override
  Widget build(BuildContext context) {
    final question = baseline[widget.index];
    final (icon, colour) = sectionMarks[question.section] ?? (Icons.circle, SoulColors.clay);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
                child: Icon(icon, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                question.section.toUpperCase(),
                style: const TextStyle(
                  fontFamily: SoulType.sans,
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w500,
                  color: SoulColors.clayDark,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: Text(
              question.text,
              textAlign: TextAlign.center,
              style: SoulType.heading.copyWith(fontSize: 26, height: 1.2),
            ),
          ),
          const SizedBox(height: 22),
          IgnorePointer(
            ignoring: !_canAnswer || _advancing,
            child: KeyedSubtree(
              key: ValueKey('${widget.index}:$_cleared'),
              child: _scene(question),
            ),
          ),
          const Spacer(),
          // Only on a question that was already answered before this visit.
          // A first answer moves on by itself and a button under it would
          // make the movement into a form.
          if (_returning && !_cleared) ...[
            SoulButton(
              'Continue',
              kind: SoulButtonKind.filled,
              onPressed: _advancing ? null : widget.onContinue,
            ),
            const SizedBox(height: 4),
            SoulButton(
              'Change my answer',
              kind: SoulButtonKind.ghost,
              onPressed: _advancing ? null : _change,
            ),
            const SizedBox(height: 10),
          ],
          Center(
            child: Text(
              '${widget.index + 1} of ${baseline.length}',
              style: SoulType.muted.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
