import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../models/models.dart';

// ---------- Enums ----------
enum LoadLevel { rendah, optimal, tinggi }
enum RecoveryStatus { siap, waspada, butuhIstirahat }
enum PlanType { rest, easy, tempo, interval, long, taper, event }
enum SessionTone { good, neutral, warn }
enum SortMode { terbaru, terjauh, tercepat }

// ---------- Analysis models ----------
class CoachAnalysis {
  final double totalKm;
  final int totalRides;
  final double avgSpeedKmh;
  final double avgHr;
  final double hrCoverage;
  final double totalElevationM;
  final double last7Km;
  final double speedTrendPct;
  final double loadScore;
  final LoadLevel loadLevel;
  final double weekKm;
  final double lastWeekKm;
  final double wowPct;
  final double sessionsPerWeek;
  final double avgDurationMin;
  final double trimp7;
  final double ctl;
  final double atl;
  final double tsb;
  final String freshnessLabel;
  final String weekMix;
  final String weekPlan;
  final String confidence;
  final RecoveryStatus recovery;
  final String recoveryReason;
  final PlanType todayType;
  final String todayTitle;
  final String todayDetail;
  final Map<String, int> hrZones;
  final Map<String, double> hrZoneMinutes; // menit per zona (tertimbang durasi)
  final String latestName; // sesi acuan (terbaru menurut tanggal)
  final String latestDate; // yyyy-MM-dd sesi acuan
  final List<String> warnings;

  const CoachAnalysis({
    required this.totalKm,
    required this.totalRides,
    required this.avgSpeedKmh,
    required this.avgHr,
    required this.hrCoverage,
    required this.totalElevationM,
    required this.last7Km,
    required this.speedTrendPct,
    required this.loadScore,
    required this.loadLevel,
    required this.weekKm,
    required this.lastWeekKm,
    required this.wowPct,
    required this.sessionsPerWeek,
    required this.avgDurationMin,
    required this.trimp7,
    required this.ctl,
    required this.atl,
    required this.tsb,
    required this.freshnessLabel,
    required this.weekMix,
    required this.weekPlan,
    required this.confidence,
    required this.recovery,
    required this.recoveryReason,
    required this.todayType,
    required this.todayTitle,
    required this.todayDetail,
    required this.hrZones,
    required this.hrZoneMinutes,
    required this.latestName,
    required this.latestDate,
    required this.warnings,
  });
}

class TrainingDay {
  final String date; // yyyy-MM-dd
  final String dayLabel;
  final PlanType type;
  final double distanceKm;
  final String note;
  const TrainingDay({required this.date, required this.dayLabel, required this.type, required this.distanceKm, required this.note});
}

class SessionEvaluation {
  final String verdict;
  final SessionTone tone;
  final List<String> strengths;
  final List<String> gaps;
  final String focusNext;
  const SessionEvaluation({required this.verdict, required this.tone, required this.strengths, required this.gaps, required this.focusNext});
}

class PeriodStat {
  final String label;
  final double km;
  final int rides;
  final double elevM;
  final double minutes;
  const PeriodStat({required this.label, required this.km, required this.rides, required this.elevM, required this.minutes});
}

class RideRecords {
  final double longestKm;
  final String longestName;
  final double fastestKmh;
  final String fastestName;
  final double maxElevM;
  final String maxElevName;
  final int totalRides;
  const RideRecords({required this.longestKm, required this.longestName, required this.fastestKmh, required this.fastestName, required this.maxElevM, required this.maxElevName, required this.totalRides});
}

// ---------- Date helpers ----------
final _dayFmt = DateFormat('yyyy-MM-dd', 'en_US');

String todayString() => _dayFmt.format(DateTime.now());

int daysUntil(String targetYmd) {
  try {
    final target = _dayFmt.parse(targetYmd.substring(0, 10));
    final today = _dayFmt.parse(todayString());
    return target.difference(today).inDays;
  } catch (_) {
    return -999;
  }
}

DateTime? parseActivityDate(String ymd) {
  try {
    return _dayFmt.parse(ymd.substring(0, 10));
  } catch (_) {
    return null;
  }
}

const _idDays = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
const _idMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String prettyDay(DateTime d) {
  final dow = _idDays[d.weekday % 7];
  return '$dow, ${d.day} ${_idMonths[d.month - 1]}';
}

int weekdayMonFirst(String ymd) {
  final d = parseActivityDate(ymd);
  if (d == null) return 0;
  return (d.weekday - 1) % 7; // Mon=0
}

String weekStartMonday([int weeksBack = 0]) {
  final now = DateTime.now();
  final dowMonFirst = (now.weekday - 1) % 7;
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: dowMonFirst + weeksBack * 7));
  return _dayFmt.format(monday);
}

double weekKmOf(List<CyclingActivity> activities) {
  final thisMon = weekStartMonday(0);
  final today = todayString();
  double sum = 0;
  for (final a in activities) {
    // Abaikan tanggal masa depan (salah input) agar progres tidak menggelembung.
    if (a.dateKey.compareTo(thisMon) >= 0 && a.dateKey.compareTo(today) <= 0) {
      sum += a.distance;
    }
  }
  return sum / 1000.0;
}

int daysLeftInWeek() => (7 - weekdayMonFirst(todayString())).clamp(1, 7);

double requiredPerDay(double weekKm, double targetKm) {
  if (weekKm >= targetKm) return 0;
  return (targetKm - weekKm) / daysLeftInWeek();
}

// ---------- HR ----------
String hrZoneName(double hr, int maxHr) {
  if (hr <= 0) return '-';
  final pct = hr / math.max(maxHr, 100);
  if (pct < 0.60) return 'Z1';
  if (pct < 0.70) return 'Z2';
  if (pct < 0.80) return 'Z3';
  if (pct < 0.90) return 'Z4';
  return 'Z5';
}

String hrZoneDesc(String zone) => switch (zone) {
      'Z1' => 'Recovery (<60%)',
      'Z2' => 'Aerobik (60–70%)',
      'Z3' => 'Tempo (70–80%)',
      'Z4' => 'Threshold (80–90%)',
      'Z5' => 'Maksimal (>90%)',
      _ => '-',
    };

String planTypeLabel(PlanType t) => switch (t) {
      PlanType.rest => 'Istirahat',
      PlanType.easy => 'Easy',
      PlanType.tempo => 'Tempo',
      PlanType.interval => 'Interval',
      PlanType.long => 'Long Ride',
      PlanType.taper => 'Taper',
      PlanType.event => 'EVENT',
    };

// ---------- Core ----------
double durationMinOf(CyclingActivity a) {
  // Durasi GPS real diutamakan (termasuk jeda lampu merah); fallback ke
  // jarak/kecepatan untuk sesi manual/CSV lama.
  if (a.durationSec > 0) return a.durationSec / 60.0;
  if (a.averageSpeed <= 0) return 0;
  return a.distance / a.averageSpeed / 60.0;
}

double trimpOf(CyclingActivity a, int maxHr, [int restHr = 60]) {
  final durMin = durationMinOf(a);
  if (durMin <= 0) return 0;
  if (a.averageHeartRate <= 0) return (a.distance / 1000.0) * 4.0;
  final ratio = ((a.averageHeartRate - restHr) / math.max(maxHr - restHr, 40)).clamp(0.0, 1.0);
  return durMin * ratio * 0.64 * math.exp(1.92 * ratio);
}

String generateCoachInsight(List<CyclingActivity> activities, double targetKm) {
  final weekKm = weekKmOf(activities);
  final hasThisWeek = activities.any((a) => a.dateKey.compareTo(weekStartMonday(0)) >= 0);
  if (!hasThisWeek) return 'Belum ada latihan minggu ini. Yuk, catat gowes pertamamu!';
  if (weekKm >= targetKm) return 'Luar biasa! Kamu melampaui target $targetKm km minggu ini. Total ${weekKm.toStringAsFixed(1)} km.';
  if (weekKm >= targetKm * 0.5) {
    return 'Mantap! ${weekKm.toStringAsFixed(1)} km minggu ini, sisa ${(targetKm - weekKm).toStringAsFixed(1)} km lagi.';
  }
  return 'Awal yang baik! Baru ${weekKm.toStringAsFixed(1)} km dari target $targetKm km minggu ini.';
}

CoachAnalysis analyzeCoach(List<CyclingActivity> activities, int maxHr, [EventGoal? event]) {
  if (activities.isEmpty) {
    return const CoachAnalysis(
      totalKm: 0, totalRides: 0, avgSpeedKmh: 0, avgHr: 0, hrCoverage: 0,
      totalElevationM: 0, last7Km: 0, speedTrendPct: 0, loadScore: 0, loadLevel: LoadLevel.rendah,
      weekKm: 0, lastWeekKm: 0, wowPct: 0, sessionsPerWeek: 0, avgDurationMin: 0,
      trimp7: 0, ctl: 0, atl: 0, tsb: 0, freshnessLabel: 'Belum ada data',
      weekMix: 'Belum ada sesi', weekPlan: 'Mulai 2–3 sesi easy Z2 minggu ini, total 40–60 km.',
      confidence: 'Belum ada data.', recovery: RecoveryStatus.siap,
      recoveryReason: 'Belum ada data. Mulai 2–3 sesi easy minggu ini.',
      todayType: PlanType.easy, todayTitle: 'Mulai dengan Easy Ride 15 km',
      todayDetail: 'Jaga HR di Z2 (60–70% HRmax). Fokus konsistensi, bukan kecepatan.',
      hrZones: {}, hrZoneMinutes: {}, latestName: '-', latestDate: '-',
      warnings: ['Tambahkan minimal 3 latihan agar analisis akurat.'],
    );
  }

  // Urutan terbaru menurut TANGGAL (bukan urutan input/DB) agar sesi acuan
  // selalu benar walau user mengimpor CSV lama setelah mencatat yang baru.
  final byDate = List<CyclingActivity>.of(activities)
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
  final latest = byDate.first;

  final totalKm = activities.fold<double>(0, (s, a) => s + a.distance) / 1000.0;
  // Rata-rata TERTIMBANG durasi: sprint 5 km tidak disetarakan dengan ride 100 km.
  final totalSec = activities.fold<double>(
      0, (s, a) => s + (a.averageSpeed > 0 ? a.distance / a.averageSpeed : 0));
  final avgSpeedKmh =
      totalSec > 0 ? (totalKm * 1000.0) / totalSec * 3.6 : 0.0;
  final withHr = activities.where((a) => a.averageHeartRate > 0).toList();
  final withHrMin =
      withHr.fold<double>(0, (s, a) => s + durationMinOf(a));
  final avgHr = withHr.isEmpty || withHrMin <= 0
      ? 0.0
      : withHr.fold<double>(
              0, (s, a) => s + a.averageHeartRate * durationMinOf(a)) /
          withHrMin;
  final hrCoverage = withHr.length / activities.length;
  final totalElev = activities.fold<double>(0, (s, a) => s + a.totalElevationGain);
  final avgDurationMin = activities.map(durationMinOf).reduce((a, b) => a + b) / activities.length;

  final nowMs = DateTime.now().millisecondsSinceEpoch;
  int daysAgo(CyclingActivity a) {
    final cal = parseActivityDate(a.startDate);
    if (cal == null) return 999;
    return (nowMs - cal.millisecondsSinceEpoch) ~/ (1000 * 60 * 60 * 24);
  }

  final thisMon = weekStartMonday(0);
  final lastMon = weekStartMonday(1);
  final today = todayString();
  // Abaikan tanggal masa depan (salah input/impor) agar progres tidak menggelembung.
  final weekKm = activities.where((a) => a.dateKey.compareTo(thisMon) >= 0 && a.dateKey.compareTo(today) <= 0).fold<double>(0, (s, a) => s + a.distance) / 1000.0;
  final lastWeekKm = activities.where((a) => a.dateKey.compareTo(lastMon) >= 0 && a.dateKey.compareTo(thisMon) < 0).fold<double>(0, (s, a) => s + a.distance) / 1000.0;
  final wowPct = lastWeekKm > 0 ? (weekKm - lastWeekKm) / lastWeekKm * 100 : (weekKm > 0 ? 100.0 : 0.0);
  final sessionsPerWeek = activities.where((a) => daysAgo(a) >= 0 && daysAgo(a) <= 27).length / 4.0;
  final last7Km = activities.where((a) => daysAgo(a) >= 0 && daysAgo(a) <= 6).fold<double>(0, (s, a) => s + a.distance) / 1000.0;

  // Rata-rata TERTIMBANG jarak per jendela: long ride 80 km lebih mewakili
  // tren daripada sekadar dihitung 1 suara seperti sesi 10 km.
  double? avgSpeedWindow(int fromAgo, int toAgo) {
    double km = 0, weighted = 0;
    var n = 0;
    for (final a in activities) {
      final d = daysAgo(a);
      if (d >= fromAgo && d <= toAgo) {
        km += a.distance / 1000.0;
        weighted += a.speedKmh * a.distance / 1000.0;
        n++;
      }
    }
    return (n >= 2 && km > 0) ? weighted / km : null;
  }

  final recent = avgSpeedWindow(0, 13);
  final prev = avgSpeedWindow(14, 27);
  final speedTrendPct = (recent != null && prev != null && prev > 1.0) ? (recent - prev) / prev * 100 : 0.0;

  double trimpOnDay(int ago) {
    final target = _dayFmt.format(DateTime.now().subtract(Duration(days: ago)));
    return activities.where((a) => a.dateKey == target).fold<double>(0, (s, a) => s + trimpOf(a, maxHr));
  }

  final trimp7 = List.generate(7, (i) => trimpOnDay(i)).fold<double>(0, (a, b) => a + b);
  final atl = trimp7 / 7.0;
  final ctl = List.generate(42, (i) => trimpOnDay(i)).fold<double>(0, (a, b) => a + b) / 42.0;
  final tsb = ctl - atl;
  final freshnessLabel = tsb >= 10 ? 'Sangat Segar' : tsb >= -10 ? 'Siap / Seimbang' : tsb >= -30 ? 'Lelah Normal' : 'Risiko Overreach';

  final loadScore = last7Km + totalElev / 800.0;
  final loadLevel = loadScore < 30 ? LoadLevel.rendah : loadScore <= 100 ? LoadLevel.optimal : LoadLevel.tinggi;

  final zones = {'Z1': 0, 'Z2': 0, 'Z3': 0, 'Z4': 0, 'Z5': 0};
  final zoneMinutes = {'Z1': 0.0, 'Z2': 0.0, 'Z3': 0.0, 'Z4': 0.0, 'Z5': 0.0};
  for (final a in withHr) {
    final z = hrZoneName(a.averageHeartRate, maxHr);
    zones[z] = (zones[z] ?? 0) + 1;
    zoneMinutes[z] = (zoneMinutes[z] ?? 0) + durationMinOf(a);
  }

  final last7 = activities.where((a) => daysAgo(a) >= 0 && daysAgo(a) <= 6).toList();
  final easy7 = last7.where((a) {
    final z = hrZoneName(a.averageHeartRate, maxHr);
    return z == 'Z1' || z == 'Z2' || a.averageHeartRate <= 0;
  }).length;
  final quality7 = last7.where((a) => ['Z3', 'Z4', 'Z5'].contains(hrZoneName(a.averageHeartRate, maxHr))).length;
  final long7 = last7.any((a) => a.distance >= 25000);
  final weekMix = '$easy7 easy, $quality7 quality, ${long7 ? 1 : 0} long ride (${last7.length} sesi)';
  String weekPlan;
  if (sessionsPerWeek < 2) {
    weekPlan = 'Naikkan frekuensi ke 3 sesi/minggu: 2 easy Z2 + 1 interval pendek.';
  } else if (quality7 == 0) {
    weekPlan = 'Tambah 1 sesi quality (interval/tempo); 80% volume tetap easy (polarized 80/20).';
  } else if (!long7) {
    weekPlan = 'Jadwalkan 1 long ride Z2 akhir pekan (±${(last7Km * 0.5).clamp(20.0, 100.0).toStringAsFixed(0)} km).';
  } else {
    weekPlan = 'Struktur ideal: 3 easy + 1 interval + 1 long + 2 rest. Pertahankan.';
  }

  final warnings = <String>[];
  if (activities.length < 4) warnings.add('Data baru ${activities.length} sesi — rekomendasi bersifat awal. Akurasi naik setelah 8+ sesi.');
  if (hrCoverage < 0.5) warnings.add('Hanya ${(hrCoverage * 100).round()}% sesi ada HR — TRIMP sesi tanpa HR diestimasi dari jarak.');
  if ((zones['Z5'] ?? 0) >= 2) warnings.add('${zones['Z5']} sesi di Z5. Batasi maksimal 1 sesi intensitas sangat tinggi per minggu.');
  if (speedTrendPct <= -5) warnings.add('Kecepatan 14 hari turun ${(-speedTrendPct).toStringAsFixed(1)}% — indikasi kelelahan menumpuk.');
  if (tsb < -30) warnings.add('TSB ${tsb.toStringAsFixed(0)} (overreach). Wajib deload 3–5 hari easy/rest.');
  // Monotoni beban (Foster): rata-rata TRIMP harian / SD. >2,0 + volume besar
  // = risiko overtraining walau TSB belum merah.
  final daily7 = List.generate(7, (i) => trimpOnDay(i));
  final mean7 = daily7.fold<double>(0, (a, b) => a + b) / 7.0;
  final sd7 = mean7 <= 0
      ? 0.0
      : math.sqrt(daily7.fold<double>(
              0, (s, t) => s + (t - mean7) * (t - mean7)) /
          7.0);
  final monotony = sd7 > 0 ? mean7 / sd7 : (mean7 > 0 ? 99.0 : 0.0);
  if (monotony > 2.0 && trimp7 > 300) {
    warnings.add('Beban 7 hari monoton (${monotony.toStringAsFixed(1)}) dengan TRIMP ${trimp7.toStringAsFixed(0)} — variasikan intensitas (1 easy, 1 off) agar tidak stagnan/overtraining.');
  }

  double kmOfWeek(int weeksBack) {
    final start = weekStartMonday(weeksBack);
    final end = weekStartMonday(math.max(weeksBack - 1, 0));
    return activities.where((a) {
      if (weeksBack == 0) return a.dateKey.compareTo(start) >= 0;
      return a.dateKey.compareTo(start) >= 0 && a.dateKey.compareTo(end) < 0;
    }).fold<double>(0, (s, a) => s + a.distance) / 1000.0;
  }

  final w1 = kmOfWeek(1), w2 = kmOfWeek(2), w3 = kmOfWeek(3);
  final needDeload = w3 > 5 && w2 >= w3 * 1.1 && w1 >= w2 * 1.1 && tsb < -15;
  if (needDeload) {
    warnings.add('Volume naik 3 minggu beruntun (${w3.toStringAsFixed(0)}→${w2.toStringAsFixed(0)}→${w1.toStringAsFixed(0)} km) dengan TSB negatif. Ambil deload week: volume −40–50%.');
    weekPlan = 'Deload week: potong volume 40–50%, semua easy Z1–Z2, tanpa interval. Kembali build minggu depan.';
  }
  final spanDays = dayGapDays(byDate.first.dateKey, byDate.last.dateKey);
  final confidence = (activities.length >= 8 && hrCoverage >= 0.5 && spanDays >= 21)
      ? 'Keyakinan: BAIK — ${activities.length} sesi / $spanDays hari, model TRIMP 42 hari.'
      : (activities.length >= 4
          ? 'Keyakinan: SEDANG — ${activities.length} sesi. Akurasi penuh setelah 8+ sesi dengan HR selama 3+ minggu.'
          : 'Keyakinan: AWAL — tambah sesi dan isi HR tiap latihan agar presisi.');

  final newestHr = latest.averageHeartRate;
  final z2lo = (maxHr * 0.6).round(), z2hi = (maxHr * 0.7).round();
  final z3lo = (maxHr * 0.7).round(), z3hi = (maxHr * 0.8).round();
  final z4hi = (maxHr * 0.95).round();
  final easyDistKm = (35.0 / 60.0) * math.max(avgSpeedKmh, 15.0);
  final longTargetKm = ((last7.where((a) => a.distance >= 10000).map((a) => a.distance / 1000.0).fold<double?>(null, (p, e) => p == null ? e : math.max(p, e)) ?? 30.0) * 1.1).clamp(20.0, 90.0);
  final intervalTotalKm = (50.0 / 60.0) * math.max(avgSpeedKmh, 15.0);

  late RecoveryStatus recovery;
  late String reason;
  late PlanType todayType;
  late String todayTitle;
  late String todayDetail;

  // Dua sesi keras (≥85% HRmax) beruntun dalam ≤2 hari — TSB bisa belum merah
  // padahal sistem saraf belum pulih. Wajib easy.
  bool isHard(CyclingActivity a) =>
      a.averageHeartRate > 0 && a.averageHeartRate >= maxHr * 0.85;
  final last2 = byDate.take(2).toList();
  final backToBackHard = last2.length == 2 &&
      last2.every(isHard) &&
      dayGapDays(last2[0].dateKey, last2[1].dateKey) <= 2;

  if (newestHr >= maxHr * 0.90 && newestHr > 0) {
    recovery = RecoveryStatus.butuhIstirahat;
    reason = 'Sesi terakhir ${(newestHr / maxHr * 100).round()}% HRmax (Z5) dengan TSB ${tsb.toStringAsFixed(0)}. Sistem saraf butuh 24–48 jam pulih penuh.';
    todayType = PlanType.rest; todayTitle = 'Istirahat Total';
    todayDetail = 'Tanpa sepeda. Tidur 7–8 jam, protein 1,6 g/kgBB, hidrasi. Boleh jalan ringan 20 menit.';
  } else if (tsb < -30) {
    recovery = RecoveryStatus.butuhIstirahat;
    reason = 'TSB ${tsb.toStringAsFixed(0)}: kelelahan menumpuk (CTL ${ctl.toStringAsFixed(0)} vs ATL ${atl.toStringAsFixed(0)}). Latihan keras sekarang = overtraining.';
    todayType = PlanType.rest; todayTitle = 'Deload: Rest 2–3 Hari';
    todayDetail = 'Libur sepeda 2–3 hari, lalu kembali via Easy 30 mnt Z1 (HR di bawah ${(maxHr * 0.6).round()} bpm).';
  } else if (needDeload) {
    recovery = RecoveryStatus.waspada;
    reason = 'TSB ${tsb.toStringAsFixed(0)} setelah 3 minggu volume naik. Tubuh butuh deload agar adaptasi terserap.';
    todayType = PlanType.easy; todayTitle = 'Deload Easy ${easyDistKm.toStringAsFixed(0)} km Z1';
    todayDetail = '40–50 mnt sangat santai, HR di bawah ${(maxHr * 0.6).round()} bpm. Tanpa interval minggu ini.';
  } else if (backToBackHard) {
    recovery = RecoveryStatus.waspada;
    reason = 'Dua sesi keras beruntun ("${last2[1].name}" lalu "${last2[0].name}"). Sistem kardiovaskular butuh 1 hari easy agar adaptasi terserap, bukan ditumpuk.';
    todayType = PlanType.easy; todayTitle = 'Recovery ${easyDistKm.toStringAsFixed(0)} km Z1–Z2';
    todayDetail = '35–45 mnt sangat santai. HR $z2lo–$z2hi bpm. Interval berikutnya setelah 1 easy + 1 tidur cukup.';
  } else if (tsb < -10) {
    recovery = RecoveryStatus.waspada;
    reason = 'TSB ${tsb.toStringAsFixed(0)}: fase adaptasi pasca-beban. Stimulus ringan justru mempercepat superkompensasi.';
    todayType = PlanType.easy; todayTitle = 'Recovery ${easyDistKm.toStringAsFixed(0)} km Z1–Z2';
    todayDetail = '35–45 mnt santai. HR $z2lo–$z2hi bpm, cadence 85–95 rpm. Berhenti jika HR melayang >10 bpm di pace biasa.';
  } else if (quality7 == 0) {
    recovery = RecoveryStatus.siap;
    reason = 'TSB ${tsb.toStringAsFixed(0)} (${freshnessLabel.toLowerCase()}). Tidak ada sesi quality 7 hari terakhir — saatnya stimulus VO2max.';
    todayType = PlanType.interval; todayTitle = 'Interval 4×4 mnt @ ${(maxHr * 0.9).round()}–$z4hi bpm';
    todayDetail = 'Pemanasan 15 mnt Z2. 4× (4 mnt keras 90–95% HRmax + 3 mnt easy). Pendinginan 10 mnt. Total ±50 mnt (±${intervalTotalKm.toStringAsFixed(0)} km).';
  } else if (!long7) {
    recovery = RecoveryStatus.siap;
    reason = 'TSB ${tsb.toStringAsFixed(0)} (${freshnessLabel.toLowerCase()}). Basis aerobik kurang: belum ada long ride minggu ini.';
    todayType = PlanType.long; todayTitle = 'Long Ride ${longTargetKm.toStringAsFixed(0)} km @ $z2lo–$z2hi bpm';
    todayDetail = 'Z2 sepanjang jalan, pace ngobrol. Karbo 30–60 g/jam setelah jam pertama.';
  } else {
    recovery = RecoveryStatus.siap;
    reason = 'TSB ${tsb.toStringAsFixed(0)} (${freshnessLabel.toLowerCase()}). Struktur minggu seimbang — kunci dengan tempo.';
    todayType = PlanType.tempo; todayTitle = 'Tempo 25 mnt @ $z3lo–$z3hi bpm';
    todayDetail = '20 mnt Z2 + 25 mnt Z3 + 10 mnt cooldown. Pacing datar, cadence stabil 90 rpm.';
  }

  if (event != null) {
    final d = daysUntil(event.eventDate);
    if (d == 0) {
      recovery = RecoveryStatus.siap;
      reason = 'Hari H ${event.name}. Kepercayaan pada proses taper 3 hari terakhir.';
      todayType = PlanType.event; todayTitle = 'HARI H: ${event.name} ${event.targetDistanceKm.toInt()} km';
      todayDetail = 'Makan 3 jam sebelum start. Pacing sesuai long ride latihan.';
    } else if (d == 1) {
      recovery = RecoveryStatus.siap;
      reason = 'H-1 ${event.name}: kebugaran sudah terkunci, yang tersisa hanya kesegaran.';
      todayType = PlanType.rest; todayTitle = 'Rest Total Pra-Event';
      todayDetail = 'Tanpa sepeda. Siapkan perlengkapan, carb-loading, tidur jam 9 malam.';
    } else if (d >= 2 && d <= 3) {
      recovery = RecoveryStatus.siap;
      reason = 'Masuk taper ${event.name} (H-$d). Volume turun, intensitas dijaga pendek.';
      todayType = PlanType.taper; todayTitle = 'Taper Easy 12 km + Bukaan Kaki';
      todayDetail = 'Easy 12 km Z1–Z2 + 3×1 mnt bukaan kaki Z3. Total ±30 mnt.';
    }
  }

  return CoachAnalysis(
    totalKm: totalKm, totalRides: activities.length, avgSpeedKmh: avgSpeedKmh,
    avgHr: avgHr, hrCoverage: hrCoverage, totalElevationM: totalElev,
    last7Km: last7Km, speedTrendPct: speedTrendPct, loadScore: loadScore, loadLevel: loadLevel,
    weekKm: weekKm, lastWeekKm: lastWeekKm, wowPct: wowPct, sessionsPerWeek: sessionsPerWeek,
    avgDurationMin: avgDurationMin, trimp7: trimp7, ctl: ctl, atl: atl, tsb: tsb,
    freshnessLabel: freshnessLabel, weekMix: weekMix, weekPlan: weekPlan, confidence: confidence,
    recovery: recovery, recoveryReason: reason, todayType: todayType,
    todayTitle: todayTitle, todayDetail: todayDetail, hrZones: zones,
    hrZoneMinutes: zoneMinutes,
    latestName: latest.name, latestDate: latest.dateKey, warnings: warnings,
  );
}

// ---------- Event readiness ----------
({int pct, String verdict}) eventReadiness(EventGoal event, List<CyclingActivity> activities, double ctl, double weekKm) {
  // Longest ride dinilai dari 90 hari terakhir (kebugaran spesifik event),
  // bukan rekor sepanjang masa yang bisa sudah basi setahun lalu.
  final cutoff = DateTime.now().subtract(const Duration(days: 90));
  final recent = activities.where((a) {
    final d = parseActivityDate(a.startDate);
    return d != null && !d.isBefore(cutoff);
  }).toList();
  final pool = recent.isNotEmpty ? recent : activities;
  final longestKm = pool.map((a) => a.distance / 1000.0).fold<double>(0, math.max);
  final needLong = math.max(event.targetDistanceKm * 0.7, 5.0);
  final needVol = math.max(event.targetDistanceKm * 1.5, 10.0);
  final volScore = (weekKm / needVol).clamp(0.0, 1.0);
  final longScore = (longestKm / needLong).clamp(0.0, 1.0);
  final ctlScore = (ctl / 70.0).clamp(0.0, 1.0);
  final pct = (0.4 * volScore + 0.4 * longScore + 0.2 * ctlScore) * 100;
  String verdict;
  if (pct >= 85) {
    verdict = 'Siap tempur. Tinggal jaga taper dan eksekusi pacing sesuai latihan.';
  } else if (pct >= 60) {
    final gap = longScore <= volScore
        ? 'naikkan longest ride ke ≥${needLong.round()} km (sekarang ${longestKm.toStringAsFixed(0)} km)'
        : 'naikkan volume ke ≥${needVol.round()} km/minggu (sekarang ${weekKm.toStringAsFixed(0)} km)';
    verdict = 'Hampir siap (${pct.round()}%). Fokus utama: $gap.';
  } else if (pct >= 35) {
    verdict = 'Bangun base 3–5 minggu: 1 long ride/minggu, volume +10%/minggu, 2 rest/minggu.';
  } else {
    verdict = 'Fondasi belum cukup. Opsi realistis: ikut kategori lebih pendek dulu atau geser jadwal event.';
  }
  return (pct: pct.round(), verdict: verdict);
}

// ---------- Session eval ----------
SessionEvaluation evaluateSession(CyclingActivity session, List<CyclingActivity> others, int maxHr, double tsb) {
  final strengths = <String>[], gaps = <String>[];
  final distKm = session.distance / 1000.0;
  final speedKmh = session.speedKmh;
  final durMin = durationMinOf(session);
  final hr = session.averageHeartRate;
  final zone = hrZoneName(hr, maxHr);
  final trimp = trimpOf(session, maxHr);

  final avgSpeed = others.isEmpty ? speedKmh : others.map((a) => a.speedKmh).reduce((a, b) => a + b) / others.length;
  final longest = others.map((a) => a.distance / 1000.0).fold<double>(0, math.max);
  final avgTrimp = others.isEmpty ? trimp : others.map((a) => trimpOf(a, maxHr)).reduce((a, b) => a + b) / others.length;
  final avgElev = others.isEmpty ? 0.0 : others.map((a) => a.totalElevationGain).reduce((a, b) => a + b) / others.length;

  if (others.isNotEmpty && distKm > longest && longest > 0) strengths.add('Rekor jarak baru: ${distKm.toStringAsFixed(1)} km (sebelumnya ${longest.toStringAsFixed(1)} km).');
  if (others.isNotEmpty && avgSpeed > 1 && (speedKmh - avgSpeed) / avgSpeed * 100 >= 5) strengths.add('Kecepatan ${((speedKmh - avgSpeed) / avgSpeed * 100).toStringAsFixed(0)}% di atas rata-rata (${avgSpeed.toStringAsFixed(1)} km/jam).');
  if (zone == 'Z4' && durMin >= 20 && durMin <= 70) strengths.add('Eksekusi threshold tepat: ${durMin.toInt()} mnt di Z4.');
  if (zone == 'Z3' && durMin >= 25) strengths.add('Tempo ${durMin.toInt()} mnt di Z3 melatih ketahanan pace event.');
  if ((zone == 'Z1' || zone == 'Z2') && tsb < -10) strengths.add('Disiplin recovery: tetap easy saat tubuh lelah (TSB ${tsb.toStringAsFixed(0)}).');
  if (session.totalElevationGain >= avgElev * 1.5 && session.totalElevationGain >= 100) strengths.add('Tanjakan ${session.totalElevationGain.toInt()} m — kekuatan menanjak terlatih.');
  if (distKm >= 40) strengths.add('Volume besar (${distKm.toStringAsFixed(0)} km) — pastikan recovery 48 jam.');
  if (strengths.isEmpty && hr > 0) strengths.add('Sesi terekam lengkap dengan HR — data ini mempertajam analisis berikutnya.');

  if (hr <= 0) gaps.add('Tanpa data HR: zona dan TRIMP hanya estimasi. Pakai HR monitor.');
  if (zone == 'Z5' && durMin > 40) gaps.add('${durMin.toInt()} mnt di Z5 terlalu lama. Batasi ≤40 mnt per sesi.');
  if (distKm < 5) gaps.add('Sesi sangat pendek (${distKm.toStringAsFixed(1)} km). Minimal 12 km agar stimulus bermakna.');
  if ((zone == 'Z1' || (hr <= 0 && speedKmh < avgSpeed * 0.9)) && tsb > 5 && others.length >= 3) gaps.add('Terlalu santai padahal tubuh segar (TSB +${tsb.toStringAsFixed(0)}). Selipkan tempo 10–15 mnt.');
  if (trimp > avgTrimp * 2.5 && others.length >= 3 && avgTrimp > 0) gaps.add('Beban sesi (${trimp.toStringAsFixed(0)} TRIMP) 2,5× di atas rata-rata. Naikkan maksimal 10%/minggu.');

  final tone = gaps.any((g) => g.contains('Z5 terlalu lama') || g.contains('2,5×'))
      ? SessionTone.warn
      : (strengths.length >= 2 || (zone == 'Z4' && durMin >= 20 && durMin <= 70) ? SessionTone.good : SessionTone.neutral);
  final verdict = switch (tone) {
    SessionTone.good => 'Sesi Berkualitas',
    SessionTone.warn => 'Perlu Perhatian',
    SessionTone.neutral => (zone == 'Z1' || zone == 'Z2') ? 'Recovery Tepat' : 'Sesi Selesai',
  };
  final focusNext = (zone == 'Z4' || zone == 'Z5' || trimp > 100)
      ? 'Berikutnya: Easy 30–40 mnt Z1–Z2 atau rest total.'
      : hr <= 0
          ? 'Berikutnya: ulangi rute mirip DENGAN HR monitor.'
          : tsb >= -10 && zone == 'Z1'
              ? 'Berikutnya: tubuh siap quality — coba interval 4×3 mnt Z4.'
              : distKm >= 40
                  ? 'Berikutnya: recovery 48 jam, lalu easy pendek.'
                  : 'Berikutnya: ikuti rekomendasi harian di tab Coach AI.';
  return SessionEvaluation(verdict: verdict, tone: tone, strengths: strengths.take(4).toList(), gaps: gaps.take(4).toList(), focusNext: focusNext);
}

int dayGapDays(String a, String b) {
  try {
    final da = _dayFmt.parse(a.substring(0, 10));
    final db = _dayFmt.parse(b.substring(0, 10));
    return da.difference(db).inDays.abs();
  } catch (_) {
    return 999;
  }
}

// ---------- Event plan ----------
List<TrainingDay> generateEventPlan(EventGoal event, List<CyclingActivity> activities) {
  final daysLeft = daysUntil(event.eventDate);
  if (daysLeft < 0 || daysLeft > 120) return [];
  if (daysLeft == 0) return [TrainingDay(date: event.eventDate, dayLabel: 'Hari H', type: PlanType.event, distanceKm: event.targetDistanceKm, note: 'Gas! Pacing sesuai latihan.')];
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final recent = activities.where((a) {
    final d = parseActivityDate(a.startDate);
    if (d == null) return false;
    final diff = (nowMs - d.millisecondsSinceEpoch) ~/ (1000 * 60 * 60 * 24);
    return diff >= 0 && diff <= 27;
  }).toList();
  final baseRide = recent.isEmpty ? 20.0 : recent.fold<double>(0, (s, a) => s + a.distance) / 1000.0 / recent.length;
  final longestKm = activities.map((a) => a.distance / 1000.0).fold<double>(baseRide, math.max);
  final easyDist = (baseRide.clamp(10.0, 30.0) * 0.85).clamp(10.0, 30.0);
  final tempoDist = baseRide.clamp(12.0, 40.0);
  final intervalDist = (baseRide * 0.9).clamp(12.0, 30.0);
  final longBase = math.max(math.max(longestKm * 0.85, event.targetDistanceKm * 0.5), 20.0).clamp(0.0, 100.0);

  final totalDays = math.min(daysLeft, 60);
  final result = <TrainingDay>[];
  final start = DateTime.now();
  for (var i = 0; i < totalDays; i++) {
    final cal = DateTime(start.year, start.month, start.day).add(Duration(days: i));
    final ymd = _dayFmt.format(cal);
    final label = prettyDay(cal);
    final fromEnd = totalDays - 1 - i;
    final ramp = 0.8 + 0.2 * (totalDays == 0 ? 0 : i / totalDays);
    if (fromEnd == 0) {
      result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.event, distanceKm: event.targetDistanceKm, note: 'HARI H ${event.name} — ${event.targetDistanceKm.toInt()} km.'));
      continue;
    }
    if (fromEnd == 1) {
      result.add(const TrainingDay(date: '', dayLabel: '', type: PlanType.rest, distanceKm: 0, note: '').copy(date: ymd, label: label, note: 'Rest total. Siapkan sepeda, tidur jam 9 malam.'));
      continue;
    }
    if (fromEnd == 2 || fromEnd == 3) {
      result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.taper, distanceKm: 12, note: 'Taper: easy 12 km Z1–Z2 + 3×1 mnt bukaan kaki.'));
      continue;
    }
    switch (cal.weekday) {
      case DateTime.monday:
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.rest, distanceKm: 0, note: 'Istirahat. Stretching 15 mnt.'));
        break;
      case DateTime.tuesday:
        final d = (easyDist * ramp * 10).round() / 10.0;
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.easy, distanceKm: d, note: 'Easy $d km Z2. Cadence 85–95 rpm.'));
        break;
      case DateTime.wednesday:
        final d = (intervalDist * ramp * 10).round() / 10.0;
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.interval, distanceKm: d, note: 'Interval 5×3 mnt Z4. Total ±$d km.'));
        break;
      case DateTime.thursday:
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.rest, distanceKm: 0, note: 'Rest / cross-training ringan.'));
        break;
      case DateTime.friday:
        final d = (tempoDist * ramp * 10).round() / 10.0;
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.tempo, distanceKm: d, note: 'Tempo $d km Z3.'));
        break;
      case DateTime.saturday:
        final d = (longBase * ramp * 10).round() / 10.0;
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.long, distanceKm: d, note: 'Long ride $d km Z2.'));
        break;
      default:
        final d = (easyDist * 0.8 * 10).round() / 10.0;
        result.add(TrainingDay(date: ymd, dayLabel: label, type: PlanType.easy, distanceKm: d, note: 'Recovery $d km Z1–Z2.'));
    }
  }
  return result;
}

extension on TrainingDay {
  TrainingDay copy({String? date, String? label, String? note}) =>
      TrainingDay(date: date ?? this.date, dayLabel: label ?? dayLabel, type: type, distanceKm: distanceKm, note: note ?? this.note);
}

bool isPastOrToday(String ymd) => daysUntil(ymd) <= 0;

bool planDayAutoDone(TrainingDay day, List<CyclingActivity> activities) {
  if (day.type == PlanType.rest) {
    return !activities.any((a) => a.startDate.startsWith(day.date));
  }
  return activities.any((a) => a.startDate.startsWith(day.date));
}

bool planDayDone(TrainingDay day, List<CyclingActivity> activities, Set<String> manualDone) {
  if (manualDone.contains(day.date)) return true;
  if (!isPastOrToday(day.date)) return false;
  return planDayAutoDone(day, activities);
}

List<String> last30Days() {
  final out = <String>[];
  var cal = DateTime.now().subtract(const Duration(days: 29));
  for (var i = 0; i < 30; i++) {
    out.add(_dayFmt.format(cal));
    cal = cal.add(const Duration(days: 1));
  }
  return out;
}

Map<String, double> kmPerDay(List<CyclingActivity> activities) {
  final map = <String, double>{};
  for (final a in activities) {
    if (a.startDate.length < 10) continue;
    final k = a.startDate.substring(0, 10);
    map[k] = (map[k] ?? 0) + a.distance / 1000.0;
  }
  return map;
}

List<PeriodStat> statsLastWeeks(List<CyclingActivity> activities, [int n = 8]) {
  final now = DateTime.now();
  final dowMonFirst = (now.weekday - 1) % 7;
  var base = DateTime(now.year, now.month, now.day).subtract(Duration(days: dowMonFirst));
  final starts = <String>[];
  for (var i = 0; i < n; i++) {
    starts.insert(0, _dayFmt.format(base));
    base = base.subtract(const Duration(days: 7));
  }
  return starts.map((start) {
    final s = _dayFmt.parse(start);
    final end = _dayFmt.format(s.add(const Duration(days: 7)));
    final today = _dayFmt.format(now);
    // Abaikan tanggal masa depan agar bar minggu berjalan tidak menggelembung.
    final inWeek = activities.where((a) => a.dateKey.compareTo(start) >= 0 && a.dateKey.compareTo(end) < 0 && a.dateKey.compareTo(today) <= 0).toList();
    return PeriodStat(
      label: '${s.day} ${_idMonths[s.month - 1]}',
      km: inWeek.fold<double>(0, (x, a) => x + a.distance) / 1000.0,
      rides: inWeek.length,
      elevM: inWeek.fold<double>(0, (x, a) => x + a.totalElevationGain),
      minutes: inWeek.fold<double>(0, (x, a) => x + durationMinOf(a)),
    );
  }).toList();
}

List<PeriodStat> statsLastMonths(List<CyclingActivity> activities, [int n = 6]) {
  final keys = <String>[];
  final labels = <String>[];
  var base = DateTime(DateTime.now().year, DateTime.now().month, 1);
  for (var i = 0; i < n; i++) {
    keys.insert(0, '${base.year}-${base.month}');
    labels.insert(0, _idMonths[base.month - 1]);
    base = DateTime(base.year, base.month - 1, 1);
  }
  return List.generate(n, (i) {
    final inMonth = activities.where((a) {
      final d = parseActivityDate(a.startDate);
      return d != null && '${d.year}-${d.month}' == keys[i];
    }).toList();
    return PeriodStat(
      label: labels[i],
      km: inMonth.fold<double>(0, (x, a) => x + a.distance) / 1000.0,
      rides: inMonth.length,
      elevM: inMonth.fold<double>(0, (x, a) => x + a.totalElevationGain),
      minutes: inMonth.fold<double>(0, (x, a) => x + durationMinOf(a)),
    );
  });
}

List<PeriodStat> statsLastYears(List<CyclingActivity> activities, [int n = 3]) {
  final thisYear = DateTime.now().year;
  return List.generate(n, (i) {
    final year = thisYear - n + 1 + i;
    final inYear = activities.where((a) => parseActivityDate(a.startDate)?.year == year).toList();
    return PeriodStat(
      label: '$year',
      km: inYear.fold<double>(0, (x, a) => x + a.distance) / 1000.0,
      rides: inYear.length,
      elevM: inYear.fold<double>(0, (x, a) => x + a.totalElevationGain),
      minutes: inYear.fold<double>(0, (x, a) => x + durationMinOf(a)),
    );
  });
}

RideRecords? computeRecords(List<CyclingActivity> activities) {
  if (activities.isEmpty) return null;
  final longest = activities.reduce((a, b) => a.distance >= b.distance ? a : b);
  final over1k = activities.where((a) => a.distance >= 1000).toList();
  final fastest = (over1k.isEmpty ? activities : over1k).reduce((a, b) => a.averageSpeed >= b.averageSpeed ? a : b);
  final climber = activities.reduce((a, b) => a.totalElevationGain >= b.totalElevationGain ? a : b);
  return RideRecords(
    longestKm: longest.distance / 1000.0, longestName: longest.name,
    fastestKmh: fastest.speedKmh, fastestName: fastest.name,
    maxElevM: climber.totalElevationGain, maxElevName: climber.name,
    totalRides: activities.length,
  );
}

int computeWeekStreak(List<CyclingActivity> activities) {
  if (activities.isEmpty) return 0;
  // Monday-based week key: yyyy*100 + weekIndex to avoid YEAR/WEEK_OF_YEAR bug
  String weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: (d.weekday - 1) % 7));
    final base = DateTime(2020, 1, 6); // a Monday
    final weeks = monday.difference(base).inDays ~/ 7;
    return '$weeks';
  }
  final weeks = activities.map((a) {
    final d = parseActivityDate(a.startDate);
    return d == null ? null : weekKey(d);
  }).whereType<String>().toSet();
  if (weeks.isEmpty) return 1;
  var streak = 0;
  var cal = DateTime.now();
  for (var i = 0; i < 520; i++) {
    if (weeks.contains(weekKey(cal))) {
      streak++;
      cal = cal.subtract(const Duration(days: 7));
    } else {
      // allow current week empty if early in week? keep simple: break unless first iter
      if (i == 0) {
        cal = cal.subtract(const Duration(days: 7));
        continue;
      }
      break;
    }
  }
  return streak;
}
