import 'package:flutter/material.dart';

const Color violet = Color(0xFF8E2DE2);
const Color rose = Color(0xFFFF4E8E);
const Color fond = Color(0xFF0E0B16);
const Color surface = Color(0xFF1A1526);

/// Surface un peu plus claire (champs, cartes en relief).
const Color surfaceHaute = Color(0xFF241D35);

/// Rouge des actions destructives (supprimer).
const Color danger = Color(0xFFFF6B6B);

/// Police des grands titres (logo, en-têtes).
const String policeTitre = 'Righteous';

const LinearGradient degradeCka = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [violet, rose],
);

ThemeData themeCka() {
  final schema =
      ColorScheme.fromSeed(
        seedColor: violet,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFF5FA2),
        onPrimary: Colors.white,
        surface: surface,
        surfaceContainerHigh: surfaceHaute,
        error: danger,
      );

  final arrondi = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Poppins',
    brightness: Brightness.dark,
    colorScheme: schema,
    scaffoldBackgroundColor: fond,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    // Onglets en « pilules » : plus lisibles et plus faciles à toucher.
    tabBarTheme: TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            violet.withValues(alpha: 0.55),
            rose.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 18),
      overlayColor: WidgetStatePropertyAll(
        Colors.white.withValues(alpha: 0.06),
      ),
      splashBorderRadius: BorderRadius.circular(20),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Colors.white70,
      minVerticalPadding: 8,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: schema.primary,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayColor: schema.primary.withValues(alpha: 0.2),
      trackHeight: 3.5,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surface,
      showDragHandle: true,
      dragHandleColor: Colors.white24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Colors.white70,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surfaceHaute,
      surfaceTintColor: Colors.transparent,
      shape: arrondi,
      elevation: 8,
    ),
    // Le menu « Trier » (MenuAnchor) a le même aspect que les autres menus.
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(surfaceHaute),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(arrondi),
        elevation: const WidgetStatePropertyAll(8),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceHaute,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceHaute,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: schema.primary, width: 1.6),
      ),
      helperStyle: const TextStyle(color: Colors.white54),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: arrondi,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: arrondi,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white24),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        minimumSize: const Size(0, 44),
        selectedBackgroundColor: schema.primary.withValues(alpha: 0.22),
        selectedForegroundColor: Colors.white,
        foregroundColor: Colors.white70,
        side: const BorderSide(color: Colors.white12),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(Colors.white.withValues(alpha: 0.28)),
    ),
  );
}
