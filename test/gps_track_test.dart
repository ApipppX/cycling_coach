import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cycling_coach/src/models/models.dart';
import 'package:cycling_coach/src/core/geo_utils.dart';

List<GpsPoint> line(int n, {double stepM = 10}) {
  // ~stepM meter ke timur per titik dari Jakarta.
  const baseLat = -6.2, baseLng = 106.8;
  const mPerDegLng = 111320 * 0.993; // cos(6.2°)
  return List.generate(
      n,
      (i) => GpsPoint(
          lat: baseLat,
          lng: baseLng + (i * stepM) / mPerDegLng,
          ele: i * 1.0,
          t: i * 5000));
}

void main() {
  test('haversine 100 m akurat', () {
    // 0.0008983° lat ≈ 100 m.
    expect(haversineM(0, 0, 0.0008983, 0), closeTo(100, 1.0));
  });

  test('jarak rute = jumlah segmen', () {
    final pts = line(5, stepM: 10);
    expect(routeDistanceM(pts), closeTo(40, 1.5));
  });

  test('filter buang akurasi buruk & GPS jump', () {
    final fixes = [
      const RawGpsFix(-6.2, 106.8, 0, 0, 5),
      const RawGpsFix(-6.2, 106.8001, 0, 5000, 99), // akurasi jelek
      const RawGpsFix(0, 0, 0, 10000, 5), // jump ke Atlantic
      const RawGpsFix(-6.2, 106.8002, 0, 15000, 5),
    ];
    final out = filterRawPoints(fixes);
    expect(out.length, 2); // pertama + terakhir valid
  });

  test('simplify pertahankan start/finish + hemat poin', () {
    final pts = line(50, stepM: 10);
    final s = simplifyRoute(pts, 4);
    expect(s.first.lat, pts.first.lat);
    expect(s.last.lng, pts.last.lng);
    expect(s.length, lessThan(pts.length));
  });

  test('encode/decode roundtrip + rusak aman', () {
    final pts = line(4);
    final enc = encodeRoute(pts);
    final dec = decodeRoute(enc);
    expect(dec.length, 4);
    expect(dec.first.lat, closeTo(pts.first.lat, 1e-5));
    expect(decodeRoute(''), isEmpty);
    expect(decodeRoute('bukan-json{{{'), isEmpty);
    expect(decodeRoute('{"a":1}'), isEmpty);
  });

  test('elevasi abaikan noise kecil', () {
    final pts = [
      const GpsPoint(lat: 0, lng: 0, ele: 10, t: 0),
      const GpsPoint(lat: 0, lng: 0.0001, ele: 10.5, t: 1), // +0.5 abaikan
      const GpsPoint(lat: 0, lng: 0.0002, ele: 13.5, t: 2), // +3.0 hitung
    ];
    expect(routeElevationGain(pts), closeTo(3.0, 0.01));
  });

  test('GPX valid + lolos XML escape', () {
    final pts = line(2);
    final gpx = buildGpx('A&B <ride>', pts, DateTime.utc(2026, 1, 1));
    expect(gpx, contains('<gpx'));
    expect(gpx, contains('A&amp;B &lt;ride&gt;'));
    expect(gpx, contains('<trkpt'));
  });

  test('elev loss simetris dengan gain', () {
    final pts = [
      const GpsPoint(lat: 0, lng: 0, ele: 10, t: 0),
      const GpsPoint(lat: 0, lng: 0.001, ele: 20, t: 60000),
      const GpsPoint(lat: 0, lng: 0.002, ele: 12, t: 120000),
    ];
    expect(routeElevationGain(pts), closeTo(10, 0.01));
    expect(routeElevationLoss(pts), closeTo(8, 0.01));
  });

  test('max speed abaikan segmen mustahil', () {
    final pts = [
      const GpsPoint(lat: -6.2, lng: 106.8, ele: 0, t: 0),
      // 10 m dalam 5 dtk = 2 m/s.
      const GpsPoint(lat: -6.2, lng: 106.80009, ele: 0, t: 5000),
      // Jump 5 km dalam 1 dtk → diabaikan.
      const GpsPoint(lat: -6.15, lng: 106.8, ele: 0, t: 6000),
    ];
    final v = maxSpeedMs(pts);
    expect(v, closeTo(2.0, 0.3));
    expect(v, lessThan(22.2));
  });

  test('elevation samples halus + tutup di finish', () {
    final pts = line(50, stepM: 20);
    final s = elevationSamples(pts, 10);
    expect(s.length, lessThanOrEqualTo(11));
    expect(s.first.distKm, closeTo(0, 0.01));
    expect(s.last.distKm, closeTo(routeDistanceM(pts) / 1000, 0.05));
    // Tanpa altitude → kosong (placeholder UI).
    final flat = [
      const GpsPoint(lat: 0, lng: 0, t: 0),
      const GpsPoint(lat: 0, lng: 0.001, t: 1000),
    ];
    expect(elevationSamples(flat), isEmpty);
  });

  test('splits per km + ekor pendek', () {
    // 2,3 km @ 1 m/s (3,6 km/h) → split 1, 2 penuh + ekor 0,3.
    final pts = List.generate(
        231,
        (i) => GpsPoint(
            lat: -6.2,
            lng: 106.8 + i * 10 / 110567.0,
            ele: (i % 50).toDouble(),
            t: i * 10000));
    final totalKm = routeDistanceM(pts) / 1000;
    final splits = computeSplits(pts, 1.0);
    expect(splits.length, 3);
    expect(splits[0].distKm, closeTo(1.0, 0.05));
    expect(splits[2].distKm, closeTo(totalKm - 2.0, 0.05));
    expect(splits[0].seconds, greaterThan(0));
    expect(splits[0].avgKmh, closeTo(3.6, 0.5));
    // Nomor urut 1-based.
    expect(splits.map((s) => s.index).toList(), [1, 2, 3]);
  });

  test('CyclingActivity GPS: durationMin pakai durationSec', () {    const a = CyclingActivity(
      name: 'GPS',
      distance: 10000,
      totalElevationGain: 50,
      averageSpeed: 5,
      startDate: '2026-10-01T07:00:00Z',
      durationSec: 3600,
      routeJson: '[[1,2,3,4]]',
    );
    expect(a.durationMin, 60);
    expect(a.hasRoute, isTrue);
    const manual = CyclingActivity(
      name: 'M',
      distance: 10000,
      totalElevationGain: 0,
      averageSpeed: 5,
      startDate: '2026-10-01T07:00:00Z',
    );
    expect(manual.durationMin, closeTo(33.33, 0.1));
    expect(manual.hasRoute, isFalse);
  });

  test('moving time + avg abaikan diam', () {
    // 10 m/5 dtk (2 m/s = 7,2 km/h) lalu diam 60 dtk di tempat.
    final pts = [
      const GpsPoint(lat: -6.2, lng: 106.8, ele: 0, t: 0),
      const GpsPoint(lat: -6.2, lng: 106.80009, ele: 0, t: 5000),
      const GpsPoint(lat: -6.2, lng: 106.80009, ele: 0, t: 65000),
    ];
    expect(movingTimeSec(pts), closeTo(5, 0.5));
    expect(movingAvgKmh(pts), closeTo(7.2, 0.6));
  });

  test('fastest split = avg tertinggi + ele min-maks', () {
    final pts = List.generate(
        231,
        (i) => GpsPoint(
            lat: -6.2,
            lng: 106.8 + i * 10 / 110567.0,
            ele: (i % 50).toDouble(),
            t: i * 10000));
    final splits = computeSplits(pts, 1.0);
    final fast = fastestSplit(splits);
    expect(fast, isNotNull);
    expect(fast!.avgKmh,
        splits.map((s) => s.avgKmh).reduce((a, b) => a > b ? a : b));
    expect(fastestSplit(const []), isNull);
    final mm = eleMinMax(pts);
    expect(mm.max, greaterThan(mm.min));
    expect(eleMinMax(const []).min, 0);
  });

  group('TrackFilter (akurasi live ala Strava)', () {
    test('titik pertama butuh akurasi <= 15 m', () {
      final f = TrackFilter();
      expect(
          f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 30, speedMs: 5),
          isNull);
      expect(f.hasFix, isFalse);
      final p = f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 8, speedMs: 5);
      expect(p, isNotNull);
      expect(f.hasFix, isTrue);
    });

    test('diam (Doppler < 0,5 m/s) dibekukan, jarak tak merambat', () {
      final f = TrackFilter();
      f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 5, speedMs: 6);
      // 10 fix diam 8 m bergeser (noise) selama 30 dtk → semua dibuang.
      for (var i = 1; i <= 10; i++) {
        final p = f.add(
            lat: -6.2 + i * 0.00001,
            lng: 106.8,
            ele: 0,
            t: i * 3000,
            acc: 5,
            speedMs: 0.0);
        expect(p, isNull, reason: 'fix diam ke-$i harus dibekukan');
      }
    });

    test('bergerak normal lolos tiap >= 1 dtk', () {
      final f = TrackFilter();
      f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 5, speedMs: 6);
      // ~6 m/dtk ke timur.
      final p = f.add(
          lat: -6.2, lng: 106.8 + 6 / 110567.0, ele: 0, t: 1000, acc: 5, speedMs: 6);
      expect(p, isNotNull);
      // Burst < 1 dtk dibuang.
      expect(
          f.add(
              lat: -6.2,
              lng: 106.8 + 7 / 110567.0,
              ele: 0,
              t: 1500,
              acc: 5,
              speedMs: 6),
          isNull);
    });

    test('GPS jump > 80 km/h dibuang', () {
      final f = TrackFilter();
      f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 5, speedMs: 8);
      expect(
          f.add(lat: 0, lng: 0.001, ele: 0, t: 1000, acc: 5, speedMs: 8),
          isNull);
    });

    test('akurasi jalan > 25 m dibuang', () {
      final f = TrackFilter();
      f.add(lat: -6.2, lng: 106.8, ele: 0, t: 0, acc: 5, speedMs: 6);
      expect(
          f.add(
              lat: -6.2,
              lng: 106.8001,
              ele: 0,
              t: 5000,
              acc: 40,
              speedMs: 6),
          isNull);
    });

    test('elevasi di-smoothing (noise +-8 m tak menggelembungkan gain)', () {
      final f = TrackFilter();
      const baseLat = -6.2, baseLng = 106.8;
      for (var i = 0; i < 6; i++) {
        // Dataran: altitude mentah berosilasi 100/108.
        f.add(
            lat: baseLat,
            lng: baseLng + i * 10 / 110567.0,
            ele: i.isEven ? 100.0 : 108.0,
            t: i * 2000,
            acc: 5,
            speedMs: 6);
      }
      expect(f.last, isNotNull);
      // Rata-rata window terakhir ≈ 104, bukan 108.
      expect(f.last!.ele, closeTo(104, 3.0));
    });

    test('cyclingLocationSettings valid di semua platform', () {
      final s = cyclingLocationSettings();
      expect(s.accuracy, LocationAccuracy.bestForNavigation);
      expect(s.distanceFilter, 3);
    });
  });
}
