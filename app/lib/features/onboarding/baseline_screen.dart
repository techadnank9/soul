import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'baseline.dart';
import 'baseline_answering.dart';

/// The baseline set, asked one question at a time.
///
/// Four colour tiles rather than four stacked rows. A tile presses in when it
/// is chosen, holds for a beat so the choice is felt, then the next question
/// slides in. The bar along the top fills as the set is answered.
///
/// The pleasure here is in the interaction. Nothing on this screen praises the
/// student, congratulates them, or tells them what an answer means, because
/// none of that is ours to say and the clinical guidance is direct about it.
class BaselineScreen extends StatefulWidget {
  const BaselineScreen({
    super.key,
    required this.onFinished,
    required this.onSkip,
  });

  /// Answers, indexed by question, with null for anything skipped.
  final ValueChanged<List<int?>> onFinished;
  final VoidCallback onSkip;

  @override
  State<BaselineScreen> createState() => _BaselineScreenState();
}

class _BaselineScreenState extends State<BaselineScreen> {
  final _answers = List<int?>.filled(baseline.length, null);

  int _index = 0;
  int? _pressed;
  bool _leaving = false;

  BaselineQuestion get _question => baseline[_index];

  /// How to answer this one, when the control is not obvious on sight.
  String? get _hint => switch (_question.style) {
        Answering.orb => 'Move the light toward what fits',
        Answering.scale => 'Drag to where it sits',
        Answering.blank => 'Finish the sentence',
        _ => null,
      };

  Future<void> _choose(int option) async {
    if (_leaving) return;
    setState(() => _pressed = option);
    _answers[_index] = option;

    // Long enough that choosing feels like it landed, short enough that ten
    // questions do not feel like a queue.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;

    setState(() => _leaving = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;

    if (_index == baseline.length - 1) {
      widget.onFinished(_answers);
      return;
    }
    setState(() {
      _index++;
      _pressed = null;
      _leaving = false;
    });
  }

  void _back() {
    if (_index == 0) return;
    setState(() {
      _index--;
      _pressed = _answers[_index];
      _leaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showSection = _index == 0 ||
        baseline[_index - 1].section != _question.section;

    return Scaffold(
      backgroundColor: SoulColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: _index == 0
                        ? null
                        : IconButton(
                            onPressed: _back,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.chevron_left,
                                size: 24, color: SoulColors.text3),
                          ),
                  ),
                  Expanded(child: _Progress(done: _index, of: baseline.length)),
                  const SizedBox(width: 12),
                  Text('${_index + 1} of ${baseline.length}',
                      style: SoulType.muted),
                ],
              ),
              const SizedBox(height: 28),
              AnimatedOpacity(
                opacity: _leaving ? 0 : 1,
                duration: const Duration(milliseconds: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SectionMark(section: _question.section, show: showSection),
                    const SizedBox(height: 30),
                    Text(
                      _question.text,
                      textAlign: TextAlign.center,
                      style: SoulType.heading.copyWith(fontSize: 27),
                    ),
                    if (_hint != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _hint!,
                        textAlign: TextAlign.center,
                        style: SoulType.secondary.copyWith(
                          fontFamily: SoulType.serif,
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                          color: SoulColors.text3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: AnimatedOpacity(
                  opacity: _leaving ? 0 : 1,
                  duration: const Duration(milliseconds: 140),
                  child: KeyedSubtree(
                    key: ValueKey(_index),
                    child: switch (_question.style) {
                      Answering.orb => OrbField(
                          options: _question.options,
                          chosen: _pressed,
                          onChoose: _choose,
                        ),
                      Answering.blank => BlankSentence(
                          lead: _question.lead ?? '',
                          options: _question.options,
                          chosen: _pressed,
                          onChoose: _choose,
                        ),
                      Answering.list => ListChoices(
                          options: _question.options,
                          chosen: _pressed,
                          onChoose: _choose,
                        ),
                      Answering.scale => ScaleChoice(
                          options: _question.options,
                          chosen: _pressed,
                          ends: _question.ends,
                          onChoose: _choose,
                        ),
                      Answering.words => WordChoices(
                          options: _question.options,
                          chosen: _pressed,
                          onChoose: _choose,
                        ),
                    },
                  ),
                ),
              ),
              SoulButton('Skip these',
                  kind: SoulButtonKind.ghost, onPressed: widget.onSkip),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar along the top. One segment per question, filling as they are
/// answered, so ten questions look finite rather than endless.
class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.of});
  final int done;
  final int of;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 4,
              decoration: BoxDecoration(
                color: i <= done ? SoulColors.clay : SoulColors.s3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}


/// The section a question belongs to, as a mark and a name.
///
/// It fades rather than disappearing between questions in the same section, so
/// moving from one part of the set to another is felt without being announced.
class _SectionMark extends StatelessWidget {
  const _SectionMark({required this.section, required this.show});

  final String section;
  final bool show;

  @override
  Widget build(BuildContext context) {
    final mark = sectionMarks[section] ?? (Icons.circle_outlined, SoulColors.clay);

    return AnimatedOpacity(
      opacity: show ? 1 : 0.4,
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: mark.$2, shape: BoxShape.circle),
            child: Icon(mark.$1, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            section.toUpperCase(),
            style: TextStyle(
              fontFamily: SoulType.sans,
              fontSize: 11,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
              color: mark.$2,
            ),
          ),
        ],
      ),
    );
  }
}
