import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/geo_utils.dart';
import '../../core/places_api.dart';
import '../../core/premium.dart';
import '../../models/models.dart';
import '../widgets/pro_paywall.dart';
import '../widgets/route_map.dart';
import 'track_screen.dart' show TrackScreen, shareGpx;

/// Layar Jelajah ala GMaps — tapi 100% TANPA API key:
/// tile murni OpenStreetMap (primer) + HOT (fallback), cari tempat via
/// Nominatim, rute sepeda via OSRM (profil bicycle = ramah gowes, hindari
/// jalan tol), nama jalan via Nominatim reverse.
///
/// - Kolom **Dari** + **Ke** (seperti GMaps): ketik cari, tombol tukar,
///   "Posisi saya", atau tap peta (mode pin Dari/Tujuan).
/// - Tombol **Mulai** = navigasi di DALAM app (peta mengikuti + sisa jarak
///   live + ETA + notif sampai) — tak perlu buka GMaps.
/// - **Rekam rute ini** = buka layar Rekam GPS untuk mencatat gowes.
/// - **GPX** = bagikan rute rencana (bisa diimpor ke Strava/Garmin).
///
/// Semua network call aman-offline: gagal → snackbar/pesan, peta tetap
/// tampil + tidak pernah blank tanpa penjelasan.
class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});
  @override
  ConsumerState<ExploreScreen> createState() => _ExploreState();
}

class _ExploreState extends ConsumerState<ExploreScreen> {
  final _map = MapController();
  final _fromSearch = TextEditingController();
  final _toSearch = TextEditingController();
  Timer? _debounceFrom;
  Timer? _debounceTo;

  LatLng _center = const LatLng(-6.2, 106.8); // Jakarta awal
  LatLng? _myLoc;
  bool _locating = false;

  LatLng? _from;
  String _fromLabel = '';
  LatLng? _to;
  String _toLabel = '';

  List<PlaceResult> _fromResults = [];
  List<PlaceResult> _toResults = [];
  bool _searchingFrom = false;
  bool _searchingTo = false;

  /// Tap peta mengisi kolom mana? false = Tujuan (default), true = Dari.
  bool _pickFrom = false;

  BikeRoute? _route;
  bool _routing = false;
  String? _routeErr;

  // --- navigasi dalam app ---
  bool _navigating = false;
  StreamSubscription<Position>? _navSub;
  double _remainingM = 0;
  double _navSpeedMs = 0;
  bool _followNav = true;

  bool _dark = false;

  bool get _fromIsMyLoc =>
      _from != null &&
      _myLoc != null &&
      haversineM(_from!.latitude, _from!.longitude, _myLoc!.latitude,
              _myLoc!.longitude) <
          30;

  @override
  void initState() {
    super.initState();
    _goMyLocation(auto: true);
  }

  @override
  void dispose() {
    _navSub?.cancel();
    _map.dispose();
    _fromSearch.dispose();
    _toSearch.dispose();
    _debounceFrom?.cancel();
    _debounceTo?.cancel();
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
        // Dari default = posisi saya (seperti GMaps "Your location").
        if (_from == null) {
          _from = ll;
          _fromLabel = 'Posisi saya';
          _fromSearch.text = _fromLabel;
        }
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

  // ---------- cari tempat (Dari & Ke) ----------

  void _onSearchChanged(String v, bool isFrom) {
    final deb = isFrom ? _debounceFrom : _debounceTo;
    deb?.cancel();
    if (v.trim().isEmpty) {
      setState(() {
        if (isFrom) {
          _fromResults = [];
          _searchingFrom = false;
        } else {
          _toResults = [];
          _searchingTo = false;
        }
      });
      return;
    }
    setState(() {
      if (isFrom) {
        _searchingFrom = true;
      } else {
        _searchingTo = true;
      }
    });
    final timer = Timer(const Duration(milliseconds: 600), () async {
      final out = await searchPlaces(v, near: _myLoc ?? _center);
      if (!mounted) return;
      setState(() {
        if (isFrom) {
          _fromResults = out;
          _searchingFrom = false;
        } else {
          _toResults = out;
          _searchingTo = false;
        }
      });
    });
    if (isFrom) {
      _debounceFrom = timer;
    } else {
      _debounceTo = timer;
    }
  }

  void _pickPlace(PlaceResult p, bool isFrom) {
    setState(() {
      if (isFrom) {
        _from = p.latLng;
        _fromLabel = p.name;
        _fromSearch.text = p.name;
        _fromResults = [];
      } else {
        _to = p.latLng;
        _toLabel = p.name;
        _toSearch.text = p.name;
        _toResults = [];
      }
    });
    try {
      _map.move(p.latLng, 15);
    } catch (_) {}
    FocusScope.of(context).unfocus();
    _updateRoute();
  }

  void _setFromMyLoc() {
    if (_myLoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lokasi belum ketemu — nyalakan GPS dulu.')));
      _goMyLocation();
      return;
    }
    setState(() {
      _from = _myLoc;
      _fromLabel = 'Posisi saya';
      _fromSearch.text = _fromLabel;
      _fromResults = [];
    });
    FocusScope.of(context).unfocus();
    _updateRoute();
  }

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
      final tl = _fromLabel;
      _fromLabel = _toLabel;
      _toLabel = tl;
      _fromSearch.text = _fromLabel;
      _toSearch.text = _toLabel;
      _fromResults = [];
      _toResults = [];
      _route = null;
      _routeErr = null;
    });
    _updateRoute();
  }

  // ---------- tap peta ----------

  Future<void> _onMapTap(LatLng ll) async {
    if (_navigating) return; // kunci endpoint saat navigasi jalan
    final isFrom = _pickFrom;
    final coords =
        '${ll.latitude.toStringAsFixed(5)}, ${ll.longitude.toStringAsFixed(5)}';
    setState(() {
      if (isFrom) {
        _from = ll;
        _fromLabel = coords;
        _fromSearch.text = coords;
        _fromResults = [];
      } else {
        _to = ll;
        _toLabel = coords;
        _toSearch.text = coords;
        _toResults = [];
      }
      _route = null;
      _routeErr = null;
    });
    _updateRoute();
    // Perhalus label jadi nama jalan (best-effort, tak blokir rute).
    final name = await reverseGeocode(ll);
    if (!mounted) return;
    setState(() {
      if (isFrom && _from == ll) {
        _fromLabel = name;
        _fromSearch.text = name;
      } else if (!isFrom && _to == ll) {
        _toLabel = name;
        _toSearch.text = name;
      }
    });
  }

  // ---------- rute ----------

  Future<void> _updateRoute() async {
    if (_navigating) return;
    final o = _from;
    final d = _to;
    if (o == null || d == null) {
      setState(() {
        _route = null;
        _routeErr = null;
        _routing = false;
      });
      return;
    }
    setState(() {
      _routing = true;
      _routeErr = null;
    });
    final r = await fetchBikeRoute(o, d);
    if (!mounted) return;
    setState(() {
      _routing = false;
      if (r == null) {
        _route = null;
        _routeErr =
            'Rute sepeda tak ditemukan (offline / jalan tak tersambung). Coba titik lain.';
      } else {
        _route = r;
        _routeErr = null;
        try {
          final b = boundsOf(r.points);
          if (b != null) {
            _map.fitCamera(CameraFit.bounds(
                bounds: b,
                padding: const EdgeInsets.fromLTRB(48, 140, 48, 240),
                maxZoom: 16));
          }
        } catch (_) {}
      }
    });
  }

  void _clearRoute() {
    _stopNav(silent: true);
    setState(() {
      _to = null;
      _toLabel = '';
      _toSearch.clear();
      _toResults = [];
      _route = null;
      _routeErr = null;
    });
  }

  void _clearAll() {
    _stopNav(silent: true);
    setState(() {
      _from = _myLoc;
      _fromLabel = _myLoc == null ? '' : 'Posisi saya';
      _fromSearch.text = _fromLabel;
      _to = null;
      _toLabel = '';
      _toSearch.clear();
      _fromResults = [];
      _toResults = [];
      _route = null;
      _routeErr = null;
    });
  }

  // ---------- navigasi dalam app ----------

  Future<void> _startNav() async {
    final r = _route;
    if (r == null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('GPS mati — nyalakan Location untuk navigasi.')));
      }
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Izin lokasi ditolak — navigasi butuh GPS.')));
      }
      return;
    }
    await _navSub?.cancel();
    setState(() {
      _navigating = true;
      _followNav = true;
      _remainingM = r.distanceM;
    });
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _navSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onNavFix,
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Stream GPS navigasi putus — cek GPS HP.')));
        }
      },
    );
  }

  void _onNavFix(Position pos) {
    if (!_navigating) return;
    final r = _route;
    if (r == null) return;
    final cur = LatLng(pos.latitude, pos.longitude);
    _myLoc = cur;
    _navSpeedMs = pos.speed < 0 ? 0 : pos.speed;
    // Sisa jarak = dari titik rute terdekat ke finish.
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < r.points.length; i++) {
      final d = haversineM(cur.latitude, cur.longitude,
          r.points[i].latitude, r.points[i].longitude);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    var remain = bestD;
    for (var i = best + 1; i < r.points.length; i++) {
      remain += haversineM(
          r.points[i - 1].latitude,
          r.points[i - 1].longitude,
          r.points[i].latitude,
          r.points[i].longitude);
    }
    if (!mounted) return;
    setState(() => _remainingM = remain);
    if (_followNav) {
      try {
        _map.move(cur, _map.camera.zoom);
      } catch (_) {}
    }
    // Sampai (<40 m dari finish).
    final dest = _to;
    if (dest != null &&
        haversineM(cur.latitude, cur.longitude, dest.latitude,
                dest.longitude) <
            40) {
      _stopNav();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sampai tujuan! Mantap gowesnya.')));
      }
    }
  }

  void _stopNav({bool silent = false}) {
    _navSub?.cancel();
    _navSub = null;
    if (!silent && _navigating && mounted) {
      setState(() => _navigating = false);
    } else {
      _navigating = false;
    }
    if (mounted && !silent) setState(() {});
  }

  String _navEta() {
    // Pakai kecepatan berjalan bila ada, else asumsi santai 15 km/h.
    final kmh = _navSpeedMs * 3.6 >= 5 ? _navSpeedMs * 3.6 : 15.0;
    final sec = _remainingM / (kmh / 3.6);
    final m = (sec / 60).round();
    if (m < 60) return '$m mnt';
    return '${m ~/ 60}j ${m % 60}m';
  }

  Future<void> _openGmaps() async {
    final o = _from;
    final d = _to;
    if (d == null) return;
    final uri = o == null
        ? googleMapsSearchUri(d, _toLabel.isEmpty ? 'Tujuan' : _toLabel)
        : googleMapsDirUri(o, d);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tak bisa membuka Google Maps.')));
      }
    }
  }

  /// Bagikan rute RENCANA sebagai GPX (pakai helper DetailScreen).
  Future<void> _sharePlannedGpx() async {
    final r = _route;
    if (r == null || r.points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada rute untuk dibagikan.')));
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final totalMs = (r.durationSec * 1000).round().clamp(1000, 1 << 31);
    final pts = [
      for (var i = 0; i < r.points.length; i++)
        GpsPoint(
          lat: r.points[i].latitude,
          lng: r.points[i].longitude,
          t: nowMs + (totalMs * i ~/ r.points.length),
        ),
    ];
    final name = _toLabel.isEmpty ? 'Rute Sepeda' : 'Rute ${_toLabel.split(',').first}';
    await shareGpx(
        context, name, encodeRoute(pts), DateTime.now().toIso8601String());
  }

  void _recordRoute() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const TrackScreen()));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final markers = <Marker>[
      if (_myLoc != null && !_fromIsMyLoc)
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
      if (_from != null)
        Marker(
          point: _from!,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 22),
          ),
        ),
      if (_to != null)
        Marker(
          point: _to!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin,
              color: Colors.red, size: 40),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jelajah'),
        actions: [
          IconButton(
            icon: Icon(
                _dark ? Icons.dark_mode : Icons.light_mode_outlined),
            tooltip: 'Gaya peta (Gelap = PRO)',
            onPressed: () {
              if (!_dark && !ref.read(premiumProvider).isPro) {
                showProPaywall(context, ref);
                return;
              }
              setState(() => _dark = !_dark);
            },
          ),
        ],
      ),
      body: Column(children: [
        // --- Panel Dari–Ke ala GMaps ---
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Column(children: [
                      Icon(Icons.circle,
                          size: 14, color: Colors.green),
                      SizedBox(height: 2),
                      Icon(Icons.more_vert, size: 14),
                      SizedBox(height: 2),
                      Icon(Icons.location_pin,
                          size: 16, color: Colors.red),
                    ]),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(children: [
                      _FromToField(
                        controller: _fromSearch,
                        hint: 'Dari — posisi saya / ketik tempat…',
                        searching: _searchingFrom,
                        armed: _pickFrom,
                        onChanged: (v) => _onSearchChanged(v, true),
                        onSubmitted: (v) async {
                          final out = await searchPlaces(v,
                              near: _myLoc ?? _center);
                          if (!context.mounted) return;
                          if (out.isNotEmpty) {
                            _pickPlace(out.first, true);
                          }
                        },
                        onClear: () => setState(() {
                          _fromSearch.clear();
                          _fromResults = [];
                        }),
                        onArm: () =>
                            setState(() => _pickFrom = true),
                        onMyLoc: _setFromMyLoc,
                        isFrom: true,
                      ),
                      const Divider(height: 8),
                      _FromToField(
                        controller: _toSearch,
                        hint: 'Ke — ketik tujuan / tap peta…',
                        searching: _searchingTo,
                        armed: !_pickFrom,
                        onChanged: (v) => _onSearchChanged(v, false),
                        onSubmitted: (v) async {
                          final out = await searchPlaces(v,
                              near: _myLoc ?? _center);
                          if (!context.mounted) return;
                          if (out.isNotEmpty) {
                            _pickPlace(out.first, false);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Tempat tak ditemukan — cek ejaan / internet.')));
                          }
                        },
                        onClear: () => setState(() {
                          _toSearch.clear();
                          _toResults = [];
                        }),
                        onArm: () =>
                            setState(() => _pickFrom = false),
                        onMyLoc: null,
                        isFrom: false,
                      ),
                    ]),
                  ),
                  Column(children: [
                    IconButton(
                      icon: const Icon(Icons.swap_vert_rounded),
                      tooltip: 'Tukar Dari–Tujuan',
                      onPressed:
                          (_from == null && _to == null) ? null : _swap,
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all_rounded),
                      tooltip: 'Bersihkan',
                      onPressed: _clearAll,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
        if (_fromResults.isNotEmpty || _toResults.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              margin: EdgeInsets.zero,
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: (_pickFrom || _toResults.isEmpty)
                    ? _fromResults.length.clamp(0, 4)
                    : _toResults.length.clamp(0, 4),
                separatorBuilder: (a, b) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final isFrom =
                      (_pickFrom || _toResults.isEmpty) &&
                          _fromResults.isNotEmpty;
                  final list = isFrom ? _fromResults : _toResults;
                  final p = list[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(p.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    onTap: () => _pickPlace(p, isFrom),
                  );
                },
              ),
            ),
          ),
        // --- Peta (tile OSM murni, tanpa API key) ---
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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
                    // Tap = isi kolom aktif (Dari/Tujuan).
                    onTap: (_, ll) => _onMapTap(ll),
                  ),
                  children: [
                    osmTiles(dark: _dark),
                    if (_route != null)
                      PolylineLayer(polylines: [
                        Polyline(
                            points: _route!.points,
                            strokeWidth: 5,
                            color: scheme.primary),
                      ]),
                    MarkerLayer(markers: markers),
                    const RichAttributionWidget(attributions: [
                      TextSourceAttribution(
                          '© OpenStreetMap contributors')
                    ]),
                  ],
                ),
                // Chip mode tap.
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: scheme.outlineVariant),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          _pickFrom
                              ? Icons.circle
                              : Icons.location_pin,
                          size: 14,
                          color: _pickFrom
                              ? Colors.green
                              : Colors.red),
                      const SizedBox(width: 6),
                      Text(
                        _pickFrom
                            ? 'Tap peta → Dari'
                            : 'Tap peta → Tujuan',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
                if (_routing)
                  Positioned(
                    top: 52,
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
                // Banner navigasi live.
                if (_navigating)
                  Positioned(
                    top: 52,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(Icons.navigation_rounded,
                            color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sisa ${_remainingM >= 1000 ? '${(_remainingM / 1000).toStringAsFixed(1)} km' : '${_remainingM.toStringAsFixed(0)} m'} • ~${_navEta()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                ),
                                Text(
                                  _toLabel.isEmpty
                                      ? 'Menuju tujuan'
                                      : 'ke ${_toLabel.split(',').first}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                              ]),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Berhenti navigasi',
                          onPressed: () => _stopNav(),
                        ),
                      ]),
                    ),
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
              ]),
            ),
          ),
        ),
        // Panel rute bawah: Mulai (in-app) + Rekam + GPX + GMaps.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _bottomPanel(context),
        ),
      ]),
    );
  }

  Widget _bottomPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_navigating) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: const Text('Berhenti'),
                onPressed: () => _stopNav(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.fiber_manual_record, size: 18),
                label: const Text('Rekam'),
                onPressed: _recordRoute,
              ),
            ),
          ]),
        ),
      );
    }
    if (_from == null || _to == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'Isi Dari & Tujuan di atas, atau tap peta — rute sepeda ramah gowes otomatis dibuat (tanpa API key).',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    final startGapM = (_myLoc != null && !_fromIsMyLoc)
        ? haversineM(_myLoc!.latitude, _myLoc!.longitude,
            _from!.latitude, _from!.longitude)
        : 0.0;
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
                      '${_fromLabel.isEmpty ? 'Awal' : _fromLabel.split(',').first} → ${_toLabel.isEmpty ? 'Tujuan' : _toLabel.split(',').first}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      _route != null
                          ? '${_route!.distanceKm.toStringAsFixed(1)} km • ~${_route!.etaLabel} gowes • ramah sepeda'
                          : (_routeErr ?? 'Menghitung…'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (startGapM > 200)
                      Text(
                        'Titik awal ${(startGapM / 1000).toStringAsFixed(1)} km darimu — navigasi mulai dari posisimu.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                                color:
                                    scheme.onSurfaceVariant),
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
              child: FilledButton.icon(
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Mulai'),
                onPressed:
                    _route == null ? null : () => _startNav(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.fiber_manual_record, size: 18),
                label: const Text('Rekam'),
                onPressed: _recordRoute,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('GPX'),
                onPressed:
                    _route == null ? null : () => _sharePlannedGpx(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('GMaps'),
                onPressed: _openGmaps,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.route_outlined, size: 18),
                label: const Text('Ulangi'),
                onPressed: () {
                  if (_from != null && _to != null) {
                    _updateRoute();
                  }
                },
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Satu baris input Dari/Tujuan: ikon pin-arm (tap-peta target) +
/// tombol posisi-saya (khusus Dari) + clear.
class _FromToField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool searching;
  final bool armed;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onArm;
  final VoidCallback? onMyLoc;
  final bool isFrom;
  const _FromToField({
    required this.controller,
    required this.hint,
    required this.searching,
    required this.armed,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onArm,
    required this.onMyLoc,
    required this.isFrom,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      maxLines: 1,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: armed
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        prefixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                icon: Icon(
                    isFrom ? Icons.circle : Icons.location_pin,
                    size: 16,
                    color: armed
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
                tooltip: isFrom
                    ? 'Tap peta mengisi Dari'
                    : 'Tap peta mengisi Tujuan',
                onPressed: onArm,
              ),
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isFrom && onMyLoc != null)
            IconButton(
              icon: const Icon(Icons.my_location, size: 18),
              tooltip: 'Gunakan posisi saya',
              onPressed: onMyLoc,
            ),
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Hapus',
              onPressed: onClear,
            ),
        ]),
      ),
    );
  }
}
