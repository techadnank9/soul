import 'package:flutter/material.dart';
import '../../theme/soul_theme.dart';
import 'onboarding_kit.dart';
import 'profile_fields.dart';
import 'profile_screen.dart';

/// After the introduction, before sign in. It says what was given, in the
/// person's own choices, and hands off to the one screen that asks for an
/// account.
///
/// Nothing on it is a result. The chips are the answers handed back as
/// they were given, and the sentence says where they went. It is here so
/// that fifteen questions land somewhere before one more is asked.
class ReadyScreen extends StatelessWidget {
  const ReadyScreen({
    super.key,
    required this.profile,
    required this.onContinue,
    this.line,
  });

  final Profile profile;
  final VoidCallback onContinue;

  /// Written from the answers just given, asked for when the baseline
  /// ended. Absent until it lands, and absent for good if it never does.
  final Future<String>? line;

  List<String> get _chips => [
        if (profile.displayName != null) profile.displayName!,
        ?labelFor(ageBands, profile.ageBand),
        if (profile.place != null)
          profile.place!
        else
          ?labelFor(regions, profile.region),
      ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          Settle(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'Your space is ready',
              style: SoulType.heading.copyWith(fontSize: 36, height: 1.1),
            ),
          ),
          const SizedBox(height: 20),
          // Room for three lines is held from the start, so nothing below
          // moves when the line arrives, and it may take more if it needs
          // them rather than being cut off.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 84),
            child: FutureBuilder<String>(
              future: line,
              builder: (context, snapshot) {
                final text = snapshot.data;
                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  opacity: text == null ? 0 : 1,
                  child: Text(
                    text ?? '',
                    style: const TextStyle(
                      fontFamily: SoulType.serif,
                      fontSize: 19,
                      height: 1.4,
                      color: SoulColors.text,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          // Ours, not the model's, so it is here whatever happened above it
          // and says the same thing to everybody.
          Settle(
            delay: const Duration(milliseconds: 300),
            child: Text(
              'From here the app fills in as you go, one moment at a time.',
              style: const TextStyle(
                fontFamily: SoulType.serif,
                fontSize: 19,
                height: 1.4,
                color: SoulColors.text2,
              ),
            ),
          ),
          if (_chips.isNotEmpty) ...[
            const SizedBox(height: 22),
            Settle(
              delay: const Duration(milliseconds: 360),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in _chips)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: SoulColors.border2),
                      ),
                      child: Text(
                        chip,
                        style: SoulType.muted.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: SoulColors.text2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const Spacer(),
          Settle(
            delay: const Duration(milliseconds: 500),
            child: PrimaryCta('Continue', onPressed: onContinue),
          ),
        ],
      ),
    );
  }
}
