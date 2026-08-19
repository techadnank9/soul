import 'package:flutter/material.dart';

/// The palette and type scale from docs/screens.html. Every value here has a
/// counterpart in that file. Change both together.
abstract final class SoulColors {
  /// Warm and light, with colour doing the work.
  ///
  /// The first two versions were near black and read as empty. The reference is
  /// Headspace: a cream ground, large saturated tiles as the primary surface,
  /// and generous rounding. Warmth in the surfaces, restraint in the words.
  static const bg = Color(0xFFFFF6EC);
  static const s1 = Color(0xFFFFFFFF);
  static const s2 = Color(0xFFFBEEE0);
  static const s3 = Color(0xFFF3E4D3);
  static const border = Color(0xFFEEE0CF);
  static const border2 = Color(0xFFDECBB4);

  static const text = Color(0xFF201B15);
  static const text2 = Color(0xFF6B6055);
  static const text3 = Color(0xFF9C9084);

  /// The four theme colours. Saturated enough to fill a tile, dark enough that
  /// white sits on them at an accessible contrast.
  static const clay = Color(0xFFEA5F17);
  static const clayDark = Color(0xFFB8460D);
  static const clayLight = Color(0xFFFFF0E6);
  static const amber = Color(0xFFE59200);
  static const violet = Color(0xFF5B4FD1);
  static const moss = Color(0xFF3F8B2E);

  /// A soft warm shadow. On a light interface this is what lifts a card, and it
  /// is warm rather than grey so it does not read as dirt.
  static const shade = Color(0x14A0693A);
  static const lift = Color(0x0DFFFFFF);
}

abstract final class SoulType {
  static const serif = 'InstrumentSerif';
  static const sans = 'Inter';

  /// Serif at 17 points is the size named in task 0a. It is the size a student
  /// reads their own words back in, so it is the one the keyboard test is
  /// measured against.
  static const lead = TextStyle(
    fontFamily: sans,
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: SoulColors.text,
  );

  static const secondary = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: SoulColors.text2,
  );

  static const muted = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    letterSpacing: 0.1,
    fontWeight: FontWeight.w400,
    color: SoulColors.text3,
  );

  static const field = TextStyle(
    fontFamily: serif,
    fontSize: 17,
    height: 1.45,
    color: SoulColors.text,
  );

  static const heading = TextStyle(
    fontFamily: serif,
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.5,
    color: SoulColors.text,
  );
}

ThemeData soulTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: SoulColors.bg,
    fontFamily: SoulType.sans,
    colorScheme: const ColorScheme.light(
      surface: SoulColors.bg,
      primary: SoulColors.clay,
      onPrimary: Colors.white,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SoulColors.clay,
      selectionColor: Color(0x33EA5F17),
      selectionHandleColor: SoulColors.clay,
    ),
  );
}
