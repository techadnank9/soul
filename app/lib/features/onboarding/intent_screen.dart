import 'package:flutter/material.dart';

import '../../theme/soul_theme.dart';
import 'onboarding_kit.dart';
import 'profile_fields.dart';

/// The two questions between signing in and home.
///
/// What part of life they want to look at, then why now. They come after
/// sign in rather than among the fourteen questions before it, because they
/// are the first thing asked of somebody who has an account rather than one
/// more thing to get through to reach one. The progress bar does not count
/// them for the same reason.
///
/// Both are one choice from a short list, and both lists end with a true way
/// to say nothing. A question everybody has to answer needs one, or what it
/// collects is whichever row was least wrong.
///
/// Nothing is scored, nothing is shown back, and neither answer is ever read
/// to somebody as a description of who they are. The area moves one theme to
/// the front of the week ring until their own entries have named one, and
/// that is the whole of what reads them today.
enum IntentStep { area, reason }

const intentAreas = <Choice>[
  Choice('school_or_work', 'School or work'),
  Choice('people_close', 'The people close to me'),
  Choice('sleep_and_food', 'How I sleep and eat'),
  Choice('my_time', 'What I do with my time'),
  Choice('avoiding', 'Something I keep avoiding'),
  Choice('not_sure', 'I am not sure yet'),
];

const intentReasons = <Choice>[
  Choice('keeps_happening', 'Something keeps happening and I want to see it'),
  Choice('still_in_it', 'Something happened and I am still in it'),
  Choice('want_to_see', 'I want to know what is going on with me'),
  Choice('no_reason', 'No reason in particular'),
];

/// One of the two, drawn with the same furniture as every other question.
///
/// It owns its own top edge, because the flow's progress bar stops at sign
/// in and a bar over these two would say there is more to get through.
class IntentQuestion extends StatelessWidget {
  const IntentQuestion({
    super.key,
    required this.step,
    required this.chosen,
    required this.onChoose,
    required this.onContinue,
    this.onBack,
  });

  final IntentStep step;
  final String? chosen;
  final ValueChanged<String?> onChoose;
  final VoidCallback onContinue;

  /// The question before this one. Null on the first, which has sign in
  /// behind it and nothing to go back to.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final options = switch (step) {
      IntentStep.area => intentAreas,
      IntentStep.reason => intentReasons,
    };

    return Scaffold(
      backgroundColor: SoulColors.bg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 22, 0),
              child: SizedBox(
                height: 40,
                child: onBack == null
                    ? null
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: onBack,
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.chevron_left,
                              size: 24, color: SoulColors.text2),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: QuestionScaffold(
                eyebrow: switch (step) {
                  IntentStep.area => 'Last thing',
                  IntentStep.reason => 'Last thing',
                },
                title: switch (step) {
                  IntentStep.area => 'What are you here to look at?',
                  IntentStep.reason => 'What brought you here?',
                },
                helper: switch (step) {
                  IntentStep.area =>
                    'It is not a plan and nothing is held to it. Pick the one '
                        'that is closest.',
                  IntentStep.reason => null,
                },
                ctaTitle: 'Continue',
                ctaEnabled: chosen != null,
                onContinue: onContinue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      OptionRow(
                        label: options[i].label,
                        selected: chosen == options[i].key,
                        dimmed: chosen != null && chosen != options[i].key,
                        onTap: () => onChoose(
                            chosen == options[i].key ? null : options[i].key),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
