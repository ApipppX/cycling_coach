import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../models/models.dart' as m;

part 'app_database.g.dart';

@DataClassName('ActivityRow')
class CyclingActivities extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get distance => real()();
  RealColumn get totalElevationGain => real()();
  RealColumn get averageSpeed => real()();
  TextColumn get startDate => text()();
  RealColumn get averageHeartRate => real().withDefault(const Constant(0))();
  TextColumn get note => text().withDefault(const Constant(''))();
  // v6: rute GPS (JSON ringkas) + durasi real perekaman (detik).
  TextColumn get routeJson => text().withDefault(const Constant(''))();
  RealColumn get durationSec => real().withDefault(const Constant(0))();
}

@DataClassName('EventRow')
class EventGoals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get eventDate => text()();
  RealColumn get targetDistanceKm => real()();
  RealColumn get targetElevationM => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
}

@DataClassName('PlanCheckRow')
class PlanChecks extends Table {
  TextColumn get date => text()();
  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(tables: [CyclingActivities, EventGoals, PlanChecks])
class AppDatabase extends _$AppDatabase {
  // Web (Chrome/Edge) butuh `web:` berisi URI sqlite3.wasm +
  // drift_worker.js (di folder web/, dari release drift yang sama dengan
  // pubspec.lock). Tanpa ini web crash: "the `web` parameter needs to be
  // set". Di Android/iOS/desktop param `web` diabaikan (pakai file native).
  AppDatabase()
      : super(driftDatabase(
          name: 'cycling_coach_database',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v3 ke bawah belum punya kolom note.
          if (from < 4) {
            try {
              await m.addColumn(
                  cyclingActivities, cyclingActivities.note);
            } catch (_) {
              // Kolom sudah ada (upgrade parsial) — aman diabaikan.
            }
          }
          // v4 sempat punya kolom rpe — hapus, tidak dipakai lagi.
          // Dibungkus try agar upgrade loncat (v3->v5) tidak gagal
          // saat kolom rpe memang tidak pernah ada.
          if (from <= 4) {
            try {
              await m.dropColumn(cyclingActivities, 'rpe');
            } catch (_) {
              // Kolom tidak ada — bukan error.
            }
          }
          // v6: rute GPS + durasi real. addColumn dibungkus try agar
          // upgrade parsial / reinstall tidak crash.
          if (from < 6) {
            try {
              await m.addColumn(
                  cyclingActivities, cyclingActivities.routeJson);
            } catch (_) {}
            try {
              await m.addColumn(
                  cyclingActivities, cyclingActivities.durationSec);
            } catch (_) {}
          }
        },
      );

  Stream<List<m.CyclingActivity>> watchActivities() {
    return (select(cyclingActivities)..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .watch()
        .map((rows) => rows.map(_toActivity).toList());
  }

  Future<List<m.CyclingActivity>> getActivities() async {
    final rows = await (select(cyclingActivities)
          ..orderBy([(t) => OrderingTerm.desc(t.id)]))
        .get();
    return rows.map(_toActivity).toList();
  }

  m.CyclingActivity _toActivity(ActivityRow r) => m.CyclingActivity(
        id: r.id,
        name: r.name,
        distance: r.distance,
        totalElevationGain: r.totalElevationGain,
        averageSpeed: r.averageSpeed,
        startDate: r.startDate,
        averageHeartRate: r.averageHeartRate,
        note: r.note,
        routeJson: r.routeJson,
        durationSec: r.durationSec,
      );

  Future<int> upsertActivity(m.CyclingActivity a) {
    final c = CyclingActivitiesCompanion(
      id: a.id == 0 ? const Value.absent() : Value(a.id),
      name: Value(a.name),
      distance: Value(a.distance),
      totalElevationGain: Value(a.totalElevationGain),
      averageSpeed: Value(a.averageSpeed),
      startDate: Value(a.startDate),
      averageHeartRate: Value(a.averageHeartRate),
      note: Value(a.note),
      routeJson: Value(a.routeJson),
      durationSec: Value(a.durationSec),
    );
    return into(cyclingActivities).insertOnConflictUpdate(c);
  }

  Future<void> deleteActivity(m.CyclingActivity a) =>
      (delete(cyclingActivities)..where((t) => t.id.equals(a.id))).go();

  Future<void> clearActivities() => delete(cyclingActivities).go();

  Stream<List<m.EventGoal>> watchEvents() {
    return (select(eventGoals)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows
            .map((r) => m.EventGoal(
                id: r.id, name: r.name, eventDate: r.eventDate,
                targetDistanceKm: r.targetDistanceKm,
                targetElevationM: r.targetElevationM, createdAt: r.createdAt))
            .toList());
  }

  Future<List<m.EventGoal>> getEvents() async {
    final rows = await (select(eventGoals)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    return rows
        .map((r) => m.EventGoal(
            id: r.id,
            name: r.name,
            eventDate: r.eventDate,
            targetDistanceKm: r.targetDistanceKm,
            targetElevationM: r.targetElevationM,
            createdAt: r.createdAt))
        .toList();
  }

  /// Restore penuh dari backup: timpa semua data dalam satu transaksi.
  Future<void> restoreAll(
      List<m.CyclingActivity> activities, List<m.EventGoal> events) async {
    await transaction(() async {
      await delete(cyclingActivities).go();
      await delete(eventGoals).go();
      await delete(planChecks).go();
      for (final a in activities) {
        await into(cyclingActivities).insert(CyclingActivitiesCompanion(
          name: Value(a.name),
          distance: Value(a.distance),
          totalElevationGain: Value(a.totalElevationGain),
          averageSpeed: Value(a.averageSpeed),
          startDate: Value(a.startDate),
          averageHeartRate: Value(a.averageHeartRate),
          note: Value(a.note),
          routeJson: Value(a.routeJson),
          durationSec: Value(a.durationSec),
        ));
      }
      for (final e in events) {
        await into(eventGoals).insert(EventGoalsCompanion(
          name: Value(e.name),
          eventDate: Value(e.eventDate),
          targetDistanceKm: Value(e.targetDistanceKm),
          targetElevationM: Value(e.targetElevationM),
          createdAt: Value(e.createdAt),
        ));
      }
    });
  }

  Future<void> saveSingleEvent(m.EventGoal e) async {
    await delete(eventGoals).go();
    await delete(planChecks).go();
    await into(eventGoals).insert(EventGoalsCompanion(
      name: Value(e.name), eventDate: Value(e.eventDate),
      targetDistanceKm: Value(e.targetDistanceKm),
      targetElevationM: Value(e.targetElevationM),
      createdAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  Future<void> deleteEvent(m.EventGoal e) async {
    await (delete(eventGoals)..where((t) => t.id.equals(e.id))).go();
    await delete(planChecks).go();
  }

  Stream<Set<String>> watchPlanChecks() =>
      select(planChecks).watch().map((r) => r.map((e) => e.date).toSet());

  Future<void> togglePlanDay(String date, bool done) async {
    if (done) {
      await into(planChecks).insertOnConflictUpdate(PlanChecksCompanion(date: Value(date)));
    } else {
      await (delete(planChecks)..where((t) => t.date.equals(date))).go();
    }
  }

  Future<void> clearAll() async {
    await delete(cyclingActivities).go();
    await delete(eventGoals).go();
    await delete(planChecks).go();
  }
}
