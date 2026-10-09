import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Hasil pencarian tempat ala GMaps (via Nominatim OSM, gratis tanpa API key).
class PlaceResult {
  final String name;
  final String address;
  final double lat;
  final double lng;
  const PlaceResult({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });
  LatLng get latLng => LatLng(lat, lng);
}

/// Cari tempat: "sudirman", "bandung", "kawah putih", ...
/// [near] opsional untuk bias hasil ke sekitar user (viewbox).
/// Tidak pernah throw — kembalikan [] bila offline / limit.
Future<List<PlaceResult>> searchPlaces(
  String query, {
  LatLng? near,
  http.Client? client,
}) async {
  final q = query.trim();
  if (q.isEmpty) return const [];
  client ??= http.Client();
  try {
    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'accept-language': 'id',
    };
    if (near != null) {
      // viewbox ~40km sekitar user agar "kopi" = kopi terdekat dulu.
      params['viewbox'] =
          '${near.longitude - 0.2},${near.latitude + 0.2},${near.longitude + 0.2},${near.latitude - 0.2}';
      params['bounded'] = '0';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final res = await client
        .get(uri, headers: {
          // Wajib oleh usage policy Nominatim — tanpa UA bisa 403.
          'User-Agent': 'cycling_coach/1.0 (contact: cyclingcoach.app)',
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return const [];
    final decoded = json.decode(res.body);
    if (decoded is! List) return const [];
    final out = <PlaceResult>[];
    for (final e in decoded) {
      if (e is! Map) continue;
      final lat = double.tryParse('${e['lat']}');
      final lng = double.tryParse('${e['lon']}');
      if (lat == null || lng == null) continue;
      final display = '${e['display_name'] ?? ''}';
      final parts = display.split(',').map((s) => s.trim()).toList();
      final name =
          (parts.isNotEmpty && parts.first.isNotEmpty) ? parts.first : q;
      final address = parts.length > 1
          ? parts.skip(1).take(3).join(', ')
          : display;
      out.add(PlaceResult(
          name: name,
          address: address,
          lat: lat,
          lng: lng));
    }
    return out;
  } catch (_) {
    return const [];
  }
}

/// Rute sepeda ala GMaps directions (via OSRM demo, gratis tanpa API key).
class BikeRoute {
  final List<LatLng> points;
  final double distanceM;
  final double durationSec;
  const BikeRoute({
    required this.points,
    required this.distanceM,
    required this.durationSec,
  });
  double get distanceKm => distanceM / 1000.0;
  String get etaLabel {
    final m = (durationSec / 60).round();
    if (m < 60) return '$m mnt';
    return '${m ~/ 60}j ${m % 60}m';
  }
}

/// Minta rute sepeda [from] → [to]. Kembalikan null bila offline / tak ada jalan.
Future<BikeRoute?> fetchBikeRoute(LatLng from, LatLng to,
    {http.Client? client}) async {
  client ??= http.Client();
  try {
    // OSRM format: {lng},{lat};{lng},{lat}
    final coords =
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.https('router.project-osrm.org',
        '/route/v1/bicycle/$coords', {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
    });
    final res = await client
        .get(uri, headers: {
          'User-Agent': 'cycling_coach/1.0',
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final decoded = json.decode(res.body);
    if (decoded is! Map || decoded['routes'] is! List) return null;
    final routes = decoded['routes'] as List;
    if (routes.isEmpty || routes.first is! Map) return null;
    final r = routes.first as Map;
    final geom = (r['geometry'] as Map?)?['coordinates'];
    if (geom is! List || geom.isEmpty) return null;
    final pts = <LatLng>[];
    for (final c in geom) {
      if (c is List && c.length >= 2) {
        final lng = (c[0] as num?)?.toDouble();
        final lat = (c[1] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        pts.add(LatLng(lat, lng));
      }
      if (pts.length > 10000) break;
    }
    if (pts.length < 2) return null;
    return BikeRoute(
      points: pts,
      distanceM: ((r['distance'] as num?)?.toDouble() ?? 0),
      durationSec: ((r['duration'] as num?)?.toDouble() ?? 0),
    );
  } catch (_) {
    return null;
  }
}

/// Link "Buka di Google Maps" untuk navigasi turn-by-turn beneran.
Uri googleMapsDirUri(LatLng from, LatLng to) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1&origin=${from.latitude},${from.longitude}&destination=${to.latitude},${to.longitude}&travelmode=bicycling');

/// Link pencarian GMaps untuk satu titik (fallback bila OSRM gagal).
Uri googleMapsSearchUri(LatLng p, String label) => Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}(${Uri.encodeComponent(label)})');
