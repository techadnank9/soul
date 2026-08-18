import 'package:flutter/material.dart';
import '../theme/soul_theme.dart';

/// Fixed sample content for the shell.
///
/// Nothing here is generated and nothing here is stored. Every string is the
/// copy from docs/screens.html, so the screens can be walked and reacted to
/// before the API exists. This file is deleted at task 6, when real entries
/// start arriving.
abstract final class Sample {
  static const transcript =
      'I almost quit today. He took credit for the whole thing in front of '
      'everyone and I typed out a resignation email and just sat there and '
      'did not send it.';

  static const beatOne =
      'You wrote the email and you did not send it. That gap is worth a minute.';

  static const tension =
      'Wanting to be seen for the work, and wanting to stay somewhere that '
      'just did not see you.';

  static const underneath =
      'This may have landed as being erased rather than being annoyed. '
      'Does that fit?';

  static const question = 'What stopped you from sending it?';

  static const heldDecision = 'Talk to him directly before Friday';

  static const themes = <ThemeSlice>[
    ThemeSlice('Self doubt', 4, SoulColors.clay),
    ThemeSlice('Overwhelm', 3, SoulColors.amber),
    ThemeSlice('Comparison', 2, SoulColors.violet),
    ThemeSlice('Compassion', 3, SoulColors.moss),
  ];

  static const week = <Color?>[
    null,
    SoulColors.clay,
    Color(0xFF7A3018),
    SoulColors.amber,
    SoulColors.moss,
    null,
    null,
  ];

  static const day = <Moment>[
    Moment('Took the extra project without thinking', 'overwhelm',
        SoulColors.violet, 'you noticed this one'),
    Moment('A tense call after lunch', 'shorter answers than usual',
        SoulColors.amber, null),
    Moment('He took credit and I went quiet', 'self doubt', SoulColors.clay,
        null),
    Moment('Told my sister and felt lighter', 'compassion', SoulColors.moss,
        null),
  ];

  static const patterns = <Pattern>[
    Pattern('Going quiet when not credited', '3 times, most recently last week',
        SoulColors.clay, [1, 5, 9]),
    Pattern('Saying yes when already full', '5 times', SoulColors.amber,
        [0, 2, 4, 7, 10]),
    Pattern('Steadier after you name it out loud', '4 times', SoulColors.moss,
        [2, 5, 7, 10]),
  ];
}

class ThemeSlice {
  const ThemeSlice(this.name, this.count, this.color);
  final String name;
  final int count;
  final Color color;
}

class Moment {
  const Moment(this.what, this.note, this.color, this.tag);
  final String what;
  final String note;
  final Color color;
  final String? tag;
}

class Pattern {
  const Pattern(this.name, this.detail, this.color, this.marks);
  final String name;
  final String detail;
  final Color color;
  final List<int> marks;
}
