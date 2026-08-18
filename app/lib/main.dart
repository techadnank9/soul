import 'package:flutter/material.dart';

import 'data/sample.dart';
import 'features/capture/capture_screen.dart';
import 'features/capture/confirm_transcript.dart';
import 'features/day/day_screen.dart';
import 'features/home/home_screen.dart';
import 'features/mirror/mirror_screen.dart';
import 'features/onboarding/consent_screen.dart';
import 'features/onboarding/question_screen.dart';
import 'features/outcome/outcome_screen.dart';
import 'features/patterns/pattern_prompt_screen.dart';
import 'features/patterns/patterns_screen.dart';
import 'features/reflection/beat_one_screen.dart';
import 'theme/soul_theme.dart';

/// The client shell.
///
/// Every screen in docs/screens.html, walkable in flow order, on local state
/// and fixed sample content. There is no network here and nothing is stored.
/// The reflections are sample strings, not generated, which is why this shell
/// cannot tell anyone whether beat one is any good. That is task 7, and it
/// needs the API.
void main() => runApp(const SoulApp());

class SoulApp extends StatelessWidget {
  const SoulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soul',
      debugShowCheckedModeBanner: false,
      theme: soulTheme(),
      home: const FirstRun(),
    );
  }
}

/// Screens 1 to 3, once.
class FirstRun extends StatefulWidget {
  const FirstRun({super.key});

  @override
  State<FirstRun> createState() => _FirstRunState();
}

class _FirstRunState extends State<FirstRun> {
  int _step = 0;

  void _next() => setState(() => _step++);

  void _toHome(BuildContext context, {int moments = 0}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => Home(momentsThisWeek: moments)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => ConsentScreen(onContinue: _next),
      1 => QuestionScreen(onAnswered: _next),
      _ => CaptureScreen(
          onSkip: () => _toHome(context),
          onSubmitted: (text) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Session(
                transcript: text,
                onFinished: () => _toHome(context, moments: 1),
              ),
            ),
          ),
        ),
    };
  }
}

/// Screen 4 and everything reached from it.
class Home extends StatefulWidget {
  const Home({super.key, this.momentsThisWeek = 12});
  final int momentsThisWeek;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late int _moments = widget.momentsThisWeek;
  String? _held = Sample.heldDecision;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      momentsThisWeek: _moments,
      heldDecision: _moments == 0 ? null : _held,
      onCapture: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CaptureScreen(
            opener: 'right now',
            prompt: 'What just happened?',
            note: 'Thirty seconds is plenty.',
            onSubmitted: (text) => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => Session(
                  transcript: text,
                  onFinished: () {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    setState(() => _moments++);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      onOpenDay: (day) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DayScreen(
            day: day,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      onOpenPatterns: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PatternsScreen(reflectionCount: 34),
        ),
      ),
      onOutcome: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => OutcomeScreen(
            decision: _held ?? Sample.heldDecision,
            observation: 'That is twice now that saying it directly ended '
                'lighter than holding it.',
            onDone: () {
              Navigator.of(context).pop();
              setState(() => _held = null);
            },
          ),
        ),
      ),
    );
  }
}

/// One pass through the loop. Screens 5, 6, and the pattern question.
class Session extends StatefulWidget {
  const Session({
    super.key,
    required this.transcript,
    required this.onFinished,
  });

  final String transcript;
  final VoidCallback onFinished;

  @override
  State<Session> createState() => _SessionState();
}

enum _Beat { confirm, one, mirror, pattern }

class _SessionState extends State<Session> {
  _Beat _beat = _Beat.confirm;

  @override
  Widget build(BuildContext context) {
    return switch (_beat) {
      _Beat.confirm => ConfirmTranscript(
          transcript: widget.transcript,
          onSend: () => setState(() => _beat = _Beat.one),
          onDiscard: () => Navigator.of(context).pop(),
        ),
      _Beat.one => BeatOneScreen(
          transcript: widget.transcript,
          line: Sample.beatOne,
          spokenSeconds: 41,
          timeOfDay: '6:14 PM',
          onLookCloser: () => setState(() => _beat = _Beat.mirror),
          onDone: widget.onFinished,
        ),
      _Beat.mirror => MirrorScreen(
          tension: Sample.tension,
          underneath: Sample.underneath,
          question: Sample.question,
          offered: Sample.heldDecision,
          onHold: (_) => setState(() => _beat = _Beat.pattern),
          onNothingYet: widget.onFinished,
        ),
      _Beat.pattern => PatternPromptScreen(
          when: 'seven weeks later',
          entry: 'My brother talked over my idea at dinner again and I just '
              'went quiet for the rest of the night.',
          proposal: 'This feels close to something you wrote in June, about '
              'the meeting. Both times you had something to say and held it. '
              'Does that connection fit for you?',
          onFits: widget.onFinished,
          onNotTheSame: widget.onFinished,
          onLater: widget.onFinished,
        ),
    };
  }
}
