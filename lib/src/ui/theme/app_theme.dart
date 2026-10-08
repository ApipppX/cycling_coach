import 'package:flutter/material.dart';

/// Design system ala Strava untuk CyclingCoach.
///
/// Ciri Strava yang ditiru:
/// - Primary oranye menyala (#FC4C02) di atas netral abu terang/gelap.
/// - Background feed abu muda (#F1F1F4), kartu putih, border tipis.
/// - Dark mode abu arang (#131315), bukan AMOLED hitam pekat.
/// - Radius kartu 16, tombol 12, chip pill 99.
/// - Judul tegas w800, angka tabular, label seksi kecil uppercase.
/// - Input filled abu + padding lega (18 vertikal) agar label tidak kepotong.
class AppColors {
  /// Oranye Strava.
  static const stravaOrange = Color(0xFFFC4C02);
  static const stravaOrangeDark = Color(0xFFE34402);

  static const lightScaffold = Color(0xFFF1F1F4);
  static const lightCard = Colors.white;
  static const lightInput = Color(0xFFEDEDF0);
  static const lightContainer = Color(0xFFFFE8DC);

  static const darkScaffold = Color(0xFF131315);
  static const darkCard = Color(0xFF1E1E21);
  static const darkInput = Color(0xFF26262B);
  static const darkContainer = Color(0xFF3A1E10);

  static const z5 = Color(0xFFFF3D00);
  static const z4 = Color(0xFFFF9100);
  static const z3 = Color(0xFF2979FF);
  static const z2 = Color(0xFF00C853);
  static const z1 = Color(0xFF9E9E9E);

  /// Semantic colors — dipakai lewat context.success/warning/error/info
  /// agar tidak ada Colors.green/red/orange hardcoded yang merusak
  /// dark mode & aksesibilitas.
  static const success = Color(0xFF1B9E4B);
  static const successDark = Color(0xFF4CC978);
  static const warning = Color(0xFFE47B00);
  static const warningDark = Color(0xFFFFB224);
  static const error = Color(0xFFD32F2F);
  static const errorDark = Color(0xFFFF6B6B);
  static const info = Color(0xFF2979FF);
  static const infoDark = Color(0xFF7BABFF);

  static Color zoneColor(String zone, ColorScheme scheme) => switch (zone) {
        'Z5' => z5,
        'Z4' => z4,
        'Z3' => z3,
        'Z2' => z2,
        _ => scheme.primary,
      };
}

class AppTheme {
  static const radius = 16.0;
  static const buttonRadius = 12.0;

  static InputDecorationTheme _inputTheme(
      Color fill, Color hint, Color label) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(color: hint, fontSize: 14),
      labelStyle: TextStyle(color: label, fontSize: 14),
      floatingLabelStyle:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      isDense: false,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide:
              const BorderSide(color: AppColors.stravaOrange, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.2)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide:
              const BorderSide(color: Colors.red, width: 1.5)),
    );
  }

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.stravaOrange,
          primary: AppColors.stravaOrange,
          onPrimary: Colors.white,
          primaryContainer: AppColors.lightContainer,
          onPrimaryContainer: const Color(0xFF7A2200),
          secondaryContainer: const Color(0xFFE9E9EC),
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.lightScaffold,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.3),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
                color: Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.stravaOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: Colors.white,
          indicatorColor: AppColors.lightContainer,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.lightContainer,
          selectedIconTheme:
              IconThemeData(color: AppColors.stravaOrange),
          selectedLabelTextStyle:
              TextStyle(color: AppColors.stravaOrange),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: AppColors.stravaOrange,
          foregroundColor: Colors.white,
          extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(16))),
        ),
        inputDecorationTheme: _inputTheme(
          AppColors.lightInput,
          Colors.black38,
          Colors.black54,
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor:
              const WidgetStatePropertyAll(Colors.white),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
              side: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06)))),
          hintStyle: const WidgetStatePropertyAll(
              TextStyle(color: Colors.black38, fontSize: 14)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          borderRadius: BorderRadius.all(Radius.circular(99)),
          linearMinHeight: 8,
          color: AppColors.stravaOrange,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99)),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20))),
        ),
        textTheme: const TextTheme(
          displayMedium: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: Colors.black),
          headlineSmall: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.black),
          titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.black),
          titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black),
          titleSmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.black54),
          bodySmall: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.stravaOrange,
          primary: AppColors.stravaOrange,
          onPrimary: Colors.white,
          primaryContainer: AppColors.darkContainer,
          onPrimaryContainer: const Color(0xFFFFB59B),
          brightness: Brightness.dark,
          surface: AppColors.darkCard,
        ),
        scaffoldBackgroundColor: AppColors.darkScaffold,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF1E1E21),
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: AppColors.darkCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.stravaOrange,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(buttonRadius)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 72,
          backgroundColor: const Color(0xFF1E1E21),
          indicatorColor: AppColors.darkContainer,
          labelTextStyle: WidgetStateProperty.all(const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white)),
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: Color(0xFF1E1E21),
          indicatorColor: AppColors.darkContainer,
          selectedIconTheme:
              IconThemeData(color: AppColors.stravaOrange),
          selectedLabelTextStyle:
              TextStyle(color: AppColors.stravaOrange),
        ),
        floatingActionButtonTheme:
            const FloatingActionButtonThemeData(
          backgroundColor: AppColors.stravaOrange,
          foregroundColor: Colors.white,
          extendedTextStyle: TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(16))),
        ),
        inputDecorationTheme: _inputTheme(
          AppColors.darkInput,
          Colors.white38,
          Colors.white60,
        ),
        searchBarTheme: SearchBarThemeData(
          backgroundColor:
              const WidgetStatePropertyAll(Color(0xFF1E1E21)),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(buttonRadius),
              side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08)))),
          hintStyle: const WidgetStatePropertyAll(
              TextStyle(color: Colors.white38, fontSize: 14)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          borderRadius: BorderRadius.all(Radius.circular(99)),
          linearMinHeight: 8,
          color: AppColors.stravaOrange,
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(99)),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding:
              EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.darkCard,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20))),
        ),
        textTheme: const TextTheme(
          displayMedium: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: Colors.white),
          headlineSmall: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white),
          titleLarge: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white),
          titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white),
          titleSmall: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: Colors.white60),
          bodySmall: TextStyle(fontSize: 12, color: Colors.white60),
        ),
      );
}

/// Jarak konsisten antar-elemen (dipakai semua halaman).
/// Skala 4px: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32.
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radius konsisten.
class AppRadius {
  static const double sm = 8;
  static const double card = 16;
  static const double button = 12;
  static const double pill = 99;
}

/// Ukuran sentuh & tinggi komponen (aksesibilitas: min 44-48).
class AppSizes {
  static const double touchMin = 44;
  static const double touchComfort = 48;
  static const double buttonHeight = 52;
  static const double buttonHeightLarge = 54;
  static const double inputHeight = 56;
  static const double avatarSm = 40;
  static const double avatarMd = 48;
}

/// Durasi animasi — cepat & subtle (tidak mengganggu navigasi).
class AppDurations {
  static const fast = Duration(milliseconds: 200);
  static const medium = Duration(milliseconds: 350);
  static const slow = Duration(milliseconds: 800);
}

/// Helper semantik warna per-theme (hindari hardcoded Colors.x).
extension SemanticColors on BuildContext {
  bool get _isDark =>
      Theme.of(this).brightness == Brightness.dark;
  Color get success =>
      _isDark ? AppColors.successDark : AppColors.success;
  Color get warning =>
      _isDark ? AppColors.warningDark : AppColors.warning;
  Color get danger =>
      _isDark ? AppColors.errorDark : AppColors.error;
  Color get infoColor =>
      _isDark ? AppColors.infoDark : AppColors.info;
}
