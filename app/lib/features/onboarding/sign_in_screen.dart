import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/client.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'policies.dart';

/// The last screen of first run. Sign in with Apple, or with an email code.
///
/// It comes after the introduction rather than before anything, so a person
/// is asked to sign in to keep something that already exists rather than to
/// get through a door. What they wrote is already saved either way, in the
/// account this phone was given on first launch. Signing in attaches a way
/// back into it from another phone.
///
/// The agreement was already made, on its own screen before the first word,
/// so nothing here gates on it.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignedIn,
    required this.onSkip,
    this.onBack,
  });

  final VoidCallback onSignedIn;

  /// The screen before this one.
  final VoidCallback? onBack;

  /// Development only. Goes straight to home with no account. It is labelled
  /// as such on the screen so nobody ships it by forgetting it is there.
  final VoidCallback onSkip;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _api = SoulApi.fromEnvironment();

  bool _running = false;
  bool _failed = false;

  /// Email is not offered until Apple has been tried and did not work.
  /// One way in is less to read; the second appears at the moment it is
  /// the answer to something.
  bool _emailOffered = false;

  /// The email path. An address, then a code, then in. It sits under Apple's
  /// button for anybody Apple's sheet does not work for, and it is a full
  /// sign in rather than a fallback: the address is the way back in.
  final _email = TextEditingController();
  bool _emailRunning = false;
  String? _emailNote;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _finish(String token, String how) async {
    await storeSessionToken(token);
    _api.event('signin_ok', {'how': how});
    if (!mounted) return;
    widget.onSignedIn();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _emailNote = 'That does not look like an email address.');
      return;
    }
    setState(() {
      _emailRunning = true;
      _emailNote = null;
    });
    try {
      await _api.emailStart(email);
      _api.event('signin_email_code_sent');
      if (!mounted) return;
      setState(() => _emailRunning = false);
      // The code has a screen of its own, so the one thing being asked for
      // is the only thing on it.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EmailCodeScreen(
            email: email,
            onSignedIn: (token) => _finish(token, 'email'),
          ),
        ),
      );
    } on SoulApiException catch (error) {
      _api.event('signin_email_start_failed', {'status': error.status});
      if (!mounted) return;
      setState(() {
        _emailRunning = false;
        _emailNote = error.status == 503
            ? 'Email sign in is not available right now.'
            : error.status == 429
                ? 'Too many codes for now. Try again in a while.'
                : 'That did not go through.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emailRunning = false;
        _emailNote = 'That did not go through.';
      });
    }
  }

  /// Apple's sheet, then the exchange, then the token on the device.
  ///
  /// No scopes are asked for. Asking Apple for a name or an address would
  /// contradict the policy the person has just been shown two lines above
  /// the button. The account identifier and the signed token are the whole
  /// of what arrives, and the server never learns who the Apple account
  /// belongs to.
  Future<void> _signIn() async {
    setState(() {
      _running = true;
      _failed = false;
    });

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [],
      );
      final identityToken = credential.identityToken;
      final appleUserId = credential.userIdentifier;
      if (identityToken == null || appleUserId == null) {
        throw const FormatException('apple returned no identity');
      }

      final token = await _api.signInWithApple(
        identityToken: identityToken,
        appleUserId: appleUserId,
      );
      await _finish(token, 'apple');
    } on SignInWithAppleAuthorizationException catch (error) {
      // Backing out of Apple's sheet is a decision, not a fault. The screen
      // goes back to how it was and says nothing about it.
      if (error.code != AuthorizationErrorCode.canceled) {
        _api.event('signin_apple_failed', {'code': error.code.name});
      }
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = error.code != AuthorizationErrorCode.canceled;
        if (_failed) _emailOffered = true;
      });
    } catch (error) {
      // Refused, offline, or the server said no. One line, and the button is
      // still there.
      _api.event('signin_apple_failed', {
        'status': error is SoulApiException ? error.status : null,
      });
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = true;
        _emailOffered = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      body: [
        // The way out sits top right, away from the thumb that is about to
        // press the button at the bottom.
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: const Padding(
                padding: EdgeInsets.only(left: 16, bottom: 12),
                child: Icon(Icons.close, size: 24, color: SoulColors.text3),
              ),
            ),
          ),
        // The lock and the line sit together in the upper middle, with the
        // room below them empty. Nothing else on this screen is a reason to
        // read, so nothing else is on it.
        const SizedBox(height: 150),
        const Center(
          child: Icon(Icons.lock_outline, size: 30, color: SoulColors.clay),
        ),
        const SizedBox(height: 26),
        Text(
          'This space is yours.\nSign in to keep what you have said.',
          textAlign: TextAlign.center,
          style: SoulType.heading.copyWith(fontSize: 26, height: 1.35),
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The terms, reachable, and not a gate. Using the app is the
          // agreement, per decision 201, so this says so rather than asking
          // for a tick that would stand between somebody and their account.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: SoulColors.s2,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  'By signing in you agree to the Terms of Service and the '
                  'Privacy Policy, and to what you write being sent to the '
                  'providers named there so the app can answer.',
                  textAlign: TextAlign.center,
                  style: SoulType.secondary.copyWith(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Link(
                      'Terms of Service',
                      onTap: () => openPolicy(context, 'Terms of Service', termsOfService),
                    ),
                    const SizedBox(width: 20),
                    _Link(
                      'Privacy Policy',
                      onTap: () => openPolicy(context, 'Privacy Policy', privacyPolicy),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AppleButton(
            enabled: true,
            running: _running,
            onPressed: _signIn,
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              'That did not go through. Your email works too.',
              textAlign: TextAlign.center,
              style: SoulType.secondary.copyWith(color: SoulColors.clay),
            ),
          ],
          if (_emailOffered) ...[
          const SizedBox(height: 14),
          _EmailSignIn(
            enabled: !_running,
            running: _emailRunning,
            note: _emailNote,
            email: _email,
            onSendCode: _sendCode,
          ),
          ],
          const SizedBox(height: 6),
          // Development only, and it says so. It exists because first run is
          // fifteen questions long and testing the rest of the app should not
          // cost an Apple account every time.
          //
          // Nothing is stored on this path, on purpose. A skip that left a
          // token behind would hide first run from the next launch, which is
          // the one thing the person pressing it is usually trying to see.
          SoulButton(
            'Skip sign in, development only',
            kind: SoulButtonKind.ghost,
            onPressed: _running ? null : widget.onSkip,
          ),
        ],
      ),
    );
  }

}


/// Apple's button, in Apple's shape.
///
/// It is dimmed rather than removed until the box is ticked, so the order is
/// obvious: read, agree, then sign in.
class _AppleButton extends StatelessWidget {
  const _AppleButton({
    required this.enabled,
    required this.running,
    required this.onPressed,
  });

  final bool enabled;

  /// Apple's sheet is its own window, so the wait a user notices is the one
  /// after it closes, while the token is exchanged. The button says so rather
  /// than sitting there looking pressed.
  final bool running;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: TextButton(
          onPressed: running ? null : onPressed,
          style: TextButton.styleFrom(
            backgroundColor: Colors.black,
            disabledBackgroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: running
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apple, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Sign in with Apple',
                      style: TextStyle(
                        fontFamily: SoulType.sans,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Sign in by email. An address and a button, then a code and a button.
///
/// It is quieter than Apple's button and sits under it, and it is dimmed the
/// same way until the box is ticked. The note under it says what happened
/// last, in one line, and is the only feedback: no toasts, no dialogs.
/// The address, and the button that sends a code to it. The code itself is
/// asked for on its own screen.
class _EmailSignIn extends StatelessWidget {
  const _EmailSignIn({
    required this.enabled,
    required this.running,
    required this.note,
    required this.email,
    required this.onSendCode,
  });

  final bool enabled;
  final bool running;
  final String? note;
  final TextEditingController email;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Field(
            controller: email,
            hint: 'Email',
            keyboard: TextInputType.emailAddress,
            enabled: enabled && !running,
            onDone: onSendCode,
          ),
          const SizedBox(height: 8),
          SoulButton(
            running ? 'Sending' : 'Continue',
            onPressed: enabled && !running ? onSendCode : null,
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              textAlign: TextAlign.center,
              style: SoulType.secondary.copyWith(fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// The code, on its own screen, because it is one thing to do and the screen
/// behind it has three.
class EmailCodeScreen extends StatefulWidget {
  const EmailCodeScreen({
    super.key,
    required this.email,
    required this.onSignedIn,
  });

  final String email;

  /// Handed the session token. The screen behind this one stores it and
  /// carries on, so this one only has to close.
  final Future<void> Function(String token) onSignedIn;

  @override
  State<EmailCodeScreen> createState() => _EmailCodeScreenState();
}

class _EmailCodeScreenState extends State<EmailCodeScreen> {
  final _api = SoulApi.fromEnvironment();
  final _code = TextEditingController();
  bool _running = false;
  String? _note;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _note = 'The code is six digits.');
      return;
    }
    setState(() {
      _running = true;
      _note = null;
    });
    try {
      final token = await _api.emailVerify(widget.email, code);
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSignedIn(token);
    } catch (error) {
      _api.event('signin_email_failed', {
        'status': error is SoulApiException ? error.status : null,
      });
      if (!mounted) return;
      setState(() {
        _running = false;
        _note = 'That code did not work. Check it, or ask for another.';
      });
    }
  }

  Future<void> _again() async {
    setState(() {
      _running = true;
      _note = null;
    });
    try {
      await _api.emailStart(widget.email);
      if (!mounted) return;
      setState(() {
        _running = false;
        _note = 'Another code is on its way.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _running = false;
        _note = 'That did not go through.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      body: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.only(right: 16, bottom: 12),
              child: Icon(Icons.chevron_left, size: 26, color: SoulColors.text3),
            ),
          ),
        ),
        const SizedBox(height: 150),
        const Center(
          child: Icon(Icons.mail_outline, size: 30, color: SoulColors.clay),
        ),
        const SizedBox(height: 26),
        Text(
          'Enter the code sent to\n${widget.email}',
          textAlign: TextAlign.center,
          style: SoulType.heading.copyWith(fontSize: 24, height: 1.35),
        ),
        const SizedBox(height: 26),
        _Field(
          controller: _code,
          hint: '6 digit code',
          keyboard: TextInputType.number,
          enabled: !_running,
          onDone: _verify,
        ),
        const SizedBox(height: 8),
        SoulButton(
          _running ? 'Checking' : 'Continue',
          kind: SoulButtonKind.filled,
          onPressed: _running ? null : _verify,
        ),
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _running ? null : _again,
          child: Text(
            'Send another code',
            textAlign: TextAlign.center,
            style: SoulType.secondary.copyWith(fontSize: 13, color: SoulColors.clay),
          ),
        ),
        if (_note != null) ...[
          const SizedBox(height: 10),
          Text(
            _note!,
            textAlign: TextAlign.center,
            style: SoulType.secondary.copyWith(fontSize: 13),
          ),
        ],
      ],
    );
  }
}


class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.keyboard,
    required this.enabled,
    required this.onDone,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboard;
  final bool enabled;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: SoulColors.s1,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SoulColors.border),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onDone(),
        style: SoulType.secondary.copyWith(
          fontSize: 15,
          color: SoulColors.text,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: SoulType.secondary.copyWith(fontSize: 15),
        ),
      ),
    );
  }
}

/// One of the two policy links under the button.
class _Link extends StatelessWidget {
  const _Link(this.text, {required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: SoulType.sans,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: SoulColors.clay,
          decoration: TextDecoration.underline,
          decorationColor: SoulColors.clay,
        ),
      ),
    );
  }
}

/// A policy, in full, in a sheet.
void openPolicy(BuildContext context, String title, String body) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: SoulColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: SoulType.heading.copyWith(fontSize: 24)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheet).pop(),
                  icon: const Icon(Icons.close, size: 22, color: SoulColors.text3),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22),
            child: Rule(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
              child: Text(body.trim(), style: SoulType.secondary),
            ),
          ),
        ],
      ),
    ),
  );
}

