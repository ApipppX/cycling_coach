import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/geo_utils.dart';
import '../../core/gpx.dart';
import '../../core/places_api.dart';
import '../../core/premium.dart';
import '../../models/models.dart';
import '../../models/planned_route.dart';
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
/// - **GPX** = impor file `.gpx`, atau bagikan rute rencana. Rute hasil
///   impor langsung bisa dinavigasi dengan "Mulai".
///
/// Semua network call aman-offline: gagal → snackbar/pesan, peta tetap
/// tampil + tidak pernah blank tanpa penjelasan.
class ExploreScreen extends ConsumerStatefulWidget {
  /// Rute GPX yang sudah tersimpan di event (dibuka dari layar Event).
  final String initialRouteJson;
  final String initialRouteName;

  const ExploreScreen({
    super.key,
    this.initialRouteJson = '',
    this.initialRouteName = '',
  });

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

  /// Nomor request rute: hasil OSRM lama tidak boleh menimpa GPX impor.
  int _routeReq = 0;

  // --- rute GPX impor ---
  bool _gpxImported = false;
  String _gpxName = '';
  double _gpxElevationGainM = 0;
  int _gpxPointCount = 0;

  /// Padding kamera rute yang aman untuk layar pendek.
  ///
  /// Padding atas+bawah tidak boleh melebihi tinggi peta: nilai lama
  /// (140 + 240 px) membuat ruang efektif negatif sehingga CameraFit jatuh
  /// ke zoom minimum dan rute hanya terlihat sebagai titik.
  static const _routeFitPadding = EdgeInsets.fromLTRB(28, 32, 28, 32);

  // --- navigasi dalam app ---
  bool _navigating = false;
  StreamSubscription<Position>? _navSub;
  double _remainingM = 0;
  double _navSpeedMs = 0;
  bool _followNav = true;

  /// Progres terakhir di daftar titik rute. Dipakai agar rute loop
  /// (start = finish) tidak dianggap "sampai" saat baru mulai.
  int _navRouteIdx = 0;

  bool _dark = false;

  bool get _fromIsMyLoc =>
      _from != null &&
      _myLoc != null &&
      haversineM(
            _from!.latitude,
            _from!.longitude,
            _myLoc!.latitude,
            _myLoc!.longitude,
          ) <
          30;

  @override
  void initState() {
    super.initState();
    _goMyLocation(auto: true);
    if (widget.initialRouteJson.isNotEmpty) {
      // Tunggu FlutterMap terpasang dulu agar fitCamera tidak error.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final pts = decodeRoute(widget.initialRouteJson);
        if (pts.length >= 2) {
          _applyGpxRoute(
            pts,
            name: widget.initialRouteName,
            showSnackBar: false,
          );
        }
      });
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS mati — nyalakan Location di pengaturan HP.'),
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin lokasi ditolak — peta tetap bisa dijelajah manual.',
              ),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 15));
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
      // Saat auto-lokasi pertama, jangan geser peta bila sudah ada rute
      // (mis. dibuka dari event dengan GPX impor) — nanti rute tak terlihat.
      if (!(auto && (_gpxImported || _route != null))) {
        try {
          _map.move(ll, 15);
        } catch (_) {}
      }
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
      _detachGpx();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi belum ketemu — nyalakan GPS dulu.'),
        ),
      );
      _goMyLocation();
      return;
    }
    setState(() {
      _detachGpx();
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
      _detachGpx();
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
      _detachGpx();
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
    if (_navigating || _gpxImported) return;
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
    final req = ++_routeReq;
    setState(() {
      _routing = true;
      _routeErr = null;
    });
    final r = await fetchBikeRoute(o, d);
    if (!mounted || req != _routeReq) return;
    setState(() {
      _routing = false;
      if (r == null) {
        _route = null;
        _routeErr = 'Rute sepeda tak ditemukan (offline / jalan tak tersambung). Coba titik lain.';
      } else {
        _route = r;
        _routeErr = null;
        try {
          final b = boundsOf(r.points);
          if (b != null) {
            _map.fitCamera(
              CameraFit.bounds(
                bounds: b,
                padding: _routeFitPadding,
                maxZoom: 16,
              ),
            );
          }
        } catch (_) {}
      }
    });
  }

  void _clearRoute() {
    _stopNav(silent: true);
    setState(() {
      _routeReq++;
      _detachGpx();
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
      _routeReq++;
      _detachGpx();
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

  // ---------- impor GPX ----------

  /// Lepas status "rute GPX" saat user mengubah Dari/Tujuan manual.
  void _detachGpx() {
    _gpxImported = false;
    _gpxName = '';
    _gpxElevationGainM = 0;
    _gpxPointCount = 0;
  }

  /// Pasang rute GPX ke peta + endpoint Dari/Tujuan agar bisa dinavigasi.
  void _applyGpxRoute(
    List<GpsPoint> raw, {
    required String name,
    bool showSnackBar = true,
  }) {
    if (raw.length < 2) {
      if (showSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPX harus berisi minimal 2 titik rute.'),
          ),
        );
      }
      return;
    }
    _stopNav(silent: true);
    _routeReq++;
    // Satu sumber kebenaran untuk metadata GPX: jarak/elevasi dihitung dari
    // titik asli, sedangkan titik peta disederhanakan agar tetap mulus.
    final planned = PlannedRoute.fromGpsPoints(raw, name: name);
    final latLngs = planned.points;
    final startLabel = 'Start • ${planned.name}';
    final finishLabel = 'Finish • ${planned.name}';

    setState(() {
      _gpxImported = true;
      _gpxName = planned.name;
      _gpxElevationGainM = planned.elevationGainM;
      _gpxPointCount = planned.sourcePointCount;
      _routing = false;
      _routeErr = null;
      _route = BikeRoute(
        points: latLngs,
        distanceM: planned.distanceM,
        durationSec: planned.durationSec,
      );
      _from = latLngs.first;
      _fromLabel = startLabel;
      _fromSearch.text = startLabel;
      _to = latLngs.last;
      _toLabel = finishLabel;
      _toSearch.text = finishLabel;
      _fromResults = [];
      _toResults = [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitRoute();
    });
    if (showSnackBar && mounted) {
      final elev = planned.elevationGainM >= 5
          ? ' • ↑ ${planned.elevationGainM.round()} m'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'GPX "${planned.name}" dimuat • '
            '${planned.distanceKm.toStringAsFixed(1)} km$elev • '
            '${raw.length} titik. Tekan Mulai untuk navigasi.',
          ),
        ),
      );
    }
  }

  void _fitRoute() {
    final r = _route;
    if (r == null || r.points.isEmpty) return;
    final b = boundsOf(r.points);
    if (b == null) return;
    try {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: b,
          padding: _routeFitPadding,
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  Future<void> _importGpx() async {
    try {
      final track = await pickGpxFile();
      if (!mounted || track == null) return;
      _applyGpxRoute(track.points, name: track.name);
    } on GpxException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal impor GPX: ${e.message}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal membaca file GPX: $e')));
    }
  }

  /// Tombol GPX: belum ada rute → langsung impor. Sudah ada rute → pilih
  /// impor (ganti rute) atau bagikan rute yang sedang tampil.
  Future<void> _onGpxPressed() async {
    if (_route == null) {
      await _importGpx();
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: const Text('Import GPX'),
              subtitle: const Text(
                'Muat rute dari file GPX dan mulai navigasi',
              ),
              onTap: () => Navigator.pop(ctx, 'import'),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Bagikan GPX rute ini'),
              subtitle: const Text('Kirim ke Strava/Garmin atau teman gowes'),
              onTap: () => Navigator.pop(ctx, 'share'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'import') await _importGpx();
    if (action == 'share') await _sharePlannedGpx();
  }

  // ---------- navigasi dalam app ----------

  Future<void> _startNav() async {
    final r = _route;
    if (r == null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS mati — nyalakan Location untuk navigasi.'),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi ditolak — navigasi butuh GPS.'),
          ),
        );
      }
      return;
    }
    await _navSub?.cancel();
    setState(() {
      _navigating = true;
      _followNav = true;
      _remainingM = r.distanceM;
      _navRouteIdx = 0;
    });
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _navSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onNavFix,
      onError: (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Stream GPS navigasi putus — cek GPS HP.'),
            ),
          );
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
    // Mulai pencarian dari progres terakhir (boleh mundur sedikit untuk
    // toleransi GPS) agar rute loop tidak "melompat" balik ke titik start.
    var best = _navRouteIdx.clamp(0, r.points.length - 1);
    var bestD = double.infinity;
    final searchFrom = (best - 10).clamp(0, best);
    for (var i = searchFrom; i < r.points.length; i++) {
      final d = haversineM(
        cur.latitude,
        cur.longitude,
        r.points[i].latitude,
        r.points[i].longitude,
      );
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    _navRouteIdx = best;
    var remain = bestD;
    for (var i = best + 1; i < r.points.length; i++) {
      remain += haversineM(
        r.points[i - 1].latitude,
        r.points[i - 1].longitude,
        r.points[i].latitude,
        r.points[i].longitude,
      );
    }
    if (!mounted) return;
    setState(() => _remainingM = remain);
    if (_followNav) {
      try {
        _map.move(cur, _map.camera.zoom);
      } catch (_) {}
    }
    // Sampai: harus sudah berada di 15% terakhir rute + dekat finish.
    // Cek indeks ini penting untuk rute event yang start/finish-nya sama
    // (loop) — tanpa itu navigasi langsung berhenti di garis start.
    final nearEnd = best >= (r.points.length * 0.85).floor();
    if (nearEnd && remain < 50) {
      _stopNav();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sampai tujuan! Mantap gowesnya.')),
        );
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
          const SnackBar(content: Text('Tak bisa membuka Google Maps.')),
        );
      }
    }
  }

  /// Bagikan rute RENCANA sebagai GPX (pakai helper DetailScreen).
  Future<void> _sharePlannedGpx() async {
    final r = _route;
    if (r == null || r.points.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada rute untuk dibagikan.')),
      );
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
    final name = _toLabel.isEmpty
        ? 'Rute Sepeda'
        : 'Rute ${_toLabel.split(',').first}';
    await shareGpx(
      context,
      name,
      encodeRoute(pts),
      DateTime.now().toIso8601String(),
    );
  }

  /// Rute yang sedang tampil, siap dibawa ke layar Rekam.
  ///
  /// Metadata (nama, jarak, durasi, elevasi, sumber) dibungkus satu objek
  /// agar layar Rekam tidak perlu mengetahui asal rute secara terpisah.
  PlannedRoute? get _plannedRoute {
    final r = _route;
    if (r == null || r.points.length < 2) return null;
    final name = _gpxImported
        ? _gpxName
        : (_toLabel.trim().isEmpty
            ? 'Rute Jelajah'
            : _toLabel.split(',').first);
    return PlannedRoute.fromLatLngs(
      r.points,
      name: name,
      distanceM: r.distanceM,
      durationSec: r.durationSec,
      elevationGainM: _gpxImported ? _gpxElevationGainM : 0,
      sourcePointCount: _gpxImported ? _gpxPointCount : r.points.length,
      source:
          _gpxImported ? PlannedRouteSource.gpx : PlannedRouteSource.osrm,
    );
  }

  void _recordRoute() {
    // Bawa rute yang sedang tampil (GPX / OSRM) ke layar Rekam. Tanpa ini
    // TrackScreen membuka rekaman kosong dan jalur yang dipilih user hilang.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrackScreen(plannedRoute: _plannedRoute),
      ),
    );
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
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      if (_to != null)
        Marker(
          point: _to!,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jelajah'),
        actions: [
          IconButton(
            icon: Icon(_dark ? Icons.dark_mode : Icons.light_mode_outlined),
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
      body: Column(
        children: [
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
                      child: Column(
                        children: [
                          Icon(Icons.circle, size: 14, color: Colors.green),
                          SizedBox(height: 2),
                          Icon(Icons.more_vert, size: 14),
                          SizedBox(height: 2),
                          Icon(Icons.location_pin, size: 16, color: Colors.red),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        children: [
                          _FromToField(
                            controller: _fromSearch,
                            hint: 'Dari — posisi saya / ketik tempat…',
                            searching: _searchingFrom,
                            armed: _pickFrom,
                            onChanged: (v) => _onSearchChanged(v, true),
                            onSubmitted: (v) async {
                              final out = await searchPlaces(
                                v,
                                near: _myLoc ?? _center,
                              );
                              if (!context.mounted) return;
                              if (out.isNotEmpty) {
                                _pickPlace(out.first, true);
                              }
                            },
                            onClear: () => setState(() {
                              _fromSearch.clear();
                              _fromResults = [];
                            }),
                            onArm: () => setState(() => _pickFrom = true),
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
                              final out = await searchPlaces(
                                v,
                                near: _myLoc ?? _center,
                              );
                              if (!context.mounted) return;
                              if (out.isNotEmpty) {
                                _pickPlace(out.first, false);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Tempat tak ditemukan — cek ejaan / internet.',
                                    ),
                                  ),
                                );
                              }
                            },
                            onClear: () => setState(() {
                              _toSearch.clear();
                              _toResults = [];
                            }),
                            onArm: () => setState(() => _pickFrom = false),
                            onMyLoc: null,
                            isFrom: false,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.swap_vert_rounded),
                          tooltip: 'Tukar Dari–Tujuan',
                          onPressed: (_from == null && _to == null)
                              ? null
                              : _swap,
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_all_rounded),
                          tooltip: 'Bersihkan',
                          onPressed: _clearAll,
                        ),
                      ],
                    ),
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
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                child: Stack(
                  children: [
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
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _route!.points,
                                strokeWidth: 5,
                                color: scheme.primary,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: markers),
                        const RichAttributionWidget(
                          attributions: [
                            TextSourceAttribution(
                              '© OpenStreetMap contributors · Powered by Esri',
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Chip mode tap.
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _pickFrom ? Icons.circle : Icons.location_pin,
                              size: 14,
                              color: _pickFrom ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _pickFrom
                                  ? 'Tap peta → Dari'
                                  : 'Tap peta → Tujuan',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_routing)
                      Positioned(
                        top: 52,
                        left: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 10),
                              Text('Mencari rute sepeda…'),
                            ],
                          ),
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
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.navigation_rounded,
                                color: scheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Sisa ${_remainingM >= 1000 ? '${(_remainingM / 1000).toStringAsFixed(1)} km' : '${_remainingM.toStringAsFixed(0)} m'} • ~${_navEta()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
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
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Berhenti navigasi',
                                onPressed: () => _stopNav(),
                              ),
                            ],
                          ),
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
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.my_location),
                          ),
                          const SizedBox(height: 8),
                          MapZoomButtons(controller: _map),
                        ],
                      ),
                    ),
                    const Positioned(
                      left: 10,
                      bottom: 10,
                      child: MapOfflineHint(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Panel rute bawah: Mulai (in-app) + Rekam + GPX + GMaps.
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: _bottomPanel(context),
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (_navigating) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
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
            ],
          ),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Isi Dari & Tujuan di atas, tap peta, atau import file GPX.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Import GPX'),
                onPressed: _importGpx,
              ),
            ),
          ],
        ),
      );
    }
    final startGapM = (_myLoc != null && !_fromIsMyLoc)
        ? haversineM(
            _myLoc!.latitude,
            _myLoc!.longitude,
            _from!.latitude,
            _from!.longitude,
          )
        : 0.0;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bike, color: scheme.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _gpxImported
                            ? _gpxName
                            : '${_fromLabel.isEmpty ? 'Awal' : _fromLabel.split(',').first} → ${_toLabel.isEmpty ? 'Tujuan' : _toLabel.split(',').first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _route != null
                            ? '${_route!.distanceKm.toStringAsFixed(1)} km'
                                '${_gpxImported && _gpxElevationGainM >= 5 ? ' • ↑ ${_gpxElevationGainM.round()} m' : ''}'
                                ' • ~${_route!.etaLabel} gowes • ${_gpxImported ? 'rute GPX' : 'ramah sepeda'}'
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
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Hapus rute',
                  onPressed: _clearRoute,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Mulai'),
                    onPressed: _route == null ? null : () => _startNav(),
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
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: _onGpxPressed,
                    child: const Text(
                      'Import GPX',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
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
                    label: Text(_gpxImported ? 'Lihat' : 'Ulangi'),
                    onPressed: _route == null
                        ? null
                        : () {
                            if (_gpxImported) {
                              _fitRoute();
                            } else if (_from != null && _to != null) {
                              _updateRoute();
                            }
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        filled: true,
        fillColor: armed
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        prefixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                icon: Icon(
                  isFrom ? Icons.circle : Icons.location_pin,
                  size: 16,
                  color: armed ? scheme.primary : scheme.onSurfaceVariant,
                ),
                tooltip: isFrom
                    ? 'Tap peta mengisi Dari'
                    : 'Tap peta mengisi Tujuan',
                onPressed: onArm,
              ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
  }
}
