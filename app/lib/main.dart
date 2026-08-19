import 'dart:io';

import 'package:flutter/material.dart';

import 'data/sample.dart';
import 'features/capture/capture_screen.dart';
import 'features/capture/confirm_transcript.dart';
import 'features/day/day_screen.dart';
import 'features/home/home_screen.dart';
import 'features/shell/app_shell.dart';
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

/// A way to open one screen directly, for reviewing them without walking the
/// whole flow. Set SOUL_SCREEN in the environment. Unset, the app starts where
/// a student starts.
///
/// This exists so screens can be looked at side by side during design review.
/// It reads an environment variable rather than a compiled constant so one
/// build can show every screen.
Widget? _requestedScreen() {
  final name = Platform.environment['SOUL_SCREEN'];
  if (name == null || name.isEmpty) return null;

  void nothing() {}

  return switch (name) {
    'consent' => ConsentScreen(onContinue: nothing),
    'question' => QuestionScreen(onAnswered: nothing, onSkip: nothing),
    'capture' => CaptureScreen(onSubmitted: (_) {}, onSkip: nothing),
    'confirm' => ConfirmTranscript(
        transcript: Sample.transcript,
        onSend: nothing,
        onDiscard: nothing,
      ),
    'home_empty' => Home(momentsThisWeek: 0),
    'home' => const Home(),
    'beat_one' => BeatOneScreen(
        transcript: Sample.transcript,
        line: Sample.beatOne,
        spokenSeconds: 41,
        timeOfDay: '6:14 PM',
        onLookCloser: nothing,
        onDone: nothing,
      ),
    'mirror' => MirrorScreen(
        tension: Sample.tension,
        underneath: Sample.underneath,
        question: Sample.question,
        offered: Sample.heldDecision,
        onHold: (_) {},
        onNothingYet: nothing,
      ),
    'day' => DayScreen(day: 'Tuesday', onBack: nothing),
    'outcome' => OutcomeScreen(
        decision: Sample.heldDecision,
        observation: 'That is twice now that saying it directly ended lighter '
            'than holding it.',
        onDone: nothing,
      ),
    'pattern' => PatternPromptScreen(
        when: 'seven weeks later',
        entry: 'My brother talked over my idea at dinner again and I just went '
            'quiet for the rest of the night.',
        proposal: 'This feels close to something you wrote in June, about the '
            'meeting. Both times you had something to say and held it. Does '
            'that connection fit for you?',
        onFits: nothing,
        onNotTheSame: nothing,
        onLater: nothing,
      ),
    'patterns' => const PatternsScreen(reflectionCount: 34),
    _ => null,
  };
}

class SoulApp extends StatelessWidget {
  const SoulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soul',
      debugShowCheckedModeBanner: false,
      theme: soulTheme(),
      home: _requestedScreen() ?? const FirstRun(),
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

  /// Skipping first run lands on home as the mockups show it, with a week of
  /// sample data behind it. The day one empty version is what a real new
  /// account gets, and it is reached by passing zero.
  void _toHome(BuildContext context, {int moments = 12}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => Home(momentsThisWeek: moments)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      0 => ConsentScreen(onContinue: _next),
      1 => QuestionScreen(
          onAnswered: _next,
          onSkip: () => _toHome(context),
        ),
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
  final String _held = Sample.heldDecision;

  @override
  Widget build(BuildContext context) {
    if (_moments > 0) {
      return AppShell(
        momentsThisWeek: _moments,
        onCapture: () => _openCapture(context),
      );
    }
    return HomeScreen(
      momentsThisWeek: _moments,
      heldDecision: _moments == 0 ? null : _held,
      onCapture: () => _openCapture(context),
      onOpenDay: (_) {},
      onOpenPatterns: () {},
      onOutcome: () {},
    );
  }

  void _openCapture(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (capture) => CaptureScreen(
          opener: 'right now',
          prompt: 'What just happened?',
          note: 'Thirty seconds is plenty.',
          // A way out that costs nothing. Opening the app and deciding not to
          // say anything has to be an ordinary thing to do, not a thing you
          // have to back out of.
          onSkip: () => Navigator.of(capture).pop(),
          onSubmitted: (text) => Navigator.of(capture).pushReplacement(
            MaterialPageRoute(
              builder: (session) => Session(
                transcript: text,
                onFinished: () {
                  Navigator.of(session).popUntil((route) => route.isFirst);
                  setState(() => _moments++);
                },
              ),
            ),
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
