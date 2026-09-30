import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final bodyFamily = GoogleFonts.beVietnamPro().fontFamily;
    return ThemeData(
      useMaterial3: true,
      fontFamily: bodyFamily,
      textTheme: GoogleFonts.beVietnamProTextTheme(),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: TextStyle(
            fontFamily: bodyFamily,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentTextStyle: TextStyle(
          fontFamily: bodyFamily,
          fontSize: 14,
          color: AppColors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: bodyFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return TextStyle(
            fontFamily: bodyFamily,
            fontSize: 11,
            color: AppColors.textGrey,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

/// Shared border-radius scale so cards, rows, chips, and panels draw from
/// one set of values instead of each screen picking its own arbitrary
/// number (an app-wide audit found 2/3/4/6/8/10/12/14/16/18/20/24 all in
/// use with no consistent rule).
class AppRadius {
  AppRadius._();
  static const chip = 10.0; // filter chips, small pills
  static const row = 14.0; // list rows, buttons, inputs, leading icon boxes
  static const panel = 20.0; // section/header cards, top-level panels
  static const pill = 28.0; // FAB-style floating pill buttons
}

// --- Box decoration helpers ---
class AppDecorations {
  AppDecorations._();

  // Clean white surface + soft shadow + hairline border. A pure-white
  // fill guarantees visible contrast against the app's warm-ivory page
  // background and against warm-tinted banners/chips no matter how
  // subtle any of those tints are — a tonal (colored-fill) card was tried
  // here and looked washed-out/undifferentiated against those neutrals,
  // so elevation is shown the reliable way: color contrast + a soft
  // shadow, the same language professional dashboard apps use.
  static final _cardBorder = Border.all(color: AppColors.border.withValues(alpha: 0.6));
  static final _cardShadow = <BoxShadow>[
    BoxShadow(
      color: AppColors.textDark.withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration get card => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.panel),
    border: _cardBorder,
    boxShadow: _cardShadow,
  );

  static BoxDecoration get cardSubtle => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.row + 2),
    border: _cardBorder,
    boxShadow: _cardShadow,
  );

  /// Same surface language as [card]/[cardSubtle] but sized for a single
  /// list row (product/store/employee rows, etc.).
  static BoxDecoration get row => BoxDecoration(
    color: AppColors.cardBg,
    borderRadius: BorderRadius.circular(AppRadius.row),
    border: _cardBorder,
    boxShadow: _cardShadow,
  );

  static BoxDecoration get cardFlat => BoxDecoration(
    color: AppColors.surfaceVariant,
    borderRadius: BorderRadius.circular(AppRadius.row),
  );

  /// Fully-rounded "pill" search bar — one consistent shape for every
  /// search field in the app instead of each screen picking its own
  /// radius on the default (14-radius) input field.
  static InputDecoration searchField(String hint, {Widget? suffixIcon}) => InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      );
}

class AppTextStyles {
  AppTextStyles._();

  // Display type — Fraunces, the serif used for headline titles and
  // numbers in the "Bi'S MART — Thiết kế mới" design (everything else
  // stays the app's default body sans, Be Vietnam Pro, inherited from
  // ThemeData.fontFamily).
  static final appTitle = GoogleFonts.fraunces(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static final sectionHeader = GoogleFonts.fraunces(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: -0.2,
  );

  static const bodyText = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const bodyTextMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textGrey,
    height: 1.4,
  );

  static const captionMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textGrey,
    height: 1.4,
  );

  static const linkOrange = TextStyle(
    fontSize: 14,
    color: AppColors.primary,
    fontWeight: FontWeight.w500,
  );

  static const nameHighlight = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  /// Small headline figure used in stat-row tiles (member counts, KPI
  /// scores, revenue) — same Fraunces display type as [appTitle]/[metric]
  /// but sized for a compact 3-up row instead of a full metric card.
  static final statValue = GoogleFonts.fraunces(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static final metric = GoogleFonts.fraunces(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    letterSpacing: -0.3,
    height: 1.1,
  );

  static const metricLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textGrey,
    letterSpacing: 0.3,
  );
}
