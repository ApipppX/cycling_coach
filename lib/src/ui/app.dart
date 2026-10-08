import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/prefs.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_shell.dart';

class CyclingCoachApp extends ConsumerWidget {
  const CyclingCoachApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    return MaterialApp(
      title: 'CyclingCoach',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: prefs.themeMode == 1
          ? ThemeMode.light
          : prefs.themeMode == 2
              ? ThemeMode.dark
              : ThemeMode.system,
      home: prefs.onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}
