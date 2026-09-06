import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../data/session_store.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';
import '../onboarding/sign_in_screen.dart';

/// Putting a number on the account that is already here.
///
/// The same two calls as signing in by text, and the same six digits. The
/// difference is who is asking: this screen carries the session of the
/// account already on the phone, and the server attaches the number to that
/// account rather than making a new one. Nothing written is left behind.
///
/// A number already on another account signs into that one instead, which
/// is the right answer to somebody proving they own it.
class AddPhoneScreen extends StatefulWidget {
  const AddPhoneScreen({super.key, required this.api, required this.onAdded});

  final SoulApi api;

  /// Called once the number is on the account, so the profile can read
  /// itself again and show it.
  final VoidCallback onAdded;

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _phone = TextEditingController(text: '+1 ');
  bool _running = false;
  String? _note;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final phone = '+${_phone.text.replaceAll(RegExp(r'[^0-9]'), '')}';
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      setState(() =>
          _note = 'That does not look like a phone number. Start with the country code.');
      return;
    }
    setState(() {
      _running = true;
      _note = null;
    });

    try {
      await widget.api.phoneStart(phone);
      widget.api.event('phone_code_sent');
      if (!mounted) return;
      setState(() => _running = false);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CodeScreen(
            email: phone,
            byPhone: true,
            onSignedIn: (token) async {
              // The account is the same one. The token is new because the
              // server issues one on every proof, and holding the newer of
              // the two is the safe way round.
              await storeSessionToken(token);
              widget.api.event('phone_attached');
              widget.onAdded();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
      );
    } on SoulApiException catch (error) {
      widget.api.event('phone_start_failed', {'status': error.status});
      if (!mounted) return;
      setState(() {
        _running = false;
        _note = switch (error.status) {
          503 => 'Text sign in is not available right now.',
          429 => 'Too many codes for now. Try again in a while.',
          502 => 'That number did not go through.',
          _ => 'That did not go through.',
        };
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
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      body: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
            child: const Padding(
              padding: EdgeInsets.only(right: 16, bottom: 10),
              child: Icon(Icons.chevron_left, size: 26, color: SoulColors.text3),
            ),
          ),
        ),
        const Text('Your number', style: SoulType.heading),
        const SizedBox(height: 10),
        const Text(
          'A code comes by text. The number becomes another way back into '
          'this account, and nothing else is ever sent to it.',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 22),
        _PhoneField(controller: _phone, enabled: !_running, onDone: _send),
        const SizedBox(height: 10),
        SoulButton(
          _running ? 'Sending' : 'Send the code',
          kind: SoulButtonKind.filled,
          onPressed: _running ? null : _send,
        ),
        if (_note != null) ...[
          const SizedBox(height: 10),
          Text(
            _note!,
            textAlign: TextAlign.center,
            style: SoulType.secondary.copyWith(fontSize: 13, color: SoulColors.clay),
          ),
        ],
      ],
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.enabled,
    required this.onDone,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      autocorrect: false,
      style: const TextStyle(fontFamily: SoulType.sans, fontSize: 16, color: SoulColors.text),
      decoration: InputDecoration(
        hintText: 'Phone number',
        filled: true,
        fillColor: SoulColors.s1,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoulColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SoulColors.clay),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onSubmitted: (_) => onDone(),
    );
  }
}
