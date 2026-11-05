import 'package:cycling_coach/src/models/models.dart';
import 'package:cycling_coach/src/models/planned_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('PlannedRoute.fromGpsPoints', () {
    test('menghitung jarak, elevasi, dan durasi dari timestamp', () {
      final route = PlannedRoute.fromGpsPoints(const [
        GpsPoint(lat: -6.2000, lng: 106.8000, ele: 10, t: 1700000000000),
        GpsPoint(lat: -6.2010, lng: 106.8010, ele: 12, t: 1700000300000),
        GpsPoint(lat: -6.2020, lng: 106.8020, ele: 15, t: 1700000600000),
      ], name: '  Audax 200K  ');

      expect(route.name, 'Audax 200K');
      expect(route.source, PlannedRouteSource.gpx);
      expect(route.sourcePointCount, 3);
      expect(route.hasRoute, isTrue);
      expect(route.distanceM, greaterThan(0));
      expect(route.elevationGainM, 5);
      expect(route.durationSec, 600);
      expect(route.start!.latitude, -6.2000);
      expect(route.finish!.longitude, 106.8020);
      expect(route.summaryLine, contains('↑ 5 m'));
      expect(route.summaryLine, contains('10 mnt'));
    });

    test('fallback durasi 20 km/jam bila GPX tanpa timestamp', () {
      final route = PlannedRoute.fromGpsPoints(const [
        GpsPoint(lat: -6.2000, lng: 106.8000, t: 0),
        GpsPoint(lat: -6.2100, lng: 106.8100, t: 0),
      ], name: '');

      expect(route.name, 'Rute GPX');
      expect(route.durationSec, closeTo(route.distanceM / (20 / 3.6), 0.01));
    });
  });

  group('PlannedRoute.fromLatLngs', () {
    test('mempertahankan metadata OSRM dan format ETA', () {
      final route = PlannedRoute.fromLatLngs(
        const [LatLng(-6.2, 106.8), LatLng(-6.21, 106.81)],
        name: 'Rute Jelajah',
        distanceM: 12345,
        durationSec: 3900,
        elevationGainM: 120,
        source: PlannedRouteSource.osrm,
      );

      expect(route.hasRoute, isTrue);
      expect(route.distanceKm, 12.345);
      expect(route.etaLabel, '1j 5m');
      expect(route.summaryLine, '12.3 km • ↑ 120 m • ~1j 5m gowes');
      expect(route.source, PlannedRouteSource.osrm);
    });

    test('rute kosong aman untuk UI (tanpa crash)', () {
      final route = PlannedRoute.fromLatLngs(
        const [],
        name: '',
        source: PlannedRouteSource.manual,
      );

      expect(route.hasRoute, isFalse);
      expect(route.start, isNull);
      expect(route.finish, isNull);
      expect(route.distanceLabel, '-');
      expect(route.etaLabel, '-');
      expect(route.displayName, 'Rute Manual');
      expect(route.summaryLine, '-');
    });
  });
}
