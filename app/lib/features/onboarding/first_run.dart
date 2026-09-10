import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../api/models.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../capture/capture_screen.dart';
import 'baseline.dart';
import 'baseline_screen.dart';
import 'how_it_works_screen.dart';
import 'intent_screen.dart';
import 'intro_screen.dart';
import 'onboarding_kit.dart';
import 'profile_screen.dart';
import 'ready_screen.dart';
import 'sign_in_screen.dart';

/// First run, once, as one sequence.
///
/// Nineteen screens walked in a line: the welcome, how it works, the four
/// profile questions, the ten baseline questions, the spoken introduction,
/// a landing, then sign in. This widget owns what the screens share, which
/// is the progress bar, the back chevron and the slide from one to the
/// next, so each screen is only its own question.
///
/// The bar counts the fourteen questions and nothing else. The screens
/// before them and after them are not work to get through.
class FirstRun extends StatefulWidget {
  const FirstRun({
    super.key,
    required this.onFinished,
    required this.onSignInAgain,
    this.startAt,
  });

  /// Home, with whatever name was given.
  final ValueChanged<String?> onFinished;


  /// Somebody who has been here before, on another phone or after a log
  /// out. Straight to sign in, no questions.
  final VoidCallback onSignInAgain;

  /// For design review: the name of a step to open on. Null starts where a
  /// person starts.
  final String? startAt;

  @override
  State<FirstRun> createState() => _FirstRunState();
}

enum _Kind { welcome, how, profile, baseline, introduction, ready, signIn, intent }

class _Step {
  const _Step(this.kind, [this.index = 0]);
  final _Kind kind;

  /// Which profile question or which baseline question.
  final int index;

  bool get isQuestion => kind == _Kind.profile || kind == _Kind.baseline;

  /// The screens that draw their own chevron and top edge. The flow's
  /// chrome stays out of their way.
  bool get ownsChrome =>
      kind == _Kind.introduction ||
      kind == _Kind.signIn ||
      kind == _Kind.intent;

  /// The welcome has nothing to go back to, the landing comes after an
  /// introduction that has already been sent, and the first of the two
  /// questions after sign in has an account behind it rather than a screen.
  bool get allowsBack =>
      kind != _Kind.welcome &&
      kind != _Kind.ready &&
      !(kind == _Kind.intent && index == 0);

  String get name => switch (kind) {
        _Kind.welcome => 'intro',
        _Kind.how => 'how',
        _Kind.profile => 'profile',
        _Kind.baseline => 'baseline',
        _Kind.introduction => 'capture',
        _Kind.ready => 'ready',
        _Kind.signIn => 'sign_in',
        _Kind.intent => index == 0 ? 'intent_area' : 'intent_reason',
      };
}

final _steps = <_Step>[
  const _Step(_Kind.welcome),
  const _Step(_Kind.how),
  for (var i = 0; i < ProfileStep.values.length; i++) _Step(_Kind.profile, i),
  for (var i = 0; i < baseline.length; i++) _Step(_Kind.baseline, i),
  const _Step(_Kind.introduction),
  const _Step(_Kind.ready),
  const _Step(_Kind.signIn),
  // After sign in, because they are the first thing asked of somebody who
  // has an account rather than one more thing on the way to one.
  const _Step(_Kind.intent, 0),
  const _Step(_Kind.intent, 1),
];

class _FirstRunState extends State<FirstRun> {
  final _api = SoulApi.fromEnvironment();

  late int _at = _startIndex();
  bool _forward = true;

  Profile _profile = const Profile();
  final _answers = List<int?>.filled(baseline.length, null);

  /// The two questions after sign in. What part of life they came to look
  /// at, and why now.
  String? _intentArea;
  String? _intentReason;

  /// The where question asks the phone once. Coming back to it does not ask
  /// again, because a person who said no should not be asked twice by the
  /// act of tapping back.
  bool _askedDevice = false;

  /// The account this phone writes into, asked for before anything is asked
  /// of the person. Held as a future so the welcome's begin can wait on it,
  /// which is the only wait in first run and is almost always already over.
  /// A phone that is offline gets no account and the posts that follow fail
  /// quietly, which is what they did before too.
  late final Future<void> _account = _ensureAccount();

  _Step get _step => _steps[_at];

  int _startIndex() {
    final name = widget.startAt;
    if (name == null) return 0;
    final found = _steps.indexWhere((s) => s.name == name);
    return found < 0 ? 0 : found;
  }

  Future<void> _ensureAccount() async {
    if (await sessionToken() != null) return;
    try {
      await storeSessionToken(await _api.deviceSession());
      _api.event('account_created');
    } catch (_) {
      // Nothing to tell them yet. Sign in at the end makes another attempt.
    }
  }

  void _next() {
    if (_at >= _steps.length - 1) return;
    setState(() {
      _forward = true;
      _at++;
    });
    // The funnel. First run is fifteen screens long and where it loses
    // people is the one thing worth knowing about it, so every step forward
    // says which screen was reached and how far along it is.
    _api.event('first_run_step', {
      'step': _step.name,
      'at': _at,
      'of': _steps.length,
    });
  }

  void _previous() {
    if (!_step.allowsBack || _at == 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = false;
      _at--;
    });
  }

  /// Sent in the background as the last profile question is left, because
  /// a person should never wait on this, and a profile where nothing was
  /// given is never sent at all.
  void _leaveProfile() {
    if (!_profile.isEmpty) _api.profile(_profile.toJson()).ignore();
    _next();
  }

  /// Nothing is scored and nothing is shown back. The answers are a baseline
  /// for later, not a result for now.
  /// The line the last screen shows, asked for the moment the answers exist.
  ///
  /// A spoken introduction stands between here and that screen, so by the
  /// time it is read the line is already back. It is allowed to fail: the
  /// screen holds room for it and shows the rest either way.
  Future<String>? _welcome;

  void _leaveBaseline() {
    _api.baseline(baselineVersion, _answers).ignore();
    _welcome = _api
        .welcomeLine(
          name: _profile.displayName,
          answers: [
            for (var i = 0; i < baseline.length; i++)
              if (_answers[i] != null)
                (question: baseline[i].text, answer: baseline[i].options[_answers[i]!]),
          ],
        )
        .catchError((Object error) {
      _api.event('welcome_failed', {
        'status': error is SoulApiException ? error.status : null,
      });
      throw error;
    });
    _next();
  }

  /// The introduction is stored, not reflected on, and it always lands on
  /// the next screen.
  ///
  /// Every later entry earns a line back. This one does not: it is how the
  /// app learns who it is talking to, and a person who has just answered
  /// fourteen questions should arrive somewhere rather than be handed one
  /// more screen. Nothing is shown for a flagged introduction either, on
  /// the founder's call. The classifier still runs, blocking, on the
  /// server, and the safety_flags row is still written.
  ///
  /// The one line written back is carried to the landing all the same, as
  /// the first thing on it. It is null for a flagged introduction, a held
  /// one, an empty line and a request that failed, and the landing shows
  /// nothing in its place.
  Future<String?>? _introLine;

  void _submitIntroduction(String text, {required bool spoken, String? toneId}) {
    _introLine = _api.submit(text: text, spoken: spoken, toneId: toneId).then<String?>(
      (result) {
        _api.event('introduction_stored', {
          'state': result.runtimeType.toString(),
          'spoken': spoken,
        });
        return switch (result) {
          Reflected(:final line) when line.isNotEmpty => line,
          _ => null,
        };
      },
      onError: (Object error) {
        _api.event('introduction_failed', {
          'status': error is SoulApiException ? error.status : null,
        });
        return null;
      },
    );
    _next();
  }

  /// First run is over the moment somebody is signed in, not two questions
  /// later.
  ///
  /// The two after this are worth asking and are not worth asking twice. A
  /// phone that dies between here and home lands on home next launch without
  /// them, which is a profile with two empty fields in it. Marking it later
  /// would put that person back at the welcome and ask all fourteen again,
  /// which is the worse of the two.
  Future<void> _signedIn() async {
    await markFirstRunDone();
    if (!mounted) return;
    _next();
  }

  /// Sent in the background as the last question is left, like the profile
  /// answers before them. Nobody waits on an answer that is a baseline for
  /// later rather than a result for now.
  void _toHome() {
    if (_intentArea != null || _intentReason != null) {
      _api
          .profile({
            if (_intentArea != null) 'intentArea': _intentArea,
            if (_intentReason != null) 'intentReason': _intentReason,
          })
          .ignore();
    }
    widget.onFinished(_profile.displayName);
  }

  Widget _content() {
    final step = _step;
    return switch (step.kind) {
      _Kind.welcome => IntroScreen(
          onContinue: () async {
            await _account;
            _next();
          },
          onSignIn: widget.onSignInAgain,
        ),
      _Kind.how => HowItWorksScreen(onContinue: _next),
      _Kind.profile => ProfileQuestion(
          step: ProfileStep.values[step.index],
          profile: _profile,
          onChanged: (profile) => setState(() => _profile = profile),
          onContinue: step.index == ProfileStep.values.length - 1
              ? _leaveProfile
              : _next,
          askDeviceForLocation: !_askedDevice,
          onAskedDevice: () => _askedDevice = true,
        ),
      _Kind.baseline => BaselineQuestionView(
          index: step.index,
          answer: _answers[step.index],
          onChanged: (answer) => setState(() => _answers[step.index] = answer),
          onContinue:
              step.index == baseline.length - 1 ? _leaveBaseline : _next,
        ),
      // The first real pass through the loop. Everything before this was
      // answered by tapping. This is the first time a person says something
      // in their own words, and it goes the whole way: consent gate, safety
      // classifier, then a generated line that names something only they
      // said. It is also the only honest way to show what the product is,
      // because describing the loop is not the same as feeling it.
      _Kind.introduction => CaptureScreen(
          onBack: _previous,
          opener: 'last one',
          prompt: 'Tell us about yourself.',
          note: 'Speak or type. What you are like, what you spend your time '
              'on, what is on your mind lately.',
          onSubmitted: (text, {required spoken, toneId}) =>
              _submitIntroduction(text, spoken: spoken, toneId: toneId),
        ),
      _Kind.ready => ReadyScreen(
          profile: _profile,
          line: _welcome,
          introLine: _introLine,
          onContinue: _next,
        ),
      // Last. Signing in comes after there is something to keep, not before
      // the person has seen what this is.
      // No way out at the end of first run. There is nothing behind this
      // screen to close back to, and the way past it is to sign in. The
      // close button belongs to the other way in, from the first screen,
      // where there is something to go back to.
      _Kind.signIn => SignInScreen(onSignedIn: _signedIn),
      // The two after sign in. The first has an account behind it rather
      // than a screen, so it has no way back.
      _Kind.intent => IntentQuestion(
          step: IntentStep.values[step.index],
          chosen: step.index == 0 ? _intentArea : _intentReason,
          onChoose: (key) => setState(() {
            if (step.index == 0) {
              _intentArea = key;
            } else {
              _intentReason = key;
            }
          }),
          onContinue: step.index == 0 ? _next : _toHome,
          onBack: step.index == 0 ? null : _previous,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = _step;
    final questions = _steps.where((s) => s.isQuestion).length;
    final answered = _steps.take(_at).where((s) => s.isQuestion).length;

    return Scaffold(
      backgroundColor: SoulColors.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            if (!step.ownsChrome)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 22, 0),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: step.allowsBack
                            ? IconButton(
                                onPressed: _previous,
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_left,
                                    size: 24, color: SoulColors.text2),
                              )
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: AnimatedOpacity(
                          opacity: step.isQuestion ? 1 : 0,
                          duration: const Duration(milliseconds: 240),
                          child: StepProgress(
                              done: answered, of: questions),
                        ),
                      ),
                      const SizedBox(width: 46),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: StepSwitcher(
                stepKey: _at,
                forward: _forward,
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
