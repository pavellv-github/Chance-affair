import 'package:flutter/material.dart';

/// Палитра в духе референса: графит, оливково-бежевый, оранжевый акцент.
abstract final class AppColors {
  static const ink = Color(0xFF2B2B26);
  static const inkRaised = Color(0xFF37372F);
  static const sage = Color(0xFFD3D6BC);
  static const sageLight = Color(0xFFE3E4CE);
  static const cream = Color(0xFFFBF8E9);
  static const orange = Color(0xFFE8693A);
  static const onInk = Color(0xFFF4F2E4);
  static const onInkMuted = Color(0xFFA9A893);
  static const textDark = Color(0xFF22221E);
  static const textMuted = Color(0xFF6E6D5F);
  static const success = Color(0xFF5E8C4F);
}

abstract final class AppRadii {
  static const card = 22.0;
  static const panel = 28.0;
  static const pill = 100.0;
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.orange,
        onPrimary: Colors.white,
        surface: AppColors.ink,
        onSurface: AppColors.onInk,
        secondary: AppColors.sage,
        onSecondary: AppColors.textDark,
      );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ink,
  );

  final text = base.textTheme.apply(
    bodyColor: AppColors.onInk,
    displayColor: AppColors.onInk,
  );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.05,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.orange.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card - 6),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onInk,
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.onInkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card - 6),
        ),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inkRaised,
      labelStyle: const TextStyle(color: AppColors.onInkMuted),
      hintStyle: const TextStyle(color: AppColors.onInkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.onInkMuted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? AppColors.orange
            : AppColors.inkRaised,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.ink,
      indicatorColor: AppColors.orange,
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.onInkMuted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? AppColors.onInk
              : AppColors.onInkMuted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.cream,
      contentTextStyle: TextStyle(color: AppColors.textDark),
    ),
  );
}
