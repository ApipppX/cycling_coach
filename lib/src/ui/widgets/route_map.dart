import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../core/geo_utils.dart';

/// Tile OpenStreetMap standar (stack yang sama dipakai Leaflet.js di web).
/// flutter_map = "Leaflet untuk Flutter": TileLayer + PolylineLayer + MarkerLayer.
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _osmAttribution = '© OpenStreetMap contributors';

LatLngBounds? _boundsOf(List<LatLng> pts) {
  if (pts.isEmpty) return null;
  var minLat = pts.first.latitude,
      maxLat = pts.first.latitude,
      minLng = pts.first.longitude,
      maxLng = pts.first.longitude;
  for (final p in pts) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  // Padding agar start/finish tak mepet tepi.
  const pad = 0.002;
  return LatLngBounds(
    LatLng(minLat - pad, minLng - pad),
    LatLng(maxLat + pad, maxLng + pad),
  );
}

/// Peta rute statis untuk DetailScreen / riwayat (Strava-like).
/// [routeJson] kosong → tampilkan placeholder, bukan crash.
class RouteMap extends StatelessWidget {
  final String routeJson;
  final double height;
  final bool interactive;
  const RouteMap({
    super.key,
    required this.routeJson,
    this.height = 220,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final pts = decodeRoute(routeJson)
        .map((p) => LatLng(p.lat, p.lng))
        .toList();
    final scheme = Theme.of(context).colorScheme;
    if (pts.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.map_outlined,
              size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 6),
          Text('Tanpa rute GPS',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          Text('Sesi manual / impor CSV',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant)),
        ]),
      );
    }
    final bounds = _boundsOf(pts)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit:
                CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(24)),
            interactionOptions: InteractionOptions(
                flags: interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate: _osmUrl,
              userAgentPackageName: 'com.example.cycling_coach',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                    points: pts,
                    strokeWidth: 4.5,
                    color: scheme.primary),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pts.first,
                  width: 30,
                  height: 30,
                  child: _Pin(
                      color: Colors.green,
                      icon: Icons.play_arrow_rounded),
                ),
                Marker(
                  point: pts.last,
                  width: 30,
                  height: 30,
                  child: _Pin(
                      color: scheme.primary,
                      icon: Icons.flag_rounded),
                ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution(_osmAttribution),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _Pin({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(blurRadius: 4, color: Colors.black26)
          ]),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

/// Peta live untuk layar Rekam: ikuti posisi + gambar jejak berjalan.
class LiveTrackMap extends StatelessWidget {
  final List<GpsPoint> points;
  final double? currentLat;
  final double? currentLng;
  final MapController controller;
  const LiveTrackMap({
    super.key,
    required this.points,
    required this.controller,
    this.currentLat,
    this.currentLng,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trail =
        points.map((p) => LatLng(p.lat, p.lng)).toList();
    final center = currentLat != null && currentLng != null
        ? LatLng(currentLat!, currentLng!)
        : (trail.isNotEmpty
            ? trail.last
            : const LatLng(-6.2, 106.8)); // Jakarta fallback
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
        minZoom: 3,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: _osmUrl,
          userAgentPackageName: 'com.example.cycling_coach',
        ),
        if (trail.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                  points: trail,
                  strokeWidth: 5,
                  color: scheme.primary),
            ],
          ),
        if (currentLat != null && currentLng != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(currentLat!, currentLng!),
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution(_osmAttribution)],
        ),
      ],
    );
  }
}
