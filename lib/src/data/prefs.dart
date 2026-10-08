import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

class PrefsState {
  final double weeklyTargetKm;
  final int maxHr;
  final String userName;
  final int userAge;
  final double weightKg;
  final int themeMode; // 0 system, 1 light, 2 dark
  final bool onboarded;
  const PrefsState({
    this.weeklyTargetKm = 100, this.maxHr = 185,
    this.userName = '', this.userAge = 20, this.weightKg = 70,
    this.themeMode = 0, this.onboarded = false,
  });
  PrefsState copyWith({double? weeklyTargetKm, int? maxHr, String? userName, int? userAge, double? weightKg, int? themeMode, bool? onboarded}) =>
      PrefsState(
        weeklyTargetKm: weeklyTargetKm ?? this.weeklyTargetKm,
        maxHr: maxHr ?? this.maxHr,
        userName: userName ?? this.userName,
        userAge: userAge ?? this.userAge,
        weightKg: weightKg ?? this.weightKg,
        themeMode: themeMode ?? this.themeMode,
        onboarded: onboarded ?? this.onboarded,
      );
}

class PrefsNotifier extends Notifier<PrefsState> {
  SharedPreferences get _p => ref.read(sharedPrefsProvider);

  @override
  PrefsState build() {
    final p = ref.watch(sharedPrefsProvider);
    return PrefsState(
      weeklyTargetKm: p.getDouble('weekly_target_km') ?? 100,
      maxHr: p.getInt('max_hr') ?? 185,
      userName: p.getString('user_name') ?? '',
      userAge: p.getInt('user_age') ?? 20,
      weightKg: p.getDouble('weight_kg') ?? 70,
      themeMode: p.getInt('theme_mode') ?? 0,
      onboarded: p.getBool('has_onboarded') ?? false,
    );
  }

  void updateTarget(double v) {
    _p.setDouble('weekly_target_km', v);
    state = state.copyWith(weeklyTargetKm: v);
  }

  void updateMaxHr(int v) {
    final safe = v.clamp(140, 220);
    _p.setInt('max_hr', safe);
    state = state.copyWith(maxHr: safe);
  }

  void updateProfile(String name, int age) {
    final safeAge = age.clamp(10, 100);
    _p.setString('user_name', name.trim());
    _p.setInt('user_age', safeAge);
    final autoMax = (220 - safeAge).clamp(140, 220);
    _p.setInt('max_hr', autoMax);
    state = state.copyWith(userName: name.trim(), userAge: safeAge, maxHr: autoMax);
  }

  void updateWeight(double v) {
    final safe = v.clamp(30.0, 200.0).toDouble();
    _p.setDouble('weight_kg', safe);
    state = state.copyWith(weightKg: safe);
  }

  void updateTheme(int m) {
    _p.setInt('theme_mode', m.clamp(0, 2));
    state = state.copyWith(themeMode: m.clamp(0, 2));
  }

  void finishOnboarding(String name, int age) {
    updateProfile(name, age);
    _p.setBool('has_onboarded', true);
    state = state.copyWith(onboarded: true);
  }
}

final prefsProvider = NotifierProvider<PrefsNotifier, PrefsState>(PrefsNotifier.new);
