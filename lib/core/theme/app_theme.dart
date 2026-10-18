import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Memora design system — Material 3, calm purple, light theme.
///
/// Two sub-themes:
///   [AppTheme.patientTheme]  — large text, high contrast, big touch targets.
///   [AppTheme.caregiverTheme] — compact, information-dense.
class AppTheme {
  AppTheme._();

  // Compatibility for existing screens until their feature phase.
  static const textPrimary = onSurface;
  static const textSecondary = onSurfaceMid;
  static const accent = warning;
  static const bgGradient = LinearGradient(colors: [background, background]);
  static const primaryGradient = LinearGradient(colors: [primaryDark, primaryDark]);

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color primary = AppColors.primary;
  static const Color primaryLight = AppColors.secondaryAccent;
  static const Color primaryDark = AppColors.primary;
  static const Color secondary = AppColors.secondaryAccent;
  static const Color background = AppColors.background;
  static const Color surface = AppColors.surface;
  static const Color surfaceVar = AppColors.primaryContainer;
  static const Color onSurface = AppColors.text;
  static const Color onSurfaceMid = AppColors.secondaryText;
  static const Color onSurfaceLow = AppColors.disabled;
  static const Color success = AppColors.success;
  static const Color warning = AppColors.warning;
  static const Color error = AppColors.emergency;
  static const Color errorSurface = AppColors.emergencySurface;

  // ── Spacing ────────────────────────────────────────────────────────────────
  static const double sp4  = 4;
  static const double sp8  = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // ── Radius ─────────────────────────────────────────────────────────────────
  static const double radiusCard   = 20;
  static const double radiusButton = 14;
  static const double radiusChip   = 32;
  static const double radiusInput  = 12;

  // ── Shadows ────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: AppColors.shadow.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ── Text styles (caregiver scale) ─────────────────────────────────────────
  static TextStyle heading1(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w700, color: onSurface);
  static TextStyle heading2(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: onSurface);
  static TextStyle body(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 16, color: onSurface);
  static TextStyle bodySmall(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 13, color: onSurfaceMid);
  static TextStyle label(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: onSurfaceMid);

  // ── Text styles (patient scale — large, accessible) ───────────────────────
  static TextStyle patientHeading(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: onSurface);
  static TextStyle patientBody(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 24, color: onSurface);
  static TextStyle patientLabel(BuildContext context) =>
      GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: onSurfaceMid);

  // ── Base ThemeData ─────────────────────────────────────────────────────────
  static ThemeData _base() {
    final colorScheme = const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.text,
      secondary: AppColors.secondaryAccent,
      onSecondary: AppColors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      outline: AppColors.outline,
      error: AppColors.emergency,
      onError: AppColors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        bodyLarge: GoogleFonts.outfit(fontSize: 16, color: onSurface),
        bodyMedium: GoogleFonts.outfit(fontSize: 16, color: onSurface),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shadowColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVar,
        hintStyle: TextStyle(color: onSurfaceLow, fontSize: 15),
        labelStyle: TextStyle(color: onSurfaceMid),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: onSurfaceLow.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: BorderSide(color: onSurfaceLow.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: error, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusButton),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: GoogleFonts.outfit(color: AppColors.white, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: AppColors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceLow,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primaryContainer,
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: AppColors.primary)),
        labelTextStyle: WidgetStatePropertyAll(TextStyle(color: AppColors.text)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.disabled,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryContainer
              : AppColors.outline,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: onSurfaceLow.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Standard caregiver theme.
  static ThemeData get caregiverTheme => _base();

  /// Patient theme — larger text, bigger touch targets, high contrast.
  static ThemeData get patientTheme => _base().copyWith(
        textTheme: GoogleFonts.outfitTextTheme().copyWith(
          bodyLarge: GoogleFonts.outfit(fontSize: 24, color: onSurface),
          bodyMedium: GoogleFonts.outfit(fontSize: 24, color: onSurface),
          bodySmall: GoogleFonts.outfit(fontSize: 24, color: onSurface),
          titleLarge: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w700, color: onSurface),
          titleMedium: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w600, color: onSurface),
          labelLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: AppColors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(64),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusButton),
            ),
            textStyle: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            minimumSize: const Size(64, 64),
            textStyle: const TextStyle(fontSize: 24),
          ),
        ),
      );
}
