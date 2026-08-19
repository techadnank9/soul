import 'dart:io';

import 'package:flutter/material.dart';

import 'api/client.dart';
import 'api/models.dart' as api;

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
import 'theme/widgets.dart';

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

/// One pass through the loop, against the API.
///
/// Screens 5, 6 and the pattern question. Nothing here is sample text any
/// more. The line a student reads is generated, the safety classifier has
/// already run before it arrives, and a blocked entry never reaches this
/// screen at all.
class Session extends StatefulWidget {
  const Session({
    super.key,
    required this.transcript,
    required this.onFinished,
    this.spoken = false,
  });

  final String transcript;
  final VoidCallback onFinished;

  /// Whether this came from the mic. The confirm step exists because
  /// transcription can be wrong, and recognition on children's voices is
  /// weakest of all. A student who typed their own words has nothing to
  /// confirm, and asking them to is friction that says we were not listening.
  final bool spoken;

  @override
  State<Session> createState() => _SessionState();
}

enum _Beat { confirm, waiting, one, mirror, help, failed }

class _SessionState extends State<Session> {
  final _api = SoulApi.fromEnvironment();

  late _Beat _beat = widget.spoken ? _Beat.confirm : _Beat.waiting;

  String? _entryId;
  String? _line;
  api.HelpNeeded? _help;
  api.MirrorResult? _mirror;
  bool _loadingMirror = false;

  @override
  void initState() {
    super.initState();
    if (!widget.spoken) _submit();
  }

  Future<void> _submit() async {
    setState(() => _beat = _Beat.waiting);
    try {
      final result = await _api.submit(
        text: widget.transcript,
        spoken: widget.spoken,
      );
      if (!mounted) return;

      switch (result) {
        case api.Reflected(:final entryId, :final line):
          setState(() {
            _entryId = entryId;
            _line = line;
            _beat = _Beat.one;
          });
        case api.HelpNeeded help:
          setState(() {
            _help = help;
            _beat = _Beat.help;
          });
        case api.Held():
          // Stored, nothing sent. The student is told plainly rather than
          // shown a reflection that was never generated.
          setState(() => _beat = _Beat.failed);
      }
    } catch (_) {
      if (mounted) setState(() => _beat = _Beat.failed);
    }
  }

  Future<void> _lookCloser() async {
    setState(() => _loadingMirror = true);
    try {
      final mirror = await _api.mirror(_entryId!);
      if (!mounted) return;
      setState(() {
        _mirror = mirror;
        _loadingMirror = false;
        _beat = _Beat.mirror;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMirror = false);
    }
  }

  Future<void> _hold(String chosen) async {
    if (chosen.isNotEmpty && _entryId != null) {
      try {
        await _api.hold(
          entryId: _entryId!,
          chosen: chosen,
          offered: _mirror?.offered,
        );
      } catch (_) {
        // The decision is the student's, not ours. Losing it to a dropped
        // connection is bad, and blocking them behind an error is worse.
      }
    }
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_beat) {
      _Beat.confirm => ConfirmTranscript(
          transcript: widget.transcript,
          onSend: _submit,
          onDiscard: () => Navigator.of(context).pop(),
        ),
      _Beat.waiting => const _Waiting(note: 'reading what you said'),
      _Beat.one => BeatOneScreen(
          transcript: widget.transcript,
          line: _line!,
          spokenSeconds: widget.spoken ? 41 : null,
          timeOfDay: TimeOfDay.now().format(context),
          loadingCloser: _loadingMirror,
          onLookCloser: _lookCloser,
          onDone: widget.onFinished,
        ),
      _Beat.mirror => MirrorScreen(
          tension: _mirror!.tension,
          underneath: _mirror!.underneath,
          question: _mirror!.question,
          offered: _mirror!.offered ?? '',
          onHold: _hold,
          onNothingYet: widget.onFinished,
        ),
      _Beat.help => HelpScreen(help: _help!, onDone: widget.onFinished),
      _Beat.failed => _Failed(onDone: widget.onFinished),
    };
  }
}

/// While the models are working. It says what is happening rather than
/// spinning at nothing.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.note});
  final String note;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const SizedBox(height: 120),
        Center(
          child: Column(
            children: [
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SoulColors.clay,
                ),
              ),
              const SizedBox(height: 18),
              Label(note),
            ],
          ),
        ),
      ],
    );
  }
}

/// The entry was saved and nothing else happened. Said plainly.
class _Failed extends StatelessWidget {
  const _Failed({required this.onDone});
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: const [
        Text('That is saved', style: SoulType.heading),
        SizedBox(height: 14),
        Text(
          'We could not read it back to you just now. What you wrote is kept '
          'and nothing is lost.',
          style: SoulType.secondary,
        ),
      ],
      footer: SoulButton('Done',
          kind: SoulButtonKind.filled, onPressed: onDone),
    );
  }
}

/// What a blocked entry shows. The wording comes from the server, so it can be
/// changed without a store release.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key, required this.help, required this.onDone});

  final api.HelpNeeded help;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        Text(help.heading, style: SoulType.heading),
        const SizedBox(height: 16),
        Text(help.body, style: SoulType.lead),
        const SizedBox(height: 24),
        for (final contact in help.contacts) ...[
          SoulCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.label,
                  style: SoulType.lead.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(contact.detail, style: SoulType.secondary),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
      footer: SoulButton('Done',
          kind: SoulButtonKind.filled, onPressed: onDone),
    );
  }
}
