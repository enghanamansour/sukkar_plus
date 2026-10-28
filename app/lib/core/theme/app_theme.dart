import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: SpColors.teal,
    primary: SpColors.teal,
    onPrimary: Colors.white,
    surface: SpColors.surface,
    onSurface: SpColors.ink,
    error: SpColors.critical,
  );
  const text = TextTheme(
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.3, color: SpColors.ink),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.35, color: SpColors.ink),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4, color: SpColors.ink),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45, color: SpColors.ink),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45, color: SpColors.ink),
    bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.65, color: SpColors.ink),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6, color: SpColors.ink),
    bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.55, color: SpColors.inkSecondary),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SpColors.ink),
    labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: SpColors.inkSecondary),
    labelSmall: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: SpColors.inkMuted),
  );
  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(SpRadius.field),
    borderSide: const BorderSide(color: SpColors.border),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: spFontFamily,
    textTheme: text,
    scaffoldBackgroundColor: SpColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: SpColors.background,
      foregroundColor: SpColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: spFontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: SpColors.ink),
    ),
    dividerTheme: const DividerThemeData(color: SpColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: SpColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: SpColors.teal, width: 1.6)),
      errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: SpColors.critical)),
      hintStyle: const TextStyle(color: SpColors.inkMuted, fontSize: 14),
      labelStyle: const TextStyle(color: SpColors.inkSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SpColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 48),
        textStyle: const TextStyle(fontFamily: spFontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.inner)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SpColors.tealDeep,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: SpColors.border),
        textStyle: const TextStyle(fontFamily: spFontFamily, fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.inner)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SpColors.tealDeep,
        textStyle: const TextStyle(fontFamily: spFontFamily, fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: SpColors.surface,
      indicatorColor: SpColors.tealSoft,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: spFontFamily,
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? SpColors.tealDeep : SpColors.inkMuted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? SpColors.tealDeep : SpColors.inkMuted,
            size: 24,
          )),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: SpColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: SpColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SpRadius.card)),
      titleTextStyle: const TextStyle(fontFamily: spFontFamily, fontSize: 18, fontWeight: FontWeight.w700, color: SpColors.ink),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: SpColors.ink),
    chipTheme: const ChipThemeData(side: BorderSide(color: SpColors.border), backgroundColor: SpColors.surface),
  );
}
