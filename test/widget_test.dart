import 'package:flutter_test/flutter_test.dart';
import 'package:cycling_coach/src/core/coach_engine.dart';
import 'package:cycling_coach/src/models/models.dart';
import 'package:cycling_coach/src/core/csv_utils.dart';
import 'package:cycling_coach/src/core/health_stats.dart';
import 'package:cycling_coach/src/core/backup.dart';
import 'package:cycling_coach/src/core/eta_predictor.dart';

String ymd(int daysAgo) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${p2(d.month)}-${p2(d.day)}T07:00:00Z';
}

void main() {
  test('weekKmOf + analyzeCoach empty', () {
    final a = analyzeCoach([], 185);
    expect(a.totalKm, 0);
    expect(a.todayType, PlanType.easy);
  });

  test('trimp without HR estimated from distance', () {
    final act = CyclingActivity(
      name: 'Easy', distance: 20000, totalElevationGain: 100,
      averageSpeed: 20 / 3.6, startDate: '2026-10-05T07:00:00Z',
    );
    expect(trimpOf(act, 185), 20 * 4.0);
  });

  test('csv roundtrip dengan catatan', () {
    final acts = [
      CyclingActivity(name: 'Pagi', distance: 25000, totalElevationGain: 150, averageSpeed: 25 / 3.6, startDate: '2026-10-04T07:00:00Z', averageHeartRate: 140, note: 'Enak, "kencang"'),
    ];
    final csv = buildActivitiesCsv(acts);
    final parsed = parseActivitiesCsv(csv);
    expect(parsed.activities.length, 1);
    expect(parsed.skipped, 0);
    expect(parsed.activities.first.note, contains('kencang'));
  });

  test('csv lama (7 & 9 kolom) tetap terbaca', () {
    const legacy7 = 'id,nama,tanggal,jarak_km,elevasi_m,kecepatan_kmh,hr_bpm\n,Gowes,2026-09-01,20.00,100,20.0,130\n';
    final p7 = parseActivitiesCsv(legacy7);
    expect(p7.activities.length, 1);
    expect(p7.activities.first.note, '');
    const legacy9 = 'id,nama,tanggal,jarak_km,elevasi_m,kecepatan_kmh,hr_bpm,rpe,catatan\n,Gowes,2026-09-01,20.00,100,20.0,130,5,Lama\n';
    final p9 = parseActivitiesCsv(legacy9);
    expect(p9.activities.length, 1);
    expect(p9.activities.first.note, 'Lama');
  });

  test('durationMin + estimasi kalori positif', () {
    final act = CyclingActivity(
      name: 'Ride', distance: 30000, totalElevationGain: 200,
      averageSpeed: 30 / 3.6, startDate: '2026-10-04T07:00:00Z',
      averageHeartRate: 150,
    );
    expect(act.durationMin, closeTo(60, 0.01));
    final kcal = estimateCaloriesKcal(act, 70);
    expect(kcal, greaterThan(300));
    expect(kcal, lessThan(2000));
  });

  test('backup JSON roundtrip', () {
    final acts = [
      CyclingActivity(name: 'Pagi', distance: 25000, totalElevationGain: 150, averageSpeed: 25 / 3.6, startDate: '2026-10-04T07:00:00Z', averageHeartRate: 140, note: 'Bagus'),
    ];
    final events = [
      EventGoal(name: 'Audax', eventDate: '2026-12-01', targetDistanceKm: 200, createdAt: 1),
    ];
    final json = exportBackupJson(
      activities: acts,
      events: events,
      prefs: {'weekly_target_km': 120.0, 'user_name': 'Budi'},
    );
    final back = importBackupJson(json);
    expect(back.skipped, 0);
    expect(back.activities.length, 1);
    expect(back.activities.first.note, 'Bagus');
    expect(back.events.length, 1);
    expect(back.prefs['user_name'], 'Budi');
  });

  test('backup invalid ditolak', () {
    final back = importBackupJson('{"version":2}');
    expect(back.activities, isEmpty);
    expect(back.skipped, greaterThan(0));
  });

  test('ETA aman saat di depan COT', () {
    // 50 km dalam 120 mnt = 25 km/h; sisa 50 km -> finis 240 mnt dari 480.
    final p = predictEta(
        targetKm: 100, currentKm: 50, elapsedMin: 120, cotMin: 480);
    expect(p.currentAvgKmh, closeTo(25, 0.01));
    expect(p.projectedTotalMin, closeTo(240, 0.01));
    expect(p.requiredAvgKmh, closeTo(50 / 6, 0.01)); // sisa 360 mnt
    expect(p.verdict, EtaVerdict.aman);
    expect(p.bufferMin, closeTo(240, 0.01));
    expect(p.checkpoints.last.km, 100);
  });

  test('ETA waspada saat mepet COT', () {
    // 80 km dalam 240 mnt = 20 km/h; proyeksi 300 dari COT 300.
    final p = predictEta(
        targetKm: 100, currentKm: 80, elapsedMin: 240, cotMin: 300);
    expect(p.projectedTotalMin, closeTo(300, 0.01));
    expect(p.verdict, EtaVerdict.waspada);
  });

  test('ETA over COT saat pace kurang', () {
    // 30 km dalam 180 mnt = 10 km/h; proyeksi 600 > COT 480.
    final p = predictEta(
        targetKm: 100, currentKm: 30, elapsedMin: 180, cotMin: 480);
    expect(p.verdict, EtaVerdict.overCot);
    expect(p.bufferMin, lessThan(0));
    // pace dibutuhkan sisa: 70 km / 300 mnt = 14 km/h > pace kini 10.
    expect(p.requiredAvgKmh, closeTo(14, 0.01));
  });

  test('ETA finished & belum jalan', () {
    final done = predictEta(
        targetKm: 100, currentKm: 100, elapsedMin: 300, cotMin: 480);
    expect(done.verdict, EtaVerdict.finished);
    final fresh = predictEta(
        targetKm: 100, currentKm: 0, elapsedMin: 0, cotMin: 480);
    expect(fresh.verdict, EtaVerdict.belumJalan);
    expect(fresh.requiredAvgKmh, closeTo(100 / 8, 0.01));
  });

  test('format jam & durasi', () {
    expect(formatClock(DateTime(2026, 1, 1, 5, 7)), '05:07');
    expect(formatDuration(90), '1j 30m');
    expect(formatDuration(45), '45m');
  });

  test('weekKmOf abaikan tanggal masa depan', () {    final d = DateTime.now().add(const Duration(days: 2));
    String p2(int n) => n.toString().padLeft(2, '0');
    final future =
        '${d.year}-${p2(d.month)}-${p2(d.day)}T07:00:00Z';
    final acts = [
      CyclingActivity(name: 'Besok', distance: 50000, totalElevationGain: 0, averageSpeed: 25 / 3.6, startDate: future),
    ];
    expect(weekKmOf(acts), 0);
  });

  test('tren kecepatan tertimbang jarak', () {
    // Prev: 2x10 km @20. Recent: 10 km @20 + 50 km @30.
    // Tertimbang: (200+1500)/60=28,33 vs 20 → +41,7% (mean biasa: +25%).
    final acts = [
      CyclingActivity(name: 'P1', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(20)),
      CyclingActivity(name: 'P2', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(25)),
      CyclingActivity(name: 'R1', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(2)),
      CyclingActivity(name: 'R2', distance: 50000, totalElevationGain: 0, averageSpeed: 30 / 3.6, startDate: ymd(5)),
    ];
    final a = analyzeCoach(acts, 185);
    expect(a.speedTrendPct, closeTo(41.67, 0.5));
  });

  test('readiness pakai longest 90 hari, bukan rekor basi', () {
    final ev = EventGoal(name: 'Audax', eventDate: '2026-12-01', targetDistanceKm: 100, createdAt: 1);
    final acts = [
      CyclingActivity(name: 'Basi 200K', distance: 200000, totalElevationGain: 0, averageSpeed: 25 / 3.6, startDate: ymd(200)),
      CyclingActivity(name: 'R1', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(2)),
      CyclingActivity(name: 'R2', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(4)),
      CyclingActivity(name: 'R3', distance: 10000, totalElevationGain: 0, averageSpeed: 20 / 3.6, startDate: ymd(6)),
    ];
    final an = analyzeCoach(acts, 185);
    final r = eventReadiness(ev, acts, an.ctl, an.weekKm);
    // Rekor basi 200 km tidak boleh mengangkat skor.
    expect(r.pct, lessThan(50));
    expect(r.verdict, contains('Fondasi'));
  });
  test('resolveTriple 3 arah + kurang data', () {
    final a = resolveTriple(km: 50, speedKmh: 0, elapsedMin: 120)!;
    expect(a.speedKmh, closeTo(25, 0.01));
    final b = resolveTriple(km: 0, speedKmh: 25, elapsedMin: 120)!;
    expect(b.km, closeTo(50, 0.01));
    final c = resolveTriple(km: 50, speedKmh: 25, elapsedMin: 0)!;
    expect(c.elapsedMin, closeTo(120, 0.01));
    expect(resolveTriple(km: 50, speedKmh: 0, elapsedMin: 0), isNull);
    expect(resolveTriple(km: 0, speedKmh: 0, elapsedMin: 0), isNull);
  });
  test('rata-rata tertimbang durasi (bukan mean biasa)', () {
    // 10 km @20 km/jam (30 mnt) + 90 km @30 km/jam (180 mnt) = 100 km/210 mnt.
    final acts = [
      CyclingActivity(name: 'Sprint', distance: 10000, totalElevationGain: 10, averageSpeed: 20 / 3.6, startDate: ymd(1)),
      CyclingActivity(name: 'Long', distance: 90000, totalElevationGain: 100, averageSpeed: 30 / 3.6, startDate: ymd(0)),
    ];
    final a = analyzeCoach(acts, 185);
    expect(a.avgSpeedKmh, closeTo(100 / 3.5, 0.05)); // 28,57 bukan 25
  });

  test('sesi acuan ikut tanggal, bukan urutan input', () {
    final acts = [
      CyclingActivity(name: 'Z5 Lama', distance: 20000, totalElevationGain: 50, averageSpeed: 25 / 3.6, startDate: ymd(30), averageHeartRate: 180),
      CyclingActivity(name: 'Easy Baru', distance: 15000, totalElevationGain: 50, averageSpeed: 22 / 3.6, startDate: ymd(1), averageHeartRate: 120),
    ];
    final a = analyzeCoach(acts, 185);
    expect(a.latestName, 'Easy Baru');
    // Z5 lama tidak boleh memicu Istirahat Total.
    expect(a.todayType, isNot(PlanType.rest));
  });

  test('dua sesi keras beruntun → recovery easy', () {
    final acts = [
      CyclingActivity(name: 'Keras 1', distance: 20000, totalElevationGain: 100, averageSpeed: 28 / 3.6, startDate: ymd(1), averageHeartRate: 160),
      CyclingActivity(name: 'Keras 2', distance: 20000, totalElevationGain: 100, averageSpeed: 28 / 3.6, startDate: ymd(0), averageHeartRate: 162),
    ];
    final a = analyzeCoach(acts, 185);
    expect(a.todayType, PlanType.easy);
    expect(a.recoveryReason, contains('beruntun'));
  });

  test('beban monoton 7 hari → warning', () {
    final acts = [
      for (var i = 0; i < 7; i++)
        CyclingActivity(name: 'Rutin $i', distance: 30000, totalElevationGain: 100, averageSpeed: 25 / 3.6, startDate: ymd(i), averageHeartRate: 150),
    ];
    final a = analyzeCoach(acts, 185);
    expect(a.warnings.any((w) => w.contains('monoton')), isTrue);
  });

  test('confidence 3 tier', () {
    final one = [
      CyclingActivity(name: 'Satu', distance: 20000, totalElevationGain: 50, averageSpeed: 22 / 3.6, startDate: ymd(0), averageHeartRate: 130),
    ];
    expect(analyzeCoach(one, 185).confidence, contains('AWAL'));
    final five = [
      for (var i = 0; i < 5; i++)
        CyclingActivity(name: 'R$i', distance: 20000, totalElevationGain: 50, averageSpeed: 22 / 3.6, startDate: ymd(i), averageHeartRate: 130),
    ];
    expect(analyzeCoach(five, 185).confidence, contains('SEDANG'));
  });
}
