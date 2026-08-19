import 'package:flutter/material.dart';

/// The palette and type scale from docs/screens.html. Every value here has a
/// counterpart in that file. Change both together.
abstract final class SoulColors {
  /// An elevation scale, not a set of near identical blacks.
  ///
  /// The first version sat at four percent lightness with cards three percent
  /// above it, so nothing separated and the whole app read as one flat sheet.
  /// The base is now around seven percent with real steps above it. Every
  /// surface keeps a warm undertone, because the accents are clay and amber and
  /// a cool grey underneath them reads as cheap.
  static const bg = Color(0xFF121110);
  static const s1 = Color(0xFF1B1A18);
  static const s2 = Color(0xFF232120);
  static const s3 = Color(0xFF2E2B28);
  static const border = Color(0xFF322F2B);
  static const border2 = Color(0xFF454039);

  /// A one pixel warm highlight along the top of a raised surface. On a dark
  /// interface shadows do almost nothing, so light does the lifting instead.
  static const lift = Color(0x0DFFFFFF);
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
