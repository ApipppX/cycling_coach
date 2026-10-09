import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/core/track_service.dart';
import 'src/data/app_database.dart';
import 'src/data/prefs.dart';
import 'src/providers/providers.dart';
import 'src/ui/app.dart';

void main() async {
  // Tahan splash oranye selama init (prefs + buka DB) agar tidak ada
  // layar hitam/putih yang bikin user mengira "home tidak muncul".
  final widgetsBinding =
      WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase();
  // Siapkan foreground service agar GPS tetap jalan saat layar mati
  // (Android/iOS saja; web/desktop diabaikan).
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    try {
      await initializeTrackService();
    } catch (_) {}
  }
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
