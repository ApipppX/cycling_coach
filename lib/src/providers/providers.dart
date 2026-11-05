import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/app_database.dart';
import '../data/prefs.dart';
import '../core/coach_engine.dart';
import '../models/models.dart' as m;

final dbProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));

final activitiesProvider = StreamProvider<List<m.CyclingActivity>>((ref) {
  // Ringan: tanpa route_json. Rute lengkap diambil per-ID saat detail/edit.
  return ref.watch(dbProvider).watchActivitiesLite();
});

/// Satu sesi lengkap (termasuk rute GPS) untuk layar detail/edit.
/// autoDispose: rute besar tidak ditahan di memori setelah layar ditutup.
final activityByIdProvider =
    FutureProvider.autoDispose.family<m.CyclingActivity?, int>((ref, id) {
  return ref.watch(dbProvider).getActivityById(id);
});

final eventsProvider = StreamProvider<List<m.EventGoal>>((ref) {
  return ref.watch(dbProvider).watchEvents();
});

final planChecksProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(dbProvider).watchPlanChecks();
});

/// Analisis coach dihitung SEKALI per perubahan data dan dipakai ulang oleh
/// semua layar (Coach, Event). Sebelumnya tiap layar menghitung ulang di
/// setiap build — boros untuk riwayat ratusan sesi.
///
/// Catatan loading: saat stream DB masih loading/error, kembalikan analisis
/// kosong (bukan data basi). Layar wajib cek `activitiesProvider.isLoading`
/// dan tampilkan spinner via `AppLoading` agar tidak flash "Belum ada data".
final coachAnalysisProvider = Provider<CoachAnalysis>((ref) {
  final acts = ref.watch(activitiesProvider).value ?? [];
  final prefs = ref.watch(prefsProvider);
  final events = ref.watch(eventsProvider).value ?? [];
  return analyzeCoach(
      acts, prefs.maxHr, events.isEmpty ? null : events.first);
});
