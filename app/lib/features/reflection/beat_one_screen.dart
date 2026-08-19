import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import '../../theme/widgets.dart';

/// Screen 5. One line back, under three seconds.
///
/// The line quotes something specific the student just said. If it could be
/// pasted into a different person's entry unchanged, it has failed. There is no
/// question mark on it, because a question demands something and the first line
/// should lower pressure rather than add to it.
class BeatOneScreen extends StatelessWidget {
  const BeatOneScreen({
    super.key,
    required this.transcript,
    required this.line,
    required this.timeOfDay,
    this.spokenSeconds,
    required this.onLookCloser,
    required this.onDone,
  });

  final String transcript;
  final String line;
  /// Only set when the entry came from the mic. A typed entry was not spoken,
  /// and telling a student how long they spoke for when they did not speak is
  /// the app describing something that did not happen.
  final int? spokenSeconds;
  final String timeOfDay;
  final VoidCallback onLookCloser;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Screen(
      body: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Label(
              spokenSeconds == null
                  ? 'in your words'
                  : 'you spoke for $spokenSeconds seconds',
            ),
            Label(timeOfDay),
          ],
        ),
        const SizedBox(height: 18),
        Quote(transcript),
        const SizedBox(height: 32),
        Text(
          line,
          style: const TextStyle(
            fontFamily: SoulType.serif,
            fontSize: 21,
            height: 1.35,
            letterSpacing: -0.21,
            color: SoulColors.text,
          ),
        ),
      ],
      footer: Column(
        children: [
          SoulButton('Look closer',
              kind: SoulButtonKind.filled, onPressed: onLookCloser),
          const SizedBox(height: 9),
          SoulButton('I am done', onPressed: onDone),
        ],
      ),
    );
  }
}
