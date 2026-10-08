import 'dart:convert';
import 'dart:math' as math;
import '../models/models.dart';

/// Util GPS untuk rekaman ala Strava: filter, jarak, elevasi, simplify,
/// encode/decode rute, dan ekspor GPX.
///
/// Semua fungsi murni (tanpa efek samping) agar mudah dites.
const double earthRadiusM = 6371000.0;

/// Haversine antar dua titik (meter).
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  const d2r = math.pi / 180.0;
  final dLat = (lat2 - lat1) * d2r;
  final dLng = (lng2 - lng1) * d2r;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * d2r) *
          math.cos(lat2 * d2r) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return 2 * earthRadiusM * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

double routeDistanceM(List<GpsPoint> pts) {
  var sum = 0.0;
  for (var i = 1; i < pts.length; i++) {
    sum += haversineM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
  }
  return sum;
}

/// Gain elevasi total (meter), hanya hitung kenaikan > [minStepM]
/// agar noise barometer/GPS tidak menggelembung.
double routeElevationGain(List<GpsPoint> pts, [double minStepM = 2.0]) {
  var gain = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final d = pts[i].ele - pts[i - 1].ele;
    if (d >= minStepM) gain += d;
  }
  return gain;
}

/// Filter titik mentah: buang yang akurasinya buruk (> [maxAccuracyM])
/// atau lompatan mustahil (> [maxSpeedMs], mis. GPS jump di gedung).
/// Tetap pertahankan titik pertama agar rute tak kosong.
List<GpsPoint> filterRawPoints(
  List<RawGpsFix> fixes, {
  double maxAccuracyM = 25,
  double maxSpeedMs = 22.2, // ~80 km/h, peleton sprint masih lolos
}) {
  final out = <GpsPoint>[];
  for (final f in fixes) {
    if (f.lat == 0 && f.lng == 0) continue;
    if (f.lat < -90 || f.lat > 90 || f.lng < -180 || f.lng > 180) continue;
    if (f.accuracy > 0 && f.accuracy > maxAccuracyM) continue;
    final p = GpsPoint(lat: f.lat, lng: f.lng, ele: f.ele, t: f.t);
    if (out.isEmpty) {
      out.add(p);
      continue;
    }
    final prev = out.last;
    final dt = (p.t - prev.t) / 1000.0;
    if (dt <= 0) continue;
    final d = haversineM(prev.lat, prev.lng, p.lat, p.lng);
    if (d / dt > maxSpeedMs) continue; // GPS jump
    if (d < 2.0 && dt < 3) continue; // diam di lampu merah: hemat poin
    out.add(p);
  }
  return out;
}

/// Fix mentah dari geolocator sebelum difilter.
class RawGpsFix {
  final double lat;
  final double lng;
  final double ele;
  final int t;
  final double accuracy;
  const RawGpsFix(this.lat, this.lng, this.ele, this.t, this.accuracy);
}

/// Bungkus agar track_recorder tak perlu import geolocator di core.
GpsPoint? rawFixToFilteredSeed(
    double lat, double lng, double ele, int t, double acc) {
  final fixes = [RawGpsFix(lat, lng, ele, t, acc)];
  final out = filterRawPoints(fixes);
  return out.isEmpty ? null : out.first;
}

/// Douglas-Peucker: sederhanakan polyline agar DB ringan.
/// [toleranceM] 3–5 m ideal untuk sepeda (hemat 60–80% poin, bentuk tetap).
List<GpsPoint> simplifyRoute(List<GpsPoint> pts, [double toleranceM = 4]) {
  if (pts.length < 3) return List.of(pts);
  // Selalu pertahankan titik pertama & terakhir (start/finish Strava).
  final keep = List<bool>.filled(pts.length, false);
  keep[0] = true;
  keep[pts.length - 1] = true;
  void dp(int first, int last) {
    if (last <= first + 1) return;
    var maxD = 0.0;
    var idx = first;
    for (var i = first + 1; i < last; i++) {
      final d = _perpDistM(pts[i], pts[first], pts[last]);
      if (d > maxD) {
        maxD = d;
        idx = i;
      }
    }
    if (maxD > toleranceM) {
      keep[idx] = true;
      dp(first, idx);
      dp(idx, last);
    }
  }

  dp(0, pts.length - 1);
  final out = <GpsPoint>[];
  for (var i = 0; i < pts.length; i++) {
    if (keep[i]) out.add(pts[i]);
  }
  return out;
}

double _perpDistM(GpsPoint p, GpsPoint a, GpsPoint b) {
  // Proyeksi equirectangular lokal (cukup untuk toleransi meteran).
  const d2r = math.pi / 180.0;
  final lat0 = (a.lat + b.lat) / 2 * d2r;
  double x(double lat, double lng) => lng * d2r * earthRadiusM * math.cos(lat0);
  double y(double lat) => lat * d2r * earthRadiusM;
  final ax = x(a.lat, a.lng), ay = y(a.lat);
  final bx = x(b.lat, b.lng), by = y(b.lat);
  final px = x(p.lat, p.lng), py = y(p.lat);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return haversineM(p.lat, p.lng, a.lat, a.lng);
  var t = ((px - ax) * dx + (py - ay) * dy) / len2;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

/// Encode rute ke JSON ringkas [[lat,lng,ele,t],...] dengan pembulatan
/// (hemat ~40% ukuran DB vs object-map per titik).
String encodeRoute(List<GpsPoint> pts) {
  final arr = [
    for (final p in pts)
      [
        double.parse(p.lat.toStringAsFixed(6)),
        double.parse(p.lng.toStringAsFixed(6)),
        double.parse(p.ele.toStringAsFixed(1)),
        p.t,
      ],
  ];
  return json.encode(arr);
}

/// Decode [CyclingActivity.routeJson]. Mengembalikan [] bila kosong/rusak
/// (tidak pernah throw — aman untuk data lama/manual).
List<GpsPoint> decodeRoute(String routeJson) {
  if (routeJson.isEmpty) return const [];
  try {
    final decoded = json.decode(routeJson);
    if (decoded is! List) return const [];
    final out = <GpsPoint>[];
    for (final e in decoded) {
      if (e is List && e.length >= 2) {
        final lat = (e[0] as num?)?.toDouble();
        final lng = (e[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
        out.add(GpsPoint(
          lat: lat,
          lng: lng,
          ele: e.length > 2 ? ((e[2] as num?)?.toDouble() ?? 0) : 0,
          t: e.length > 3 ? ((e[3] as num?)?.toInt() ?? 0) : 0,
        ));
      } else if (e is Map) {
        final p = GpsPoint.fromJson(e);
        if (p != null) out.add(p);
      }
      if (out.length > 20000) break; // guard DB raksasa
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Ekspor rute ke format GPX 1.1 (bisa diimpor ke Strava/Garmin).
String buildGpx(String name, List<GpsPoint> pts, DateTime start) {
  final sb = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln(
        '<gpx version="1.1" creator="CyclingCoach" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <trk><name>${_xml(name)}</name><trkseg>');
  for (final p in pts) {
    final time = DateTime.fromMillisecondsSinceEpoch(
            p.t > 0 ? p.t : start.millisecondsSinceEpoch,
            isUtc: true)
        .toIso8601String();
    sb.writeln(
        '    <trkpt lat="${p.lat}" lon="${p.lng}"><ele>${p.ele.toStringAsFixed(1)}</ele><time>$time</time></trkpt>');
  }
  sb.writeln('  </trkseg></trk></gpx>');
  return sb.toString();
}

String _xml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Total penurunan elevasi (meter), simetris dengan [routeElevationGain].
double routeElevationLoss(List<GpsPoint> pts, [double minStepM = 2.0]) {
  var loss = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final d = pts[i - 1].ele - pts[i].ele;
    if (d >= minStepM) loss += d;
  }
  return loss;
}

/// Kecepatan maksimum segmen (m/s), anti-noise: abaikan segmen dengan
/// dt ≤ 0 atau kecepatan mustahil (> [maxSpeedMs], GPS jump lolos filter).
double maxSpeedMs(List<GpsPoint> pts, [double maxSpeedMsCap = 22.2]) {
  var top = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final dt = (pts[i].t - pts[i - 1].t) / 1000.0;
    if (dt <= 0 || dt > 300) continue;
    final d =
        haversineM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    final v = d / dt;
    if (v > top && v <= maxSpeedMsCap) top = v;
  }
  return top;
}

/// Satu sampel profil elevasi: jarak kumulatif (km) + elevasi halus (m).
class ElevSample {
  final double distKm;
  final double eleM;
  const ElevSample(this.distKm, this.eleM);
}

/// Sampel elevasi untuk grafik (maks [maxPoints]), dengan moving-average
/// agar garis halus ala Strava dan noise GPS tidak bergerigi.
/// Mengembalikan [] bila tidak ada data elevasi (semua 0, mis. browser).
List<ElevSample> elevationSamples(List<GpsPoint> pts, [int maxPoints = 120]) {
  if (pts.length < 2) return const [];
  if (pts.every((p) => p.ele == 0)) return const [];
  // Jarak kumulatif per titik.
  final cum = List<double>.filled(pts.length, 0);
  for (var i = 1; i < pts.length; i++) {
    cum[i] = cum[i - 1] +
        haversineM(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
  }
  // Smoothing elevasi (window ±2).
  double smooth(int i) {
    var s = 0.0, n = 0;
    for (var k = i - 2; k <= i + 2; k++) {
      if (k >= 0 && k < pts.length) {
        s += pts[k].ele;
        n++;
      }
    }
    return s / n;
  }

  final step = (pts.length / maxPoints).ceil().clamp(1, 1 << 30);
  final out = <ElevSample>[];
  for (var i = 0; i < pts.length; i += step) {
    out.add(ElevSample(cum[i] / 1000.0, smooth(i)));
  }
  // Selalu tutup di finish agar grafik mencapai ujung.
  if ((out.isEmpty || out.last.distKm < cum.last / 1000.0) &&
      pts.length > 1) {
    out.add(ElevSample(cum.last / 1000.0, smooth(pts.length - 1)));
  }
  return out;
}

/// Split per [splitKm] (default tiap 1 km) ala Strava: waktu, kec. rata-rata,
/// dan gain elevasi pada segmen itu.
class KmSplit {
  final int index; // 1-based
  final double distKm; // panjang split aktual (terakhir bisa < splitKm)
  final int seconds;
  final double avgKmh;
  final double elevGainM;
  const KmSplit({
    required this.index,
    required this.distKm,
    required this.seconds,
    required this.avgKmh,
    required this.elevGainM,
  });
}

List<KmSplit> computeSplits(List<GpsPoint> pts, [double splitKm = 1.0]) {
  if (pts.length < 2 || splitKm <= 0) return const [];
  final splits = <KmSplit>[];
  var segStart = 0; // indeks titik awal split berjalan
  var nextMarkM = splitKm * 1000.0;
  var cumM = 0.0;
  int segStartT = pts.first.t;
  double segGain = 0.0;

  void flush(int endIdx, double splitLenM, int endT) {
    final sec = ((endT - segStartT) / 1000.0).round().clamp(0, 1 << 30);
    final avg = sec > 0 ? splitLenM / sec * 3.6 : 0.0;
    splits.add(KmSplit(
      index: splits.length + 1,
      distKm: splitLenM / 1000.0,
      seconds: sec,
      avgKmh: avg,
      elevGainM: segGain,
    ));
    segStart = endIdx;
    segStartT = endT;
    segGain = 0.0;
  }

  for (var i = 1; i < pts.length; i++) {
    final d = haversineM(
        pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    final de = pts[i].ele - pts[i - 1].ele;
    if (de >= 2.0) segGain += de;
    final prevCum = cumM;
    cumM += d;
    // Satu segmen GPS bisa melompati beberapa marker (jarang, tapi aman).
    while (cumM >= nextMarkM) {
      final frac = d > 0 ? (nextMarkM - prevCum) / d : 1.0;
      final endT = (pts[i - 1].t +
              ((pts[i].t - pts[i - 1].t) * frac.clamp(0.0, 1.0)))
          .round();
      flush(i, nextMarkM - (splits.fold<double>(
          0, (s, e) => s + e.distKm * 1000.0)), endT);
      nextMarkM += splitKm * 1000.0;
      if (splits.length > 1000) return splits; // guard ultra-ride
    }
  }
  // Sisa ekor (< splitKm, mis. 0,4 km terakhir) tetap ditampilkan.
  if (segStart < pts.length - 1) {
    final totalM = cumM;
    final doneM = splits.fold<double>(0, (s, e) => s + e.distKm * 1000.0);
    if (totalM - doneM > 50) {
      flush(pts.length - 1, totalM - doneM, pts.last.t);
    }
  }
  return splits;
}

/// Kecepatan rata-rata bergerak (km/h): abaikan jeda diam > [stillSpeedMs].
double movingAvgKmh(List<GpsPoint> pts, [double stillSpeedMs = 1.0]) {
  if (pts.length < 2) return 0;
  var dist = 0.0, moveSec = 0.0;
  for (var i = 1; i < pts.length; i++) {
    final d = haversineM(
        pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    final dt = (pts[i].t - pts[i - 1].t) / 1000.0;
    if (dt <= 0 || dt > 300) continue;
    final v = d / dt;
    if (v >= stillSpeedMs) {
      dist += d;
      moveSec += dt;
    }
  }
  if (moveSec <= 0) return 0;
  return dist / moveSec * 3.6;
}
