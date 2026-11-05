import 'package:latlong2/latlong.dart';

import '../core/geo_utils.dart';
import 'models.dart';

/// Asal rute rencana. Label dipakai sebagai badge singkat di layar Rekam.
enum PlannedRouteSource {
  gpx('GPX'),
  osrm('OSRM'),
  event('Event'),
  manual('Manual');

  final String label;
  const PlannedRouteSource(this.label);
}

/// Rute yang akan diikuti saat merekam (GPX impor, OSRM, atau rute event).
///
/// Sebelumnya metadata rute dikirim ke layar Rekam sebagai tiga parameter
/// primitif (`plannedRoute`, `routeName`, `plannedDistanceM`). Model ini
/// menyatukan titik, jarak, durasi, dan elevasi agar konsisten di Jelajah,
/// layar Rekam, dan pengujian — sekaligus mencegah metadata tertukar.
class PlannedRoute {
  final String name;

  /// Titik yang siap digambar di peta (sudah disederhanakan bila perlu).
  final List<LatLng> points;

  /// Jarak rute asli dalam meter (dihitung sebelum penyederhanaan).
  final double distanceM;

  /// Estimasi durasi gowes dalam detik. 0 = tidak diketahui.
  final double durationSec;

  /// Total elevasi naik dalam meter. 0 = data elevasi tidak tersedia.
  final double elevationGainM;

  /// Jumlah titik pada sumber asli (sebelum penyederhanaan).
  final int sourcePointCount;

  final PlannedRouteSource source;

  PlannedRoute({
    required String name,
    required List<LatLng> points,
    this.distanceM = 0,
    this.durationSec = 0,
    this.elevationGainM = 0,
    int? sourcePointCount,
    this.source = PlannedRouteSource.manual,
  }) : name = _normalizeName(name, source),
       points = List.unmodifiable(points),
       sourcePointCount = sourcePointCount ?? points.length;

  /// Bangun rute dari titik GPX mentah: hitung jarak, elevasi, dan durasi.
  ///
  /// Titik peta disederhanakan Douglas-Peucker ([simplifyToleranceM] meter),
  /// tetapi jarak/elevasi tetap dihitung dari data asli agar angka di UI
  /// tidak berubah hanya karena penyederhanaan.
  factory PlannedRoute.fromGpsPoints(
    List<GpsPoint> raw, {
    required String name,
    PlannedRouteSource source = PlannedRouteSource.gpx,
    double simplifyToleranceM = 2,
  }) {
    final distanceM = routeDistanceM(raw);
    final elevationGainM = routeElevationGain(raw);
    var durationSec = 0.0;
    if (raw.length >= 2 && raw.first.t > 0 && raw.last.t > raw.first.t) {
      durationSec = (raw.last.t - raw.first.t) / 1000.0;
    }
    if (durationSec <= 0 && distanceM > 0) {
      // Tanpa timestamp (umum di GPX rute): asumsi gowes santai 20 km/jam.
      durationSec = distanceM / (20 / 3.6);
    }
    final simplified = simplifyRoute(raw, simplifyToleranceM);
    final points = [for (final p in simplified) LatLng(p.lat, p.lng)];
    return PlannedRoute(
      name: name,
      points: points,
      distanceM: distanceM,
      durationSec: durationSec,
      elevationGainM: elevationGainM,
      sourcePointCount: raw.length,
      source: source,
    );
  }

  /// Bangun rute dari titik peta yang sudah jadi (mis. hasil OSRM).
  ///
  /// [distanceM] dan [durationSec] diisi bila sumber sudah menghitungnya;
  /// bila nol, jarak dihitung ulang dan durasi memakai asumsi 20 km/jam.
  factory PlannedRoute.fromLatLngs(
    List<LatLng> points, {
    required String name,
    double distanceM = 0,
    double durationSec = 0,
    double elevationGainM = 0,
    int? sourcePointCount,
    PlannedRouteSource source = PlannedRouteSource.osrm,
  }) {
    var dist = distanceM;
    if (dist <= 0) {
      for (var i = 1; i < points.length; i++) {
        dist += haversineM(
          points[i - 1].latitude,
          points[i - 1].longitude,
          points[i].latitude,
          points[i].longitude,
        );
      }
    }
    var dur = durationSec;
    if (dur <= 0 && dist > 0) dur = dist / (20 / 3.6);
    return PlannedRoute(
      name: name,
      points: points,
      distanceM: dist,
      durationSec: dur,
      elevationGainM: elevationGainM,
      sourcePointCount: sourcePointCount,
      source: source,
    );
  }

  bool get hasRoute => points.length >= 2;
  double get distanceKm => distanceM / 1000.0;
  LatLng? get start => points.isEmpty ? null : points.first;
  LatLng? get finish => points.isEmpty ? null : points.last;

  String get displayName {
    final n = name.trim();
    return n.isEmpty ? 'Rute ${source.label}' : n;
  }

  String get distanceLabel => distanceM > 0
      ? '${distanceKm.toStringAsFixed(distanceKm >= 100 ? 0 : 1)} km'
      : '-';

  /// ETA ringkas, mis. `45 mnt` atau `2j 10m`.
  String get etaLabel {
    final m = (durationSec / 60).round();
    if (m <= 0) return '-';
    if (m < 60) return '$m mnt';
    return '${m ~/ 60}j ${m % 60}m';
  }

  /// Satu baris ringkasan untuk banner Rekam / kartu Jelajah.
  String get summaryLine {
    final parts = <String>[
      distanceLabel,
      if (elevationGainM >= 5) '↑ ${elevationGainM.round()} m',
      if (durationSec > 0) '~$etaLabel gowes',
    ];
    return parts.join(' • ');
  }

  static String _normalizeName(String name, PlannedRouteSource source) {
    final n = name.trim();
    return n.isEmpty ? 'Rute ${source.label}' : n;
  }
}
