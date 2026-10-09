import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/places_api.dart';
import '../widgets/route_map.dart';

/// Layar Jelajah ala GMaps (tapi tile OSM, gratis tanpa API key):
/// - Cari tempat (Nominatim) → pindah kamera + pin.
/// - Tap peta untuk pasang tujuan → rute sepeda otomatis (OSRM).
/// - Lokasi saya, zoom +/-, buka navigasi di Google Maps, bagikan.
///
/// Semua network call aman-offline: gagal → snackbar, peta tetap tampil
/// (fallback Carto) + tidak pernah blank tanpa penjelasan.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreState();
}

class _ExploreState extends State<ExploreScreen> {
  final _map = MapController();
  final _search = TextEditingController();
  Timer? _debounce;

  LatLng _center = const LatLng(-6.2, 106.8); // Jakarta awal
  LatLng? _myLoc;
  bool _locating = false;

  List<PlaceResult> _results = [];
  bool _searching = false;
  PlaceResult? _picked;

  LatLng? _dest;
  BikeRoute? _route;
  bool _routing = false;
  String? _routeErr;

  @override
  void initState() {
    super.initState();
    _goMyLocation(auto: true);
  }

  @override
  void dispose() {
    _map.dispose();
    _search.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------- lokasi ----------

  Future<void> _goMyLocation({bool auto = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!auto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('GPS mati — nyalakan Location di pengaturan HP.')));
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!auto && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Izin lokasi ditolak — peta tetap bisa dijelajah manual.')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.high))
          .timeout(const Duration(seconds: 15));
      final ll = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _myLoc = ll;
        _center = ll;
      });
      try {
        _map.move(ll, 15);
      } catch (_) {}
    } catch (e) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal ambil lokasi: $e')));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  // ---------- cari tempat ----------

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final out = await searchPlaces(v, near: _myLoc ?? _center);
      if (!mounted) return;
      setState(() {
        _results = out;
        _searching = false;
      });
    });
  }

  void _pickPlace(PlaceResult p) {
    setState(() {
      _picked = p;
      _results = [];
      _search.text = p.name;
    });
    try {
      _map.move(p.latLng, 15);
    } catch (_) {}
    // Jadikan tujuan otomatis agar user langsung dapat rute.
    _setDest(p.latLng);
    FocusScope.of(context).unfocus();
  }

  // ---------- rute ----------

  Future<void> _setDest(LatLng d) async {
    setState(() {
      _dest = d;
      _route = null;
      _routeErr = null;
    });
    final o = _myLoc;
    if (o == null) {
      // Tanpa GPS tetap tampilkan pin + ajak user nyalakan lokasi.
      setState(() =>
          _routeErr = 'Nyalakan GPS untuk rute sepeda — pin tujuan sudah dipasang.');
      return;
    }
    setState(() => _routing = true);
    final r = await fetchBikeRoute(o, d);
    if (!mounted) return;
    setState(() {
      _routing = false;
      if (r == null) {
        _routeErr =
            'Rute sepeda tak ditemukan (offline / jalan tak tersambung). Coba titik lain atau buka di Google Maps.';
      } else {
        _route = r;
        try {
          final b = boundsOf(r.points);
          if (b != null) {
            _map.fitCamera(CameraFit.bounds(
                bounds: b,
                padding: const EdgeInsets.fromLTRB(48, 120, 48, 220),
                maxZoom: 16));
          }
        } catch (_) {}
      }
    });
  }

  void _clearRoute() {
    setState(() {
      _dest = null;
      _route = null;
      _routeErr = null;
      _picked = null;
    });
  }

  Future<void> _openGmaps() async {
    final o = _myLoc;
    final d = _dest;
    if (d == null) return;
    final uri = o == null
        ? googleMapsSearchUri(d, _picked?.name ?? 'Tujuan')
        : googleMapsDirUri(o, d);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tak bisa membuka Google Maps.')));
      }
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markers = <Marker>[
      if (_myLoc != null)
        Marker(
          point: _myLoc!,
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
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
          ),
        ),
      if (_dest != null)
        Marker(
          point: _dest!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin,
              color: Colors.red, size: 40),
        ),
      if (_picked != null && _dest == null)
        Marker(
          point: _picked!.latLng,
          width: 40,
          height: 40,
          child: Icon(Icons.location_pin,
              color: scheme.primary, size: 40),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Jelajah')),
      body: Column(children: [
        // Bar cari ala GMaps.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(children: [
            SearchBar(
              controller: _search,
              hintText: 'Cari tempat, jalan, kota…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Hapus',
                    onPressed: () {
                      _search.clear();
                      setState(() => _results = []);
                    },
                  ),
              ],
              elevation: const WidgetStatePropertyAll(1),
              onChanged: _onSearchChanged,
              onSubmitted: (v) async {
                final out =
                    await searchPlaces(v, near: _myLoc ?? _center);
                if (!context.mounted) return;
                if (out.isNotEmpty) {
                  _pickPlace(out.first);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Tempat tak ditemukan — cek ejaan / internet.')));
                }
              },
            ),
            if (_results.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(top: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _results.length.clamp(0, 5),
                  separatorBuilder: (a, b) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text(p.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      onTap: () => _pickPlace(p),
                    );
                  },
                ),
              ),
          ]),
        ),
        // Peta.
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 13,
                    minZoom: 3,
                    maxZoom: 19,
                    // Tap = pasang tujuan (semudah drop pin di GMaps).
                    onTap: (_, ll) => _setDest(ll),
                  ),
                  children: [
                    osmTiles(),
                    if (_route != null)
                      PolylineLayer(polylines: [
                        Polyline(
                            points: _route!.points,
                            strokeWidth: 5,
                            color: scheme.primary),
                      ]),
                    MarkerLayer(markers: markers),
                    const RichAttributionWidget(attributions: [
                      TextSourceAttribution('© OpenStreetMap · © CARTO')
                    ]),
                  ],
                ),
                // Zoom kanan-bawah + lokasi di atasnya.
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'explore_myloc',
                          tooltip: 'Lokasi saya',
                          onPressed: _goMyLocation,
                          child: _locating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))
                              : const Icon(Icons.my_location),
                        ),
                        const SizedBox(height: 8),
                        MapZoomButtons(controller: _map),
                      ]),
                ),
                const Positioned(
                  left: 10,
                  bottom: 10,
                  child: MapOfflineHint(),
                ),
                if (_routing)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(children: [
                        SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Mencari rute sepeda…'),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        // Panel rute bawah ala GMaps.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _bottomPanel(context),
        ),
      ]),
    );
  }

  Widget _bottomPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_dest == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Tap peta untuk pasang pin tujuan, atau cari tempat di atas — rute sepeda otomatis dibuat.',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.directions_bike,
                color: scheme.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _picked?.name ?? 'Tujuan kustom',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _route != null
                          ? '${_route!.distanceKm.toStringAsFixed(1)} km • ~${_route!.etaLabel} gowes'
                          : (_routeErr ?? 'Menghitung…'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Hapus rute',
              onPressed: _clearRoute,
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('Google Maps'),
                onPressed: _openGmaps,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('Rute ulang'),
                onPressed: _dest == null
                    ? null
                    : () => _setDest(_dest!),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
