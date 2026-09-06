import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'api/client.dart';
import 'api/models.dart' as api;

import 'data/analytics.dart';
import 'data/flags.dart';
import 'data/session_store.dart';
import 'features/capture/capture_screen.dart';
import 'features/day/day_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/onboarding/first_run.dart';
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
  WidgetsFlutterBinding.ensureInitialized();
  await startAnalytics();
  await loadFlags();

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
      // Session replay, every session while the app is being tested, and
      // always on an error. Text and images are masked by the SDK's default,
      // so a replay shows where a person tapped, not what they wrote.
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;

      // A phone with no signal is not a fault in the app. Every screen that
      // makes a call already tells the person the connection is gone, and
      // these were arriving as fatals and burying the real ones.
      options.beforeSend = (event, hint) {
        final said = event.throwable?.toString() ?? '';
        final network = said.contains('SocketException') ||
            said.contains('Connection refused') ||
            said.contains('Connection closed') ||
            said.contains('Failed host lookup') ||
            said.contains('Network is unreachable') ||
            said.contains('TimeoutException');
        return network ? null : event;
      };
    },
    appRunner: () => runApp(SentryWidget(child: const SoulApp())),
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
    'intro' || 'how' || 'profile' || 'baseline' || 'ready' =>
      _firstRun(startAt: name),
    'sign_in' => SignInScreen(onSignedIn: nothing),
    'capture' => CaptureScreen(onSubmitted: (_, {spoken = false, toneId}) {}),
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
      // The screens are built for type up to about a fifth larger. Past
      // that the day strip and the tab bar overflowed by a few pixels,
      // which Sentry reports as a fatal every time it is drawn.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: child ?? const SizedBox.shrink(),
      ),
      // Screen names, so a funnel can say which screen somebody stopped on.
      navigatorObservers: [?screenObserver()],
      home: _requestedScreen() ?? const _Launch(),
      routes: {'/start': (_) => _firstRun()},
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
enum _Start { firstRun, signIn, home }

/// Sign in on its own, after a log out. Signing in with Apple or an email
/// code finds the account those were attached to, and home follows.
class SignInAgain extends StatelessWidget {
  const SignInAgain({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> home() async {
      // Skipping with no session would open a home that every screen refuses.
      if (await sessionToken() == null) {
        try {
          await storeSessionToken(await SoulApi.fromEnvironment().deviceSession());
        } catch (_) {
          return;
        }
      }
      await markFirstRunDone();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const Home()),
        (_) => false,
      );
    }

    return SignInScreen(
      onBack: () => Navigator.of(context).maybePop(),
      onSignedIn: home,
    );
  }
}

class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  /// Read once, held here. Calling this inside build handed the builder a new
  /// future on every rebuild, which dropped back to the waiting state and
  /// threw away whatever the app had built underneath it.
  late final Future<_Start> _start = _check();

  static Future<_Start> _check() async {
    if (await sessionToken() == null) return _Start.firstRun;
    return await firstRunDone() ? _Start.home : _Start.firstRun;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Start>(
      future: _start,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Screen(body: []);
        }
        // Home shows the week the server returns, so a person who signed in
        // months ago and one who signed in a minute ago both see their own.
        return switch (snapshot.data) {
          _Start.home => const Home(),
          _Start.signIn => const SignInAgain(),
          _ => _firstRun(),
        };
      },
    );
  }
}

/// First run, wired to home.
///
/// The flow itself lives in features/onboarding/first_run.dart and knows
/// nothing about where it goes when it is over. That is decided here, next
/// to Home, which is the only place that needs to know both.
Widget _firstRun({String? startAt}) {
  return Builder(
    builder: (context) => FirstRun(
      startAt: startAt,
      onFinished: (name) => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => Home(name: name)),
      ),
      onSignInAgain: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SignInAgain()),
      ),
    ),
  );
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
      onCapture: ({String? prompt, String? note}) =>
          _openCapture(context, prompt: prompt, note: note),
    );
  }

  void _openSession(
    BuildContext context,
    String text, {
    required bool spoken,
    String? toneId,
    bool fromWeather = false,
  }) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (session) => Session(
          transcript: text,
          spoken: spoken,
          toneId: toneId,
          fromWeather: fromWeather,
          onFinished: () {
            Navigator.of(session).popUntil((route) => route.isFirst);
            setState(() => _entries++);
          },
        ),
      ),
    );
  }

  /// A prompt and a note put a specific question at the top, which is what
  /// the weather card on home hands over. Without them it is the ordinary
  /// open question.
  void _openCapture(BuildContext context, {String? prompt, String? note}) {
    // A prompt means the weather card asked this, and the entry says so, so
    // the card stands down for the day once something has been said to it.
    final fromWeather = prompt != null;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (capture) => CaptureScreen(
          opener: prompt == null ? 'right now' : 'right now, where you are',
          prompt: prompt ?? 'What just happened?',
          note: note ?? 'Thirty seconds is plenty.',
          onClose: () => Navigator.of(capture).pop(),
          onSubmitted: (text, {required spoken, toneId}) => _openSession(
            capture,
            text,
            spoken: spoken,
            toneId: toneId,
            fromWeather: fromWeather,
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
    this.fromWeather = false,
  });

  final String transcript;
  final VoidCallback onFinished;

  /// How the spoken words sounded, as a handle the server gave back with the
  /// transcript. Sent with the entry, or discarded with the transcript. Null
  /// for a typed entry and for a recording nothing managed to listen to.
  final String? toneId;

  /// Written from the weather card on home, which stands down for the day
  /// once this lands.
  final bool fromWeather;

  /// Whether any of this came from the mic. The words were on the screen as
  /// they were said and could be fixed there, so there is nothing to confirm
  /// either way.
  final bool spoken;

  @override
  State<Session> createState() => _SessionState();
}

enum _Beat { waiting, one, help, failed }

class _SessionState extends State<Session> {
  final _api = SoulApi.fromEnvironment();

  _Beat _beat = _Beat.waiting;

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
    _submit();
  }

  Future<void> _submit() async {
    setState(() => _beat = _Beat.waiting);
    try {
      final result = await _api.submit(
        text: widget.transcript,
        spoken: widget.spoken,
        toneId: widget.toneId,
        fromWeather: widget.fromWeather,
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
          // The question follows the line on its own. Nobody has to ask.
          // Unless the Mirror is switched off, in which case beat one is
          // the whole of it and nothing on screen says otherwise.
          if (isOn(Flag.mirror)) _lookCloser();
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
      });
    } catch (error) {
      _api.event('mirror_failed', {
        'status': error is SoulApiException ? error.status : null,
      });
      if (mounted) setState(() => _loadingMirror = false);
    }
  }

  /// Done. What they wrote is held as a decision when there is anything to
  /// hold. A yes with nothing written holds the thing the Mirror offered.
  Future<void> _finish({bool? answer, required String said}) async {
    _api.event('question_answered', {
      'answer': answer,
      'said': said.isNotEmpty,
    });
    final chosen = said.isNotEmpty ? said : (answer == true ? (_mirror?.offered ?? '') : '');
    await _hold(chosen);
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
      _Beat.waiting => const _Waiting(note: 'reading what you said'),
      _Beat.one => BeatOneScreen(
          transcript: widget.transcript,
          line: _line!,
          // Nothing measures this yet, so nothing is claimed.
          spokenSeconds: null,
          timeOfDay: TimeOfDay.now().format(context),
          loadingQuestion: _loadingMirror,
          underneath: _mirror?.underneath,
          question: _mirror?.question,
          onDone: _finish,
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
