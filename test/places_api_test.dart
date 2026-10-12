import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:cycling_coach/src/core/places_api.dart';
import 'package:cycling_coach/src/core/premium.dart';
import 'package:cycling_coach/src/ui/widgets/route_map.dart';

void main() {
  test('searchPlaces query kosong tidak panggil network', () async {
    final out = await searchPlaces('   ');
    expect(out, isEmpty);
  });

  test('BikeRoute etaLabel: menit vs jam', () {
    const short = BikeRoute(points: [], distanceM: 5000, durationSec: 1500);
    expect(short.distanceKm, closeTo(5, 0.001));
    expect(short.etaLabel, '25 mnt');
    const long = BikeRoute(points: [], distanceM: 60000, durationSec: 5400);
    expect(long.etaLabel, '1j 30m');
  });

  test('Google Maps URIs valid (bicycling mode)', () {
    const from = LatLng(-6.2, 106.8);
    const to = LatLng(-6.3, 106.9);
    final dir = googleMapsDirUri(from, to);
    expect(dir.host, 'www.google.com');
    expect(dir.queryParameters['travelmode'], 'bicycling');
    expect(dir.queryParameters['origin'], '-6.2,106.8');
    expect(dir.queryParameters['destination'], '-6.3,106.9');
    final s = googleMapsSearchUri(to, 'Kawah');
    expect(s.queryParameters['query'], contains('-6.3'));
  });

  test('Kode donasi dinormalisasi + tervalidasi', () {
    expect(normalizeCode('  gowes-pro-2026 '), 'GOWES-PRO-2026');
    expect(isValidDonorCode('gowes-pro-2026'), isTrue);
    expect(isValidDonorCode('salah'), isFalse);
    expect(proPerks.length, 3);
  });

  test('Badge offline hanya setelah >=3 tile error', () {
    resetMapTileErrors();
    expect(mapTileErrorCount.value, 0);
    recordMapTileError();
    recordMapTileError();
    // 2 error = blip, badge tetap sembunyi (< 3).
    expect(mapTileErrorCount.value, 2);
    recordMapTileError();
    expect(mapTileErrorCount.value, greaterThanOrEqualTo(3));
    resetMapTileErrors();
    expect(mapTileErrorCount.value, 0);
  });

  test('fetchBikeRoute parse OSRM primer (tanpa key)', () async {
    final body = json.encode({
      'routes': [
        {
          'distance': 5200.0,
          'duration': 1560.0,
          'geometry': {
            'coordinates': [
              [106.8, -6.2],
              [106.81, -6.21],
              [106.82, -6.22],
            ],
          },
        },
      ],
    });
    final client = MockClient((req) async {
      expect(req.url.host, 'router.project-osrm.org');
      expect(req.url.path, contains('bicycle'));
      return http.Response(body, 200);
    });
    final r = await fetchBikeRoute(
        const LatLng(-6.2, 106.8), const LatLng(-6.22, 106.82),
        client: client);
    expect(r, isNotNull);
    expect(r!.points.length, 3);
    expect(r.distanceKm, closeTo(5.2, 0.01));
  });

  test('fetchBikeRoute fallback ke server kedua bila primer gagal', () async {
    final body = json.encode({
      'routes': [
        {
          'distance': 3000.0,
          'duration': 900.0,
          'geometry': {
            'coordinates': [
              [106.8, -6.2],
              [106.83, -6.23],
            ],
          },
        },
      ],
    });
    final client = MockClient((req) async {
      if (req.url.host == 'router.project-osrm.org') {
        return http.Response('down', 500);
      }
      expect(req.url.host, 'routing.openstreetmap.de');
      return http.Response(body, 200);
    });
    final r = await fetchBikeRoute(
        const LatLng(-6.2, 106.8), const LatLng(-6.23, 106.83),
        client: client);
    expect(r, isNotNull);
    expect(r!.distanceKm, closeTo(3.0, 0.01));
  });

  test('fetchBikeRoute null bila dua server gagal', () async {
    final client =
        MockClient((_) async => http.Response('err', 500));
    final r = await fetchBikeRoute(
        const LatLng(-6.2, 106.8), const LatLng(-6.23, 106.83),
        client: client);
    expect(r, isNull);
  });

  test('reverseGeocode label jalan, fallback koordinat saat offline',
      () async {
    final ok = MockClient((req) async {
      expect(req.url.host, 'nominatim.openstreetmap.org');
      return http.Response(
          json.encode({
            'display_name':
                'Jalan Sudirman, Jakarta Selatan, DKI Jakarta, Indonesia'
          }),
          200);
    });
    expect(
        await reverseGeocode(const LatLng(-6.2, 106.8), client: ok),
        contains('Jalan Sudirman'));
    final down =
        MockClient((_) async => http.Response('err', 500));
    expect(await reverseGeocode(const LatLng(-6.2, 106.8), client: down),
        contains('-6.2'));
  });
}
