import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/models.dart';
import '../../core/geo_utils.dart';

/// Tile OSM primer (stack yang sama dipakai Leaflet.js di web).
/// flutter_map sama dengan Leaflet untuk Flutter: TileLayer + Polyline + Marker.
///
/// PENTING (bug peta blank di HP):
/// - Android WAJIB punya `INTERNET` permission di AndroidManifest.
///   Tanpa itu tile gagal dimuat → abu-abu + log "flutter_map" berulang.
/// - OSM kadang rate-limit (403). [fallbackUrl] Carto Light memastikan
///   peta tetap tampil walau OSM menolak.
/// - [errorTileCallback] dikosongkan agar terminal tidak dispam stacktrace
///   per-tile; user cukup lihat peta fallback / tombol muat ulang.
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _darkUrl =
    'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
const _fallbackUrl =
    'https://a.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png';
const _osmAttribution = '© OpenStreetMap · © CARTO';
const _appPackage = 'com.example.cycling_coach';

/// Penghitung error tile global per sesi jalan-nya app.
///
/// Latar: badge "wifi mati" yang SELALU tampil membuat user mengira peta
/// rusak padahal internet baik-baik saja. Sekarang [MapOfflineHint] hanya
/// muncul bila tile BENAR-BENAR gagal dimuat (offline / OSM 403), dan bisa
/// di-dismiss. Ambang 3 agar satu blip jaringan tak memicu badge.
final mapTileErrorCount = ValueNotifier<int>(0);

void recordMapTileError() {
  if (mapTileErrorCount.value < 1000000) mapTileErrorCount.value++;
}

void resetMapTileErrors() => mapTileErrorCount.value = 0;

/// Satu-satunya konstruktor TileLayer yang dipakai seluruh app.
/// Konsisten → sekali perbaiki, semua peta (rekam/detail/jelajah) ikut sembuh.
/// [dark] = gaya Dark Matter, enak untuk gowes malam (keuntungan PRO).
TileLayer osmTiles({bool dark = false}) {
  return TileLayer(
    urlTemplate: dark ? _darkUrl : _osmUrl,
    fallbackUrl: _fallbackUrl,
    userAgentPackageName: _appPackage,
    // Jangan spam terminal saat offline / 403: cukup fallback yang tampil.
    // Error-nya dicatat ke [mapTileErrorCount] agar UI bisa menjelaskan
    // dengan badge, bukan layar abu-abu misterius.
    errorTileCallback: (tile, error, stack) => recordMapTileError(),
  );
}

LatLngBounds? boundsOf(List<LatLng> pts) {
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
  // Padding agar start/finish tak mepet tepi. Kalau 1 titik / garis
  // sangat pendek, kembangkan paksa agar CameraFit tak over-zoom / crash.
  var pad = 0.002;
  if ((maxLat - minLat).abs() < 0.0005) pad = 0.005;
  if ((maxLng - minLng).abs() < 0.0005) pad = 0.005;
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
    final pts =
        decodeRoute(routeJson).map((p) => LatLng(p.lat, p.lng)).toList();
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
    final bounds = boundsOf(pts)!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: bounds,
              padding: const EdgeInsets.all(24),
              maxZoom: 17,
            ),
            interactionOptions: InteractionOptions(
                flags: interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none),
          ),
          children: [
            osmTiles(),
            PolylineLayer(
              polylines: [
                Polyline(
                    points: pts, strokeWidth: 4.5, color: scheme.primary),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pts.first,
                  width: 30,
                  height: 30,
                  child: const _Pin(
                      color: Colors.green, icon: Icons.play_arrow_rounded),
                ),
                Marker(
                  point: pts.last,
                  width: 30,
                  height: 30,
                  child: _Pin(
                      color: scheme.primary, icon: Icons.flag_rounded),
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
  final bool dark;
  const LiveTrackMap({
    super.key,
    required this.points,
    required this.controller,
    this.currentLat,
    this.currentLng,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trail = points.map((p) => LatLng(p.lat, p.lng)).toList();
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
        osmTiles(dark: dark),
        if (trail.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                  points: trail, strokeWidth: 5, color: scheme.primary),
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

/// Tombol zoom +/- ala GMaps. Butuh [controller] yang sama dengan FlutterMap.
class MapZoomButtons extends StatelessWidget {
  final MapController controller;
  const MapZoomButtons({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _zoomBtn(context, Icons.add, () {
        try {
          controller.move(
              controller.camera.center, controller.camera.zoom + 1);
        } catch (_) {}
      }),
      const SizedBox(height: 8),
      _zoomBtn(context, Icons.remove, () {
        try {
          controller.move(
              controller.camera.center, controller.camera.zoom - 1);
        } catch (_) {}
      }),
    ]);
  }

  Widget _zoomBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      elevation: 2,
      shape: const CircleBorder(),
      color: Theme.of(context).colorScheme.surface,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

/// Badge penjelasan bila (dan hanya bila) tile peta gagal dimuat.
/// Muncul dengan tombol tutup; geser/zoom memicu muat ulang otomatis.
class MapOfflineHint extends StatelessWidget {
  const MapOfflineHint({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mapTileErrorCount,
      builder: (context, errors, _) {
        if (errors < 3) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.only(left: 10, right: 4, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.wifi_off_outlined,
                size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Peta gagal dimuat — cek internet lalu geser/zoom',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            InkWell(
              customBorder: const CircleBorder(),
              onTap: resetMapTileErrors,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ]),
        );
      },
    );
  }
}
