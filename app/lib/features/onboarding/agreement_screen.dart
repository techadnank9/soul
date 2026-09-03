import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import 'policies.dart';

/// The agreement, before anything is said.
///
/// It used to sit on the sign in screen at the very end of first run, which
/// meant the spoken introduction was recorded before anybody had agreed to
/// anything, and the server correctly refused to let the audio leave. Nothing
/// about the gate changed. The question moved to where it has to be asked:
/// before the first word.
///
/// The box gates the button, because a consent that happens by pressing the
/// only control on the screen is not a consent. Both documents open in full
/// from here.
class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key, required this.onAgreed});

  final VoidCallback onAgreed;

  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _agreed = false;
  bool _tried = false;

  void _continue() {
    if (!_agreed) {
      setState(() => _tried = true);
      return;
    }
    widget.onAgreed();
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
          'Before you say anything.',
          textAlign: TextAlign.center,
          style: SoulType.heading.copyWith(fontSize: 27, height: 1.25),
        ),
        const SizedBox(height: 14),
        Text(
          'What you write and say is sent to the providers named in the '
          'privacy policy so the app can answer you. Nothing leaves until '
          'you agree, and the recording is never kept.',
          textAlign: TextAlign.center,
          style: SoulType.secondary,
        ),
      ],
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AgreementBox(
            agreed: _agreed,
            warn: _tried && !_agreed,
            onChanged: (value) => setState(() {
              _agreed = value;
              if (value) _tried = false;
            }),
            onOpen: (title, body) => openPolicy(context, title, body),
          ),
          const SizedBox(height: 14),
          SoulButton(
            'Continue',
            kind: SoulButtonKind.filled,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }
}

/// The checkbox and the two links. Shared so the wording lives once.
class AgreementBox extends StatelessWidget {
  const AgreementBox({
    super.key,
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
                    'and to what I write and say being sent to the providers '
                    'named there so the app can answer.',
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
                  child: Text(
                    title,
                    style: SoulType.heading.copyWith(fontSize: 24),
                  ),
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
