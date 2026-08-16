import 'package:flutter/material.dart';

class RechargeTheme {
  const RechargeTheme._();

  // Home hero gradient: top stop now uses the canonical brand green
  // (#0B3028) instead of the old #064936; middle/bottom stops unchanged.
  static const Color homeBackgroundTop = Color(0xFF0B3028);
  static const Color homeBackground = Color(0xFF003F32);
  static const Color homeBackgroundBottom = Color(0xFF002C25);
  static const Color homeMuted = Color(0xFFAFC3BC);
  static const Color homeCategorySurface = Color(0xFF255246);
  static const Color homeTag = Color(0xFF60736D);
  static const double homeCardRadius = 12;
  static const double homePillRadius = 28;

  /// Canonical brand color per AGENTS.md ("Основной цвет: #0B3028").
  static const Color emerald900 = Color(0xFF0B3028);
  static const Color emerald700 = Color(0xFF0E6A57);
  static const Color mint100 = Color(0xFFDDF3EB);
  static const Color mint50 = Color(0xFFF4F8F5);
  static const Color ink = Color(0xFF10231F);
  static const Color mutedInk = Color(0xFF62756F);
  static const Color lime = Color(0xFFD7F55C);
  static const Color travelGreen = Color(0xFF2F8F2F);
  static const Color travelGreenDark = Color(0xFF1F6F27);
  static const Color travelCanvas = Color(0xFFF1F2EE);
  static const Color travelPanel = Color(0xFFF7F8F4);
  static const Color travelLine = Color(0xFFD9DED5);
  static const Color sky = Color(0xFF2F6BFF);
  static const Color warmGold = Color(0xFFE6B84E);
  static const Color profileBackground = Color(0xFFF6F8F5);
  static const Color profileSurface = Colors.white;
  static const Color profileBorder = Color(0xFFE4EAE5);
  static const Color profileMuted = Color(0xFF6A7771);
  static const Color profileAccent = emerald900;
  static const double profileCardRadius = 16;
  static const double profileCompactRadius = 12;

  /// Neutral "soft gray" surface used for unselected pills/chips and
  /// secondary controls in the create-flow visual language.
  static const Color createSoftGray = Color(0xFFEEF0EC);
  static const Color createSoftGrayLine = Color(0xFFE1E5DE);
  static const double createPillRadius = 999;
  static const double createSectionRadius = 20;

  static ThemeData light() {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: emerald900,
      onPrimary: Colors.white,
      primaryContainer: mint100,
      onPrimaryContainer: emerald900,
      secondary: emerald700,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE8F4EF),
      onSecondaryContainer: emerald900,
      tertiary: warmGold,
      onTertiary: ink,
      tertiaryContainer: Color(0xFFFFF2CB),
      onTertiaryContainer: ink,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Colors.white,
      onSurface: ink,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFF9FCFA),
      surfaceContainer: travelCanvas,
      surfaceContainerHigh: Color(0xFFEAF3EF),
      surfaceContainerHighest: Color(0xFFDDE9E4),
      onSurfaceVariant: mutedInk,
      outline: Color(0xFFB8C9C2),
      outlineVariant: Color(0xFFD8E7E1),
      shadow: Color(0x33003F32),
      scrim: Colors.black,
      inverseSurface: ink,
      onInverseSurface: Colors.white,
      inversePrimary: mint100,
    );

    final TextTheme textTheme = _zeroLetterSpacing(
      Typography.blackMountainView.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: travelCanvas,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: emerald900,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: travelLine),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald900,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFB8C9C2),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(48, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: emerald900,
          minimumSize: const Size(48, 46),
          side: const BorderSide(color: Color(0xFFB8C9C2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: emerald900,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD8E7E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD8E7E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: emerald900, width: 1.4),
        ),
        labelStyle: const TextStyle(color: mutedInk),
        hintStyle: const TextStyle(color: mutedInk),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? emerald900
                : mutedInk,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? emerald900
                : mutedInk,
            size: 24,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: mint100,
        disabledColor: const Color(0xFFEAF3EF),
        labelStyle: const TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(
          color: emerald900,
          fontWeight: FontWeight.w700,
        ),
        side: const BorderSide(color: Color(0xFFD8E7E1)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: emerald900,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFDDE9E4),
        thickness: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: emerald900,
        textColor: ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  static TextTheme _zeroLetterSpacing(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(letterSpacing: 0),
      displayMedium: textTheme.displayMedium?.copyWith(letterSpacing: 0),
      displaySmall: textTheme.displaySmall?.copyWith(letterSpacing: 0),
      headlineLarge: textTheme.headlineLarge?.copyWith(letterSpacing: 0),
      headlineMedium: textTheme.headlineMedium?.copyWith(letterSpacing: 0),
      headlineSmall: textTheme.headlineSmall?.copyWith(letterSpacing: 0),
      titleLarge: textTheme.titleLarge?.copyWith(letterSpacing: 0),
      titleMedium: textTheme.titleMedium?.copyWith(letterSpacing: 0),
      titleSmall: textTheme.titleSmall?.copyWith(letterSpacing: 0),
      bodyLarge: textTheme.bodyLarge?.copyWith(letterSpacing: 0),
      bodyMedium: textTheme.bodyMedium?.copyWith(letterSpacing: 0),
      bodySmall: textTheme.bodySmall?.copyWith(letterSpacing: 0),
      labelLarge: textTheme.labelLarge?.copyWith(letterSpacing: 0),
      labelMedium: textTheme.labelMedium?.copyWith(letterSpacing: 0),
      labelSmall: textTheme.labelSmall?.copyWith(letterSpacing: 0),
    );
  }
}
