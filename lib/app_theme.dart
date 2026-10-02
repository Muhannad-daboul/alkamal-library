import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand colors (from guidelines)
  static const primary = Color(0xFF00827E); // PANTONE 7717 C
  static const primaryDark = Color(0xFF004438); // PANTONE 3308 C
  static const primaryLight = Color(0xFF00AFAA); // PANTONE 326 C
  static const lightGray = Color(0xFFD8DFE1); // PANTONE 7541 C

  // Dark mode surfaces — derived from brand dark green
  static const _darkBg = Color(0xFF0A1B1A);
  static const _darkSurface = Color(0xFF122E2C);
  static const _darkCard = Color(0xFF1A3D3A);

  // ── Light ──────────────────────────────────────────────
  static ThemeData get lightTheme {
    final text = GoogleFonts.tajawalTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: primaryLight,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4FAFA),
      textTheme: text,
      appBarTheme: _appBarTheme(primary, GoogleFonts.tajawal),
      elevatedButtonTheme: _elevatedBtn(primary),
      outlinedButtonTheme: _outlinedBtn(primary),
      cardTheme: _cardTheme(Colors.white),
      tabBarTheme: _tabBarTheme(primary),
      drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
      navigationBarTheme: _navBarTheme(Colors.white, primary),
    );
  }

  // ── Dark ───────────────────────────────────────────────
  static ThemeData get darkTheme {
    final text = GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: primary,
        surface: _darkSurface,
      ),
      scaffoldBackgroundColor: _darkBg,
      textTheme: text,
      appBarTheme: _appBarTheme(primaryDark, GoogleFonts.tajawal),
      elevatedButtonTheme: _elevatedBtn(primaryLight),
      outlinedButtonTheme: _outlinedBtn(primaryLight),
      cardTheme: _cardTheme(_darkCard),
      tabBarTheme: _tabBarTheme(primaryLight),
      drawerTheme: const DrawerThemeData(backgroundColor: _darkSurface),
      navigationBarTheme: _navBarTheme(_darkSurface, primaryLight),
    );
  }

  // ── Shared builders ────────────────────────────────────
  static AppBarTheme _appBarTheme(Color bg, Function fontFn) => AppBarTheme(
    backgroundColor: bg,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: fontFn(
      color: Colors.white,
      fontSize: 18.0,
      fontWeight: FontWeight.w700,
    ),
  );

  static ElevatedButtonThemeData _elevatedBtn(Color color) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.tajawal(
            fontWeight: FontWeight.w600,
            fontSize: 16.0,
          ),
        ),
      );

  static OutlinedButtonThemeData _outlinedBtn(Color color) =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );

  static CardThemeData _cardTheme(Color color) => CardThemeData(
    elevation: 3,
    color: color,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
    ),
  );

  static TabBarThemeData _tabBarTheme(Color color) => TabBarThemeData(
    labelColor: color,
    unselectedLabelColor: Colors.grey,
    indicatorColor: color,
    labelStyle: GoogleFonts.tajawal(
      fontWeight: FontWeight.w700,
      fontSize: 14.0,
    ),
    unselectedLabelStyle: GoogleFonts.tajawal(
      fontWeight: FontWeight.w500,
      fontSize: 14.0,
    ),
  );

  static NavigationBarThemeData _navBarTheme(Color bg, Color indicator) =>
      NavigationBarThemeData(
        backgroundColor: bg,
        indicatorColor: indicator.withAlpha(35),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.tajawal(fontSize: 12.0, fontWeight: FontWeight.w600),
        ),
      );
}

/// اختصارات ألوان دلالية تتأقلم مع الوضع الفاتح/الداكن.
/// استعملها بدل الألوان الثابتة (Colors.white / Colors.black54 ...).
extension AppColors on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;

  /// خلفية البطاقات والحاويات (أبيض في الفاتح، سطح داكن في الداكن)
  Color get cSurface => _cs.surface;

  /// خلفية الشاشة العامة
  Color get cBackground => Theme.of(this).scaffoldBackgroundColor;

  /// نص أساسي قوي (بديل Colors.black87)
  Color get cText => _cs.onSurface;

  /// نص ثانوي مكتوم (بديل Colors.black54)
  Color get cMuted => _cs.onSurface.withValues(alpha: 0.62);

  /// نص خافت جداً (بديل Colors.black45 / black38)
  Color get cFaint => _cs.onSurface.withValues(alpha: 0.40);

  /// تعبئة خفيفة / فواصل (بديل grey.shade100/200)
  Color get cFill => _cs.onSurface.withValues(alpha: 0.06);
}
