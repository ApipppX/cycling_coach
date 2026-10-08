import 'dart:math' as math;

/// Kalkulator ETA Anti-COT untuk event bersepeda.
///
/// Idenya sederhana: dari posisi KM sekarang + waktu tempuh, proyeksikan jam
/// finis dengan pace saat ini, lalu bandingkan dengan batas waktu (COT).
/// Juga menghitung pace rata-rata yang DIBUTUHKAN di sisa jarak agar finis
/// sebelum COT, plus tabel checkpoint per X km.
enum EtaVerdict { belumJalan, aman, waspada, overCot, finished }

class EtaCheckpoint {
  /// KM marker dari garis start.
  final double km;

  /// Menit dari start agar tiba di marker ini TEPAT saat COT (pace dibutuhkan).
  final double etaMinFromStart;

  /// true jika marker ini masih bisa dicapai sebelum COT dengan pace saat ini.
  final bool reachableOnPace;
  const EtaCheckpoint(
      {required this.km,
      required this.etaMinFromStart,
      required this.reachableOnPace});
}

class EtaPrediction {
  final double targetKm;
  final double currentKm;
  final double elapsedMin;
  final double cotMin;
  final double currentAvgKmh;
  final double remainingKm;
  final double remainingMinVsCot;
  final double requiredAvgKmh;
  final double projectedTotalMin;
  final double bufferMin; // >0 = cadangan, <0 = over COT
  final EtaVerdict verdict;
  final List<EtaCheckpoint> checkpoints;

  const EtaPrediction({
    required this.targetKm,
    required this.currentKm,
    required this.elapsedMin,
    required this.cotMin,
    required this.currentAvgKmh,
    required this.remainingKm,
    required this.remainingMinVsCot,
    required this.requiredAvgKmh,
    required this.projectedTotalMin,
    required this.bufferMin,
    required this.verdict,
    required this.checkpoints,
  });

  bool get hasPace => currentAvgKmh > 0 && projectedTotalMin.isFinite;
}

String etaVerdictLabel(EtaVerdict v) => switch (v) {
      EtaVerdict.belumJalan => 'Belum Jalan',
      EtaVerdict.aman => 'AMAN — di depan COT',
      EtaVerdict.waspada => 'WASPADA — mepet COT',
      EtaVerdict.overCot => 'OVER COT — tambah pace!',
      EtaVerdict.finished => 'FINIS!',
    };

String formatClock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String formatDuration(double totalMin) {
  if (!totalMin.isFinite) return '-';
  final m = totalMin.round().clamp(0, 1 << 30);
  final h = m ~/ 60;
  final mm = m % 60;
  return h > 0 ? '${h}j ${mm}m' : '${mm}m';
}

/// Lengkapi segitiga KM–pace–waktu dari minimal 2 nilai yang terisi.
/// Mengembalikan triple konsisten, atau null bila data kurang dari 2.
/// Murni (tanpa efek samping) agar mudah dites.
({double km, double speedKmh, double elapsedMin})? resolveTriple({
  required double km,
  required double speedKmh,
  required double elapsedMin,
}) {
  final hasKm = km > 0;
  final hasSp = speedKmh > 0;
  final hasEl = elapsedMin > 0;
  if (hasKm && hasEl) return (km: km, speedKmh: km / (elapsedMin / 60.0), elapsedMin: elapsedMin);
  if (hasSp && hasEl) {
    return (km: speedKmh * (elapsedMin / 60.0), speedKmh: speedKmh, elapsedMin: elapsedMin);
  }
  if (hasKm && hasSp) {
    return (km: km, speedKmh: speedKmh, elapsedMin: km / speedKmh * 60.0);
  }
  return null;
}

EtaPrediction predictEta({
  required double targetKm,
  required double currentKm,
  required double elapsedMin,
  required double cotMin,
  double checkpointEveryKm = 10,
}) {
  final target = targetKm <= 0 ? 0.0 : targetKm;
  final cur = currentKm.clamp(0.0, math.max(target, 0.0)).toDouble();
  final elapsed = math.max(elapsedMin, 0.0);
  final cot = math.max(cotMin, 1.0);
  final remaining = math.max(target - cur, 0.0);
  final remainingVsCot = cot - elapsed;

  // Sudah finis.
  if (target > 0 && cur >= target) {
    return EtaPrediction(
      targetKm: target,
      currentKm: cur,
      elapsedMin: elapsed,
      cotMin: cot,
      currentAvgKmh: elapsed > 0 ? cur / (elapsed / 60.0) : 0,
      remainingKm: 0,
      remainingMinVsCot: remainingVsCot,
      requiredAvgKmh: 0,
      projectedTotalMin: elapsed,
      bufferMin: cot - elapsed,
      verdict: EtaVerdict.finished,
      checkpoints: const [],
    );
  }

  final avg = elapsed > 0 && cur > 0 ? cur / (elapsed / 60.0) : 0.0;
  final projected = avg > 0
      ? elapsed + remaining / avg * 60.0
      : double.infinity;
  final required = remainingVsCot > 0 && remaining > 0
      ? remaining / (remainingVsCot / 60.0)
      : (remaining > 0 ? double.infinity : 0.0);
  final buffer = projected.isFinite ? cot - projected : double.negativeInfinity;

  late EtaVerdict verdict;
  if (target <= 0 || (cur <= 0 && elapsed <= 0)) {
    verdict = EtaVerdict.belumJalan;
  } else if (remainingVsCot <= 0) {
    verdict = EtaVerdict.overCot;
  } else if (!projected.isFinite) {
    verdict = EtaVerdict.overCot;
  } else if (projected <= cot - 15) {
    verdict = EtaVerdict.aman;
  } else if (projected <= cot) {
    verdict = EtaVerdict.waspada;
  } else {
    verdict = EtaVerdict.overCot;
  }

  // Checkpoint: tiap X km dari posisi sekarang sampai finis, dengan ETA pada
  // pace yang dibutuhkan (agar tepat COT) + keterjangkauan pada pace kini.
  final cps = <EtaCheckpoint>[];
  final step = checkpointEveryKm <= 0 ? 10.0 : checkpointEveryKm;
  if (target > 0 && remaining > 0) {
    var marker = (cur ~/ step + 1) * step;
    if (marker - cur < 1) marker += step;
    while (marker < target) {
      final etaAtRequired = required.isFinite && required > 0
          ? elapsed + (marker - cur) / required * 60.0
          : double.infinity;
      final etaAtCurrent =
          avg > 0 ? elapsed + (marker - cur) / avg * 60.0 : double.infinity;
      cps.add(EtaCheckpoint(
        km: marker,
        etaMinFromStart: etaAtRequired,
        reachableOnPace: etaAtCurrent <= cot,
      ));
      marker += step;
    }
    final etaFinRequired = required.isFinite && required > 0
        ? elapsed + remaining / required * 60.0
        : double.infinity;
    cps.add(EtaCheckpoint(
      km: target,
      etaMinFromStart: etaFinRequired,
      reachableOnPace: projected.isFinite && projected <= cot,
    ));
  }

  return EtaPrediction(
    targetKm: target,
    currentKm: cur,
    elapsedMin: elapsed,
    cotMin: cot,
    currentAvgKmh: avg,
    remainingKm: remaining,
    remainingMinVsCot: remainingVsCot,
    requiredAvgKmh: required,
    projectedTotalMin: projected,
    bufferMin: buffer.isFinite ? buffer : double.negativeInfinity,
    verdict: verdict,
    checkpoints: cps,
  );
}
