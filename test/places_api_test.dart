import 'package:flutter_test/flutter_test.dart';
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
}
