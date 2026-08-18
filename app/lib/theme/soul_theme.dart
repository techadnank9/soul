import 'package:flutter/material.dart';

/// The palette and type scale from docs/screens.html. Every value here has a
/// counterpart in that file. Change both together.
abstract final class SoulColors {
  static const bg = Color(0xFF0C0C0B);
  static const s1 = Color(0xFF161615);
  static const s2 = Color(0xFF1F1F1D);
  static const s3 = Color(0xFF292926);
  static const border = Color(0xFF2E2E2A);
  static const border2 = Color(0xFF3D3D38);
  static const text = Color(0xFFF2F0EC);
  static const text2 = Color(0xFFA5A29A);
  static const text3 = Color(0xFF6E6B64);
  static const clay = Color(0xFFD85A30);
  static const clayDark = Color(0xFF7A3018);
  static const clayLight = Color(0xFFF0997B);
  static const amber = Color(0xFFEF9F27);
  static const violet = Color(0xFF7F77DD);
  static const moss = Color(0xFF639922);
}

abstract final class SoulType {
  static const serif = 'InstrumentSerif';
  static const sans = 'Inter';

  /// Serif at 17 points is the size named in task 0a. It is the size a student
  /// reads their own words back in, so it is the one the keyboard test is
  /// measured against.
  static const lead = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 1.65,
    fontWeight: FontWeight.w300,
    color: SoulColors.text,
  );

  static const secondary = TextStyle(
    fontFamily: sans,
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w300,
    color: SoulColors.text2,
  );

  static const muted = TextStyle(
    fontFamily: sans,
    fontSize: 12,
    letterSpacing: 0.24,
    fontWeight: FontWeight.w300,
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
    fontSize: 26,
    height: 1.35,
    letterSpacing: -0.26,
    color: SoulColors.text,
  );
}

ThemeData soulTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: SoulColors.bg,
    fontFamily: SoulType.sans,
    colorScheme: const ColorScheme.dark(
      surface: SoulColors.bg,
      primary: SoulColors.clay,
      onPrimary: SoulColors.text,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: SoulColors.clay,
      selectionColor: Color(0x33D85A30),
      selectionHandleColor: SoulColors.clay,
    ),
  );
}
