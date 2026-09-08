import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../capture/speech_field.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Saying anything about the app itself.
///
/// It sits at the bottom of home rather than in the profile, because the
/// moment somebody has an opinion about the app is the moment they have just
/// used it, and the profile is where they go to change an answer.
///
/// Not a survey and not a rating. One box, no stars, no categories to pick
/// from and nothing required before it will send, because every one of those
/// is a reason to close the sheet instead.
///
/// The words are neutral on purpose. Asking what is not working is a
/// question with an answer already in it, and somebody who liked something
/// has nowhere to put that.
///
/// What comes back is a yes or a no. This is the one thing a person writes
/// that is addressed to us, and closing on the promise of having sent it
/// without knowing is how a complaint gets lost twice.
Future<void> openFeedback(BuildContext context, {required String surface}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: SoulColors.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheet) => _FeedbackSheet(surface: surface),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.surface});
  final String surface;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _api = SoulApi.fromEnvironment();
  final _text = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _note;


  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _note = null;
    });
    try {
      await _api.feedback(text, surface: widget.surface);
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        // What they wrote is still in the box, so the way to try again is to
        // press the button again rather than to write it out a second time.
        _note = 'That did not send. It is still here, try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          24,
          22,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _sent ? _thanks(context) : _form(),
        ),
      ),
    );
  }

  List<Widget> _form() => [
        const Text('Give us feedback', style: SoulType.lead),
        const SizedBox(height: 8),
        const Text(
          'Anything about the app itself. What works, what does not, what is '
          'missing. It comes straight to us.',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 16),
        // The same box the rest of the app puts in front of somebody:
        // type into it, or tap the mic on its right and say it. Feedback is
        // the last place that should insist on a keyboard.
        SpeechField(controller: _text, hint: 'Say it plainly'),
        if (_note != null) ...[
          const SizedBox(height: 12),
          Text(_note!, style: SoulType.secondary.copyWith(color: SoulColors.clay)),
        ],
        const SizedBox(height: 16),
        SoulButton(
          _sending ? 'Sending' : 'Send',
          kind: SoulButtonKind.filled,
          onPressed: _text.text.trim().isEmpty || _sending ? null : _send,
        ),
      ];

  List<Widget> _thanks(BuildContext context) => [
        const SizedBox(height: 8),
        const Text('That reached us', style: SoulType.lead),
        const SizedBox(height: 8),
        const Text(
          'Somebody reads these. Nothing you wrote in the app went with it.',
          style: SoulType.secondary,
        ),
        const SizedBox(height: 20),
        SoulButton(
          'Close',
          kind: SoulButtonKind.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 4),
      ];
}
