import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/data/app_database.dart';
import 'src/data/prefs.dart';
import 'src/providers/providers.dart';
import 'src/ui/app.dart';

void main() async {
  // Tahan splash oranye selama init (prefs + buka DB) agar tidak ada
  // layar hitam/putih yang bikin user mengira "home tidak muncul".
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Jaring pengaman: error async tak tertangani tidak boleh mematikan app.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled async error: $error\n$stack');
    return true;
  };

  // Widget yang gagal build diganti pesan ramah (bukan layar merah) di
  // release. Debug tetap menampilkan detail agar mudah dilacak.
  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFDF7F0),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Bagian ini gagal dimuat.\nSilakan kembali lalu buka lagi.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3A2E28),
              ),
            ),
          ),
        ),
      ),
    );
  };

  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  // Service GPS TIDAK diinisialisasi di sini: dulu cold start menunggu
  // plugin foreground service, membuat layar diam 5–9 dtk. Sekarang
  // disiapkan lazily saat tab Rekam / tombol Mulai dipakai.
  runApp(
    ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const CyclingCoachApp(),
    ),
  );
  FlutterNativeSplash.remove();
}
