import 'package:flutter/material.dart';

/// Sukkar Plus design tokens. Calm teal on cool white surfaces, navy ink,
/// one family (IBM Plex Sans Arabic). See docs/DESIGN_SYSTEM.md.
abstract final class SpColors {
  static const background = Color(0xFFF3F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7FAFA);
  static const border = Color(0xFFE2E9EC);

  static const teal = Color(0xFF17958C);
  static const tealDeep = Color(0xFF0D6C66);
  static const tealSoft = Color(0xFFE3F3F1);

  static const ink = Color(0xFF1C2A35);
  static const inkSecondary = Color(0xFF55636E);
  static const inkMuted = Color(0xFF85939D);

  /// Taupe notice card (the reference layout's weather-card slot).
  static const notice = Color(0xFF8A7261);
  static const noticeDeep = Color(0xFF6E5A4C);

  // Status (always shown with an icon and a label, never colour alone).
  static const info = Color(0xFF17958C);
  static const infoSoft = Color(0xFFE3F3F1);
  static const warning = Color(0xFF9A6A00);
  static const warningSoft = Color(0xFFFFF4DA);
  static const critical = Color(0xFFB23A3A);
  static const criticalSoft = Color(0xFFFBE9E7);
  static const neutral = Color(0xFF55636E);
  static const neutralSoft = Color(0xFFEDF1F3);

  /// Demo banner.
  static const demo = Color(0xFF7A4E00);
  static const demoSoft = Color(0xFFFFF1CC);

  // Glucose range bands — validated for CVD separation and 3:1 contrast on
  // white (dataviz validator). Always paired with text labels and values.
  static const bandVeryLow = Color(0xFFA32E4E);
  static const bandLow = Color(0xFFE0704E);
  static const bandInRange = Color(0xFF0089B8);
  static const bandHigh = Color(0xFFB98200);
  static const bandVeryHigh = Color(0xFF97470F);

  // Trend chart series (validated pair).
  static const seriesLab = Color(0xFF17958C);
  static const seriesGmi = Color(0xFFB98200);
}

abstract final class SpSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const page = 16.0;
}

abstract final class SpRadius {
  static const card = 16.0;
  static const inner = 12.0;
  static const chip = 999.0;
  static const field = 14.0;
}

abstract final class SpShadow {
  static const card = [BoxShadow(color: Color(0x0F1C2A35), blurRadius: 12, offset: Offset(0, 3))];
}

const spFontFamily = 'IBMPlexSansArabic';
