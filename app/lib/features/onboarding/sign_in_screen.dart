import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../api/client.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'policies.dart';

/// The last screen of first run. Sign in, or carry on without one.
///
/// It comes after the introduction rather than before anything, so a student
/// is asked to sign in to keep something that already exists rather than to
/// get through a door. What they wrote is already saved either way.
///
/// The agreement is a checkbox and it gates the button, because a consent that
/// happens by pressing the only control on the screen is not a consent. Both
/// documents open in full from here.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignedIn,
    required this.onSkip,
  });

  final VoidCallback onSignedIn;

  /// Development only. Goes straight to home with no account. It is labelled
  /// as such on the screen so nobody ships it by forgetting it is there.
  final VoidCallback onSkip;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _api = SoulApi.fromEnvironment();

  bool _agreed = false;
  bool _tried = false;
  bool _running = false;
  bool _failed = false;

  /// Apple's sheet, then the exchange, then the token on the device.
  ///
  /// No scopes are asked for. This product holds no names and no email
  /// addresses, and asking Apple for either would contradict the policy the
  /// student has just been shown two lines above the button. The account
  /// identifier and the signed token are the whole of what arrives, and the
  /// server never learns who the Apple account belongs to.
  Future<void> _signIn() async {
    if (!_agreed) {
      setState(() => _tried = true);
      return;
    }

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
      await storeSessionToken(token);

      if (!mounted) return;
      widget.onSignedIn();
    } on SignInWithAppleAuthorizationException catch (error) {
      // Backing out of Apple's sheet is a decision, not a fault. The screen
      // goes back to how it was and says nothing about it.
      if (!mounted) return;
      setState(() {
        _running = false;
        _failed = error.code != AuthorizationErrorCode.canceled;
      });
    } catch (_) {
      // Refused, offline, or the server said no. One line, and the button is
      // still there.
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
        const SizedBox(height: 60),
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
          _Agreement(
            agreed: _agreed,
            warn: _tried && !_agreed,
            onChanged: (value) => setState(() {
              _agreed = value;
              if (value) _tried = false;
            }),
            onOpen: (title, body) => _open(context, title, body),
          ),
          const SizedBox(height: 14),
          _AppleButton(
            enabled: _agreed,
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

  void _open(BuildContext context, String title, String body) {
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
                    child: Text(
                      title,
                      style: SoulType.heading.copyWith(fontSize: 24),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheet).pop(),
                    icon: const Icon(Icons.close,
                        size: 22, color: SoulColors.text3),
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
}

class _Agreement extends StatelessWidget {
  const _Agreement({
    required this.agreed,
    required this.warn,
    required this.onChanged,
    required this.onOpen,
  });

  final bool agreed;
  final bool warn;
  final ValueChanged<bool> onChanged;
  final void Function(String title, String body) onOpen;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: SoulColors.s2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warn ? SoulColors.clay : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!agreed),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: agreed ? SoulColors.clay : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: agreed ? SoulColors.clay : SoulColors.border2,
                      width: 2,
                    ),
                  ),
                  child: agreed
                      ? const Icon(Icons.check, size: 15, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I agree to the Terms of Service and the Privacy Policy, '
                    'and to what I write being sent to the providers named '
                    'there so the app can answer.',
                    style: SoulType.secondary.copyWith(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Row(
              children: [
                _Link(
                  'Terms of Service',
                  onTap: () => onOpen('Terms of Service', termsOfService),
                ),
                const SizedBox(width: 20),
                _Link(
                  'Privacy Policy',
                  onTap: () => onOpen('Privacy Policy', privacyPolicy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: SoulColors.clay,
          decoration: TextDecoration.underline,
          decorationColor: SoulColors.clay,
        ),
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

  /// Apple's sheet is its own window, so the wait a student notices is the one
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
