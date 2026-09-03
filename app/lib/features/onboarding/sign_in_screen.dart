import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/client.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

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

  /// The email path. An address, then a code, then in. It sits under Apple's
  /// button for anybody Apple's sheet does not work for, and it is a full
  /// sign in rather than a fallback: the address is the way back in.
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeSent = false;
  bool _emailRunning = false;
  String? _emailNote;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
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
      setState(() {
        _emailRunning = false;
        _codeSent = true;
        _emailNote = 'A six digit code is on its way to $email.';
      });
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

  Future<void> _verifyCode() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _emailNote = 'The code is six digits.');
      return;
    }
    setState(() {
      _emailRunning = true;
      _emailNote = null;
    });
    try {
      final token = await _api.emailVerify(_email.text.trim(), code);
      await _finish(token, 'email');
    } catch (error) {
      _api.event('signin_email_failed', {
        'status': error is SoulApiException ? error.status : null,
      });
      if (!mounted) return;
      setState(() {
        _emailRunning = false;
        _emailNote = 'That code did not work. Check it, or ask for another.';
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Screen(
      padding: const EdgeInsets.fromLTRB(22, 40, 22, 22),
      body: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onBack,
              child: const Padding(
                padding: EdgeInsets.only(right: 16, bottom: 12),
                child: Icon(Icons.chevron_left, size: 26, color: SoulColors.text3),
              ),
            ),
          ),
        const SizedBox(height: 48),
        const Center(
          child: Icon(Icons.lock_outline, size: 34, color: SoulColors.clay),
        ),
        const SizedBox(height: 22),
        Text(
          'This space is yours.\nSign in to keep it.',
          textAlign: TextAlign.center,
          style: SoulType.heading.copyWith(fontSize: 27, height: 1.25),
        ),
        const SizedBox(height: 14),
        Text(
          'What you have written is already saved. Signing in is what keeps it '
          'yours if you ever change phones.',
          textAlign: TextAlign.center,
          style: SoulType.secondary,
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AppleButton(
            enabled: true,
            running: _running,
            onPressed: _signIn,
          ),
          if (_failed) ...[
            const SizedBox(height: 10),
            Text(
              'That did not go through.',
              textAlign: TextAlign.center,
              style: SoulType.secondary.copyWith(color: SoulColors.clay),
            ),
          ],
          const SizedBox(height: 14),
          _EmailSignIn(
            enabled: !_running,
            running: _emailRunning,
            codeSent: _codeSent,
            note: _emailNote,
            email: _email,
            code: _code,
            onSendCode: _sendCode,
            onVerify: _verifyCode,
          ),
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
class _EmailSignIn extends StatelessWidget {
  const _EmailSignIn({
    required this.enabled,
    required this.running,
    required this.codeSent,
    required this.note,
    required this.email,
    required this.code,
    required this.onSendCode,
    required this.onVerify,
  });

  final bool enabled;
  final bool running;
  final bool codeSent;
  final String? note;
  final TextEditingController email;
  final TextEditingController code;
  final VoidCallback onSendCode;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Or use your email',
            textAlign: TextAlign.center,
            style: SoulType.secondary.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (!codeSent) ...[
            _Field(
              controller: email,
              hint: 'you@somewhere.com',
              keyboard: TextInputType.emailAddress,
              enabled: enabled && !running,
              onDone: onSendCode,
            ),
            const SizedBox(height: 8),
            SoulButton(
              running ? 'Sending' : 'Send code',
              onPressed: enabled && !running ? onSendCode : null,
            ),
          ] else ...[
            _Field(
              controller: code,
              hint: '6 digit code',
              keyboard: TextInputType.number,
              enabled: enabled && !running,
              onDone: onVerify,
            ),
            const SizedBox(height: 8),
            SoulButton(
              running ? 'Checking' : 'Log in',
              kind: SoulButtonKind.filled,
              onPressed: enabled && !running ? onVerify : null,
            ),
          ],
          if (codeSent) ...[
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled && !running ? onSendCode : null,
              child: Text(
                'Send another code',
                textAlign: TextAlign.center,
                style: SoulType.secondary.copyWith(
                  fontSize: 13,
                  color: SoulColors.clay,
                ),
              ),
            ),
          ],
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
