import '../models/models.dart';

/// Estimasi kalori (kkal) per sesi dari jarak, kecepatan, dan berat badan.
///
/// Faktor biaya energi bersepeda ±0,2–0,45 kkal/kg/km tergantung kecepatan.
/// Ini ESTIMASI kasar (tanpa power meter / tanjakan detail) — cukup untuk
/// tren antar-sesi, bukan angka laboratorium.
double estimateCaloriesKcal(CyclingActivity a, double weightKg) {
  final w = weightKg.clamp(30.0, 200.0);
  final factor = 0.20 + 0.008 * a.speedKmh.clamp(0.0, 60.0);
  return a.distanceKm * w * factor;
}

double totalCaloriesKcal(List<CyclingActivity> activities, double weightKg) =>
    activities.fold<double>(0, (s, a) => s + estimateCaloriesKcal(a, weightKg));

/// Ringkasan total sepanjang masa untuk kartu "Total" di Statistik.
({double km, int rides, double elevM, double minutes, double kcal}) lifetimeTotals(
    List<CyclingActivity> activities, double weightKg) {
  double km = 0, elev = 0, min = 0;
  for (final a in activities) {
    km += a.distanceKm;
    elev += a.totalElevationGain;
    min += a.durationMin;
  }
  return (
    km: km,
    rides: activities.length,
    elevM: elev,
    minutes: min,
    kcal: totalCaloriesKcal(activities, weightKg),
  );
}
