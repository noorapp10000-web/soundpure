import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Palette ───────────────────────────────────────────────────────────── //
const Color kBg        = Color(0xFF080B14);
const Color kSurface   = Color(0xFF0F1526);
const Color kCard      = Color(0xFF141B2D);
const Color kBorder    = Color(0xFF1E2A42);
const Color kAccent    = Color(0xFF00C6FF);
const Color kAccent2   = Color(0xFF7B61FF);
const Color kSuccess   = Color(0xFF00E676);
const Color kError     = Color(0xFFFF4C6A);
const Color kWarning   = Color(0xFFFFB347);
const Color kText      = Color(0xFFE8EEFF);
const Color kTextSub   = Color(0xFF8A96B8);

// ── Gradients ─────────────────────────────────────────────────────────── //
const LinearGradient kBgGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF080B14), Color(0xFF0D1425), Color(0xFF080B14)],
);

const LinearGradient kAccentGradient = LinearGradient(
  colors: [Color(0xFF00C6FF), Color(0xFF7B61FF)],
);

const LinearGradient kCardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF141B2D), Color(0xFF0F1526)],
);

const LinearGradient kSuccessGradient = LinearGradient(
  colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
);

// ── Theme ─────────────────────────────────────────────────────────────── //
ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: kBg,
    colorScheme: const ColorScheme.dark(
      primary: kAccent,
      secondary: kAccent2,
      surface: kSurface,
      error: kError,
      onPrimary: kBg,
      onSurface: kText,
    ),
    textTheme: GoogleFonts.cairoTextTheme(
      ThemeData.dark().textTheme.copyWith(
        displayLarge: const TextStyle(
          fontSize: 32, fontWeight: FontWeight.w800, color: kText,
        ),
        displayMedium: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w700, color: kText,
        ),
        headlineMedium: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: kText,
        ),
        bodyLarge: const TextStyle(fontSize: 16, color: kText),
        bodyMedium: const TextStyle(fontSize: 14, color: kTextSub),
        labelLarge: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: kText,
        ),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: kText,
      centerTitle: true,
    ),
    dividerColor: kBorder,
  );
}
