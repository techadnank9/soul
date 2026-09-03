import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// The confirm step. Send or discard, never edit.
///
/// There is no edit field on purpose. The transcript is the permanent record
/// and the text the safety classifier reads, so the user sees it before
/// anything is submitted. Given the error rates on child speech, an unreviewed
/// permanent record is not defensible.
class ConfirmTranscript extends StatelessWidget {
  const ConfirmTranscript({
    super.key,
    required this.transcript,
    required this.onSend,
    required this.onDiscard,
  });

  final String transcript;
  final VoidCallback onSend;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        const Label('this is what we heard'),
        const SizedBox(height: 14),
        Text(transcript, style: SoulType.field),
        const SizedBox(height: 18),
        const Text(
          'If that is not what you said, discard it and say it again.',
          style: SoulType.secondary,
        ),
      ],
      footer: Column(
        children: [
          SoulButton('Send it', kind: SoulButtonKind.filled, onPressed: onSend),
          const SizedBox(height: 9),
          SoulButton('Discard', onPressed: onDiscard),
        ],
      ),
    );
  }
}
