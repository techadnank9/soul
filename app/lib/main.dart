import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'api/client.dart';
import 'api/models.dart' as api;

import 'data/session_store.dart';
import 'features/capture/capture_screen.dart';
import 'features/capture/confirm_transcript.dart';
import 'features/day/day_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/mirror/mirror_screen.dart';
import 'features/onboarding/baseline.dart';
import 'features/onboarding/baseline_screen.dart';
import 'features/onboarding/intro_screen.dart';
import 'features/onboarding/profile_screen.dart';
import 'features/onboarding/sign_in_screen.dart';
import 'features/patterns/patterns_screen.dart';
import 'features/reflection/beat_one_screen.dart';
import 'theme/soul_theme.dart';
import 'theme/widgets.dart';

/// The client shell.
///
/// Every screen in docs/screens.html, walkable in flow order. The one thing
/// kept on the device is the session token, and its whole job is to answer the
/// question this file asks first: whether this user has been here before.
///
/// Nothing on any screen is written here any more. The line a user reads is
/// generated, and the week, the day and the patterns are read back from the
/// server, so what is on screen is this user's own life or it is an empty
/// state saying so.
/// Where crashes and errors are reported. An address, not a secret, and
/// empty means nothing is reported and nothing else changes. Set at build
/// time with SENTRY_DSN or pasted here once the project exists.
const _sentryDsn = String.fromEnvironment(
  'SENTRY_DSN',
  defaultValue:
      'https://a2473c98efd8c05fbb8570017b1a669b@o4512024433393664.ingest.us.sentry.io/4512024454430720',
);

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    runApp(const SoulApp());
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _sentryDsn;
      options.environment = kReleaseMode ? 'release' : 'debug';
      options.tracesSampleRate = 0.2;
      options.sendDefaultPii = false;
    },
    appRunner: () => runApp(const SoulApp()),
  );
}

/// A way to open one screen directly, for reviewing them without walking the
/// whole flow. Set SOUL_SCREEN in the environment. Unset, the app starts where
/// a user starts.
///
/// This exists so screens can be looked at side by side during design review.
/// It reads an environment variable rather than a compiled constant so one
/// build can show any of them.
Widget? _requestedScreen() {
  final name = Platform.environment['SOUL_SCREEN'];
  if (name == null || name.isEmpty) return null;

  final api = SoulApi.fromEnvironment();
  void nothing() {}

  // Only the screens that can stand on their own data are here. The screens in
  // the middle of the loop, beat one and the Mirror and the pattern question,
  // are reached by walking the loop, because the only way to open one directly
  // would be to hand it a reflection nobody wrote.
  return switch (name) {
    'intro' => IntroScreen(onContinue: nothing, onSkip: nothing),
    'profile' => ProfileScreen(onFinished: (_) {}),
    'sign_in' => SignInScreen(onSignedIn: nothing, onSkip: nothing),
    'baseline' => BaselineScreen(onFinished: (_) {}),
    'capture' => CaptureScreen(onSubmitted: (_) {}),
    'home' => const Home(),
    'day' => DayScreen(api: api, date: todayOnDevice(), onBack: nothing),
    'patterns' => PatternsScreen(api: api),
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
      home: _requestedScreen() ?? const _Launch(),
    );
  }
}

/// First run, or straight to home.
///
/// Two keychain reads decide it: whether this phone has a session, and
/// whether first run was walked to the end. A phone gets its session on
/// first launch, before a single question, so the token alone no longer
/// means a person finished. What sits under the reads is the app's own
/// background, so there is nothing worth spinning at for the length of them.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  /// Read once, held here. Calling this inside build handed the builder a new
  /// future on every rebuild, which dropped back to the waiting state and
  /// threw away whatever the app had built underneath it.
  late final Future<bool> _returning = _check();

  static Future<bool> _check() async {
    if (await sessionToken() == null) return false;
    return firstRunDone();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _returning,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Screen(body: []);
        }
        // Home shows the week the server returns, so a person who signed in
        // months ago and one who signed in a minute ago both see their own.
        return snapshot.data == true ? const Home() : const FirstRun();
      },
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
  final _api = SoulApi.fromEnvironment();
  int _step = 0;
  Profile _profile = const Profile();

  /// The account this phone writes into, asked for before anything is asked
  /// of the person. Held as a future so the intro's continue can wait on it,
  /// which is the only wait in first run and is almost always already over.
  /// A phone that is offline gets no account and the posts that follow fail
  /// quietly, which is what they did before too.
  late final Future<void> _account = _ensureAccount();

  Future<void> _ensureAccount() async {
    if (await sessionToken() != null) return;
    try {
      await storeSessionToken(await _api.deviceSession());
      _api.event('account_created');
    } catch (_) {
      // Nothing to tell them yet. Sign in at the end makes another attempt.
    }
  }


  void _next() => setState(() => _step++);
  void _previous() => setState(() => _step = _step > 0 ? _step - 1 : 0);

  /// First run ends on home, empty, with whatever name was given. A user
  /// who has just arrived has no week behind them, so the day one version is
  /// the true one and the populated version is only ever reached by living
  /// with the app.
  /// The introduction is stored, not reflected on, and it always lands on
  /// home.
  ///
  /// Every later entry earns a line back. This one does not: it is how the
  /// app learns who it is talking to, and a user who has just answered
  /// fifteen questions should arrive somewhere rather than be handed one more
  /// screen.
  ///
  /// Nothing is shown for a flagged introduction either, on the founder's
  /// call. See decision 063. The classifier still runs, blocking, on the
  /// server, and the safety_flags row is still written with the risk level and
  /// the categories, so the record exists for whoever reads it when the
  /// escalation path is built. What is missing is the screen: a user who
  /// says something serious here sees home, the same as everyone else.
  void _submitIntroduction(BuildContext context, String text,
      {required bool spoken, String? toneId}) {
    _api.submit(text: text, spoken: spoken, toneId: toneId).then(
      (result) => _api.event('introduction_stored', {
        'state': result.runtimeType.toString(),
        'spoken': spoken,
      }),
      onError: (Object error) => _api.event('introduction_failed', {
        'status': error is SoulApiException ? error.status : null,
      }),
    );
    setState(() => _step++);
  }

  Future<void> _toHome(BuildContext context) async {
    await markFirstRunDone();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => Home(name: _profile.displayName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // What this says, and does not say, is the scope framing the clinical
    // guidance asks for. The consent screen is still absent: consent is
    // recorded by the district at rostering, so nothing here gates on it, and
    // this screen makes no promise about confidentiality it cannot keep until
    // the escalation policy is written. See decisions 048 and 055.
    return switch (_step) {
      0 => IntroScreen(
          onContinue: () async {
            await _account;
            _next();
          },
          // Development only. Straight to home as the seeded demo user, so
          // home can be judged against a week that exists rather than against
          // an empty account or fifteen questions of setup.
          onSkip: () {
            SoulApi.demoUser = 'student_demo';
            _toHome(context);
          },
        ),

      // Four questions, every one of them skippable. Sent in the background,
      // because a user should never wait on this, and a profile where
      // everything was skipped is never sent at all.
      1 => ProfileScreen(
          onBack: _previous,
          onFinished: (profile) {
            setState(() => _profile = profile);
            if (!profile.isEmpty) _api.profile(profile.toJson()).ignore();
            _next();
          },
        ),

      // Nothing is scored and nothing is shown back. The answers are a
      // baseline for later, not a result for now.
      2 => BaselineScreen(
          onBack: _previous,
          onFinished: (answers) {
            _api.baseline(baselineVersion, answers).ignore();
            _next();
          },
        ),

      // The first real pass through the loop, at the end of first run.
      // Step 3.
      //
      // Everything before this was answered by tapping. This is the first
      // time a user says something in their own words, and it goes the
      // whole way: consent gate, safety classifier, then a generated line
      // that names something only they said. It is also the only honest way
      // to show what the product is, because describing the loop is not the
      // same as feeling it.
      3 => CaptureScreen(
          onBack: _previous,
          opener: 'last one',
          prompt: 'Tell us about yourself.',
          note: 'Speak or type. What you are like, what you spend your time '
              'on, what is on your mind lately.',
          onSubmitted: (text) =>
              _submitIntroduction(context, text, spoken: false),
          // The introduction has no confirm step, so the spoken words and how
          // they sounded go straight in together.
          onTranscribed: (transcript) => _submitIntroduction(
            context,
            transcript.text,
            spoken: true,
            toneId: transcript.toneId,
          ),
        ),

      // Last. Signing in comes after there is something to keep, not before
      // the user has seen what this is.
      _ => SignInScreen(
          onBack: _previous,
          onSignedIn: () => _toHome(context),
          onSkip: () => _toHome(context),
        ),
    };
  }
}

/// Screen 4 and everything reached from it.
class Home extends StatefulWidget {
  const Home({super.key, this.name});
  final String? name;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  /// Bumped when an entry lands. It tells the tabs to read again rather than
  /// counting anything up here: the week is the server's answer, and a number
  /// added on the device would be a second version of it.
  int _entries = 0;

  @override
  Widget build(BuildContext context) {
    // Always the shell, including on day one. A new user getting a
    // different navigation model from everyone else is the same problem as an
    // empty screen looking broken.
    return AppShell(
      revision: _entries,
      name: widget.name,
      onCapture: () => _openCapture(context),
    );
  }

  void _openSession(
    BuildContext context,
    String text, {
    required bool spoken,
    String? toneId,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (session) => Session(
          transcript: text,
          spoken: spoken,
          toneId: toneId,
          onFinished: () {
            Navigator.of(session).popUntil((route) => route.isFirst);
            setState(() => _entries++);
          },
        ),
      ),
    );
  }

  void _openCapture(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (capture) => CaptureScreen(
          opener: 'right now',
          prompt: 'What just happened?',
          note: 'Thirty seconds is plenty.',
          onClose: () => Navigator.of(capture).pop(),
          onSubmitted: (text) => _openSession(capture, text, spoken: false),
          onTranscribed: (transcript) => _openSession(
            capture,
            transcript.text,
            spoken: true,
            toneId: transcript.toneId,
          ),
        ),
      ),
    );
  }
}

/// One pass through the loop, against the API.
///
/// Screens 5 and 6. Every word on them is generated for this entry, the safety
/// classifier has already run before any of it arrives, and a blocked entry
/// never reaches this screen at all.
class Session extends StatefulWidget {
  const Session({
    super.key,
    required this.transcript,
    required this.onFinished,
    this.spoken = false,
    this.toneId,
  });

  final String transcript;
  final VoidCallback onFinished;

  /// How the spoken words sounded, as a handle the server gave back with the
  /// transcript. Sent with the entry, or discarded with the transcript. Null
  /// for a typed entry and for a recording nothing managed to listen to.
  final String? toneId;

  /// Whether this came from the mic. The confirm step exists because
  /// transcription can be wrong, and recognition on children's voices is
  /// weakest of all. A user who typed their own words has nothing to
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

  /// Whether the entry behind the failure screen actually reached the server.
  bool _stored = false;

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
        toneId: widget.toneId,
      );
      _api.event('entry_${result.runtimeType.toString().toLowerCase()}', {
        'spoken': widget.spoken,
      });
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
          // Stored, nothing sent. The user is told plainly rather than
          // shown a reflection that was never generated.
          setState(() {
            _stored = true;
            _beat = _Beat.failed;
          });
      }
    } catch (error) {
      // The request itself failed, so nothing reached the server.
      _api.event('entry_failed', {
        'status': error is SoulApiException ? error.status : null,
        'spoken': widget.spoken,
      });
      if (mounted) {
        setState(() {
          _stored = false;
          _beat = _Beat.failed;
        });
      }
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
        // The decision is the user's, not ours. Losing it to a dropped
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
          onDiscard: () {
            // The transcript goes, and how it sounded goes with it. Nobody
            // waits on the delete and a failed one is swept up by the next
            // recording on the server.
            final toneId = widget.toneId;
            if (toneId != null) _api.discardTone(toneId).ignore();
            Navigator.of(context).pop();
          },
        ),
      _Beat.waiting => const _Waiting(note: 'reading what you said'),
      _Beat.one => BeatOneScreen(
          transcript: widget.transcript,
          line: _line!,
          // Nothing measures this yet, so nothing is claimed. It said forty one
          // seconds for every voice entry ever made, which is the same kind of
          // invented content the sample file was deleted for.
          spokenSeconds: null,
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
      _Beat.failed => _Failed(
          onDone: widget.onFinished,
          stored: _stored,
          onRetry: _stored ? null : _submit,
        ),
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
/// Two different things went wrong and they are not told the same way.
///
/// A held entry is on the server and the user can be told so. A submission
/// that never arrived is not, and saying it is kept when it is not is the one
/// thing this screen must never do: the user closes the app believing their
/// words are somewhere.
class _Failed extends StatelessWidget {
  const _Failed({required this.onDone, required this.stored, this.onRetry});

  final VoidCallback onDone;

  /// Whether the entry reached the server. False when the request itself
  /// failed, which means the words exist only on this screen.
  final bool stored;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        Text(stored ? 'That is saved' : 'That did not send',
            style: SoulType.heading),
        const SizedBox(height: 14),
        Text(
          stored
              ? 'We could not read it back to you just now. What you wrote is '
                  'kept and nothing is lost.'
              : 'It is still on this screen and it has not gone anywhere yet. '
                  'Try again, or go back and it is yours to keep or discard.',
          style: SoulType.secondary,
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!stored && onRetry != null)
            SoulButton('Try again',
                kind: SoulButtonKind.filled, onPressed: onRetry),
          if (!stored && onRetry != null) const SizedBox(height: 8),
          SoulButton('Done',
              kind: stored ? SoulButtonKind.filled : SoulButtonKind.outline,
              onPressed: onDone),
        ],
      ),
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
