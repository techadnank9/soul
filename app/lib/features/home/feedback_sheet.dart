import 'package:flutter/material.dart';

import '../../api/client.dart';
import '../../data/flags.dart';
import '../capture/dictation.dart';
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

  /// Saying it out loud instead of typing it. The same transcriber the rest
  /// of the app uses, in its small form: no waves, no tone, just the words
  /// arriving in the box where they can still be edited before they go.
  late final _dictation = Dictation(
    api: _api,
    onText: (text) {
      _text.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    },
  );
  bool _listening = false;

  Future<void> _toggleVoice() async {
    if (_listening) {
      setState(() => _listening = false);
      await _dictation.stop();
      return;
    }
    setState(() {
      _note = null;
      _listening = true;
    });
    final failed = await _dictation.start();
    if (!mounted) return;
    if (failed != null) {
      setState(() {
        _listening = false;
        _note = failed;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _dictation.dispose();
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
        SoulField(
          controller: _text,
          // The keyboard does not come up on its own any more. Half the
          // people opening this would rather say it, and a keyboard already
          // covering the screen makes the mic look like an afterthought.
          autofocus: false,
          // It grows to about half the sheet and scrolls after that, so a
          // long answer never pushes the send button off the screen.
          maxLines: 8,
          hint: 'Say it plainly',
        ),
        // The same switch the capture screen is behind. A transcriber that
        // is down should take the mic off both screens, not one.
        if (isOn(Flag.voiceCapture)) ...[
        const SizedBox(height: 12),
        // Speak it. The words land in the box above and can be changed
        // before they go, which is the difference between dictation and a
        // recording somebody cannot take back.
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _sending ? null : _toggleVoice,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _listening ? SoulColors.clay : SoulColors.s2,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _listening ? SoulColors.clay : SoulColors.border2,
                    ),
                  ),
                  child: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_none,
                    size: 20,
                    color: _listening ? Colors.white : SoulColors.text2,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _listening ? 'Listening. Tap to stop.' : 'Or say it',
                  style: SoulType.secondary.copyWith(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        ],
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
