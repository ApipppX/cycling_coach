import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/models.dart';
import 'geo_utils.dart';

/// Status perekaman GPS (mesin state sederhana ala Strava).
enum TrackStatus { idle, locating, recording, paused, finished, error }

/// Snapshot sekali baca untuk UI (immutable, Riverpod-friendly).
class TrackState {
  final TrackStatus status;
  final String message;
  final List<GpsPoint> points;
  final double distanceM;
  final int elapsedSec; // termasuk jeda pause? tidak — hanya waktu bergerak+jalan
  final int movingSec;
  final double currentSpeedMs;
  final double avgSpeedMs;
  final double elevationGainM;
  final double? currentLat;
  final double? currentLng;
  final double accuracyM;
  final bool autoPause;
  final DateTime? startedAt;
  /// Epoch-ms event GPS terakhir (service latar ATAU stream lama).
  /// UI memakainya untuk banner "sinyal terputus" bila macet >30 dtk.
  final int lastEventMs;

  const TrackState({
    this.status = TrackStatus.idle,
    this.message = '',
    this.points = const [],
    this.distanceM = 0,
    this.elapsedSec = 0,
    this.movingSec = 0,
    this.currentSpeedMs = 0,
    this.avgSpeedMs = 0,
    this.elevationGainM = 0,
    this.currentLat,
    this.currentLng,
    this.accuracyM = 0,
    this.autoPause = true,
    this.startedAt,
    this.lastEventMs = 0,
  });

  double get distanceKm => distanceM / 1000.0;
  double get speedKmh => avgSpeedMs * 3.6;
  double get currentKmh => currentSpeedMs * 3.6;
  bool get hasFix => currentLat != null && currentLng != null;

  TrackState copyWith({
    TrackStatus? status,
    String? message,
    List<GpsPoint>? points,
    double? distanceM,
    int? elapsedSec,
    int? movingSec,
    double? currentSpeedMs,
    double? avgSpeedMs,
    double? elevationGainM,
    double? currentLat,
    double? currentLng,
    double? accuracyM,
    bool? autoPause,
    DateTime? startedAt,
    int? lastEventMs,
  }) =>
      TrackState(
        status: status ?? this.status,
        message: message ?? this.message,
        points: points ?? this.points,
        distanceM: distanceM ?? this.distanceM,
        elapsedSec: elapsedSec ?? this.elapsedSec,
        movingSec: movingSec ?? this.movingSec,
        currentSpeedMs: currentSpeedMs ?? this.currentSpeedMs,
        avgSpeedMs: avgSpeedMs ?? this.avgSpeedMs,
        elevationGainM: elevationGainM ?? this.elevationGainM,
        currentLat: currentLat ?? this.currentLat,
        currentLng: currentLng ?? this.currentLng,
        accuracyM: accuracyM ?? this.accuracyM,
        autoPause: autoPause ?? this.autoPause,
        startedAt: startedAt ?? this.startedAt,
        lastEventMs: lastEventMs ?? this.lastEventMs,
      );
}

/// Perekam GPS: di Android/iOS rekaman jalan di FOREGROUND SERVICE
/// ([track_service.dart]) sehingga tetap hidup saat layar mati; di
/// web/desktop (service tak tersedia) pakai stream lama di isolate UI.
///
/// API publik (start/pause/resume/finish/discard/toActivity) TIDAK berubah —
/// layar Rekam tidak perlu diubah.
class TrackRecorder extends Notifier<TrackState> {
  // --- Jalur lama (web/desktop, atau fallback bila service gagal) ---
  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  DateTime? _startWall;
  int _pausedTotalSec = 0;
  DateTime? _pauseBegan;
  int _lastAutoMovingSec = 0;
  bool _autoPausedNow = false;

  // --- Jalur service latar (Android/iOS) ---
  final FlutterBackgroundService _svc = FlutterBackgroundService();
  StreamSubscription? _bgPosSub;
  StreamSubscription? _bgFullSub;
  StreamSubscription? _bgPongSub;
  bool _useBg = false;
  int _uiSeq = 0;
  bool _syncPending = false;

  /// Service latar hanya ada di Android/iOS native.
  bool get _supportsBg =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  TrackState build() {
    if (_supportsBg) {
      _bgPosSub = _svc.on('pos').listen(_onBgPos);
      _bgFullSub = _svc.on('full').listen(_onBgFull);
      _bgPongSub = _svc.on('pong').listen(_onBgPong);
      // Service mungkin masih merekam dari sebelum UI mati (user swipe
      // app saat layar mati). Tempel ulang bila begitu.
      try {
        _svc.invoke('ping');
      } catch (_) {}
    }
    ref.onDispose(() {
      _bgPosSub?.cancel();
      _bgFullSub?.cancel();
      _bgPongSub?.cancel();
      _sub?.cancel();
      _ticker?.cancel();
    });
    return const TrackState();
  }

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = state.copyWith(
          status: TrackStatus.error,
          message: 'GPS mati. Nyalakan Location di pengaturan HP.');
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      state = state.copyWith(
          status: TrackStatus.error,
          message:
              'Izin lokasi ditolak. Buka Settings → Apps → CyclingCoach → Location → Allow.');
      return false;
    }
    return true;
  }

  /// Izin khusus latar (best-effort, tak fatal bila ditolak — HP tetap
  /// merekam saat app di depan; sebagian HP membatasi saat layar mati).
  Future<void> _ensureBgPermissions() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await Permission.locationAlways.request();
        await Permission.notification.request();
        await Permission.ignoreBatteryOptimizations.request();
      } else {
        await Permission.locationAlways.request();
      }
    } catch (_) {}
  }

  Future<void> start() async {
    state = state.copyWith(status: TrackStatus.locating, message: 'Mencari GPS…');
    if (!await ensurePermission()) return;
    if (_supportsBg) {
      await _ensureBgPermissions();
      try {
        if (await _svc.startService()) {
          _useBg = true;
          _uiSeq = 0;
          _syncPending = false;
          final now = DateTime.now();
          state = TrackState(
            status: TrackStatus.recording,
            autoPause: state.autoPause,
            startedAt: now,
            lastEventMs: now.millisecondsSinceEpoch,
          );
          _svc.invoke('start', {'autoPause': state.autoPause});
          _svc.invoke('sync');
          _ticker?.cancel();
          _ticker =
              Timer.periodic(const Duration(seconds: 1), (_) => _tickBg());
          return;
        }
      } catch (_) {}
    }
    _useBg = false;
    await _startLegacy();
  }

  /// Jam dinding tampilan dihitung service; ticker ini hanya menghaluskan
  /// (tambah 1 dtk) agar angka tak diam di antara event (~5 dtk).
  void _tickBg() {
    if (state.status != TrackStatus.recording) return;
    state = state.copyWith(elapsedSec: state.elapsedSec + 1);
  }

  void _onBgPos(dynamic e) {
    if (!_useBg || e is! Map) return;
    final m = Map<String, dynamic>.from(e);
    if (state.status == TrackStatus.idle ||
        state.status == TrackStatus.finished ||
        state.status == TrackStatus.error) {
      return;
    }
    // Service mati tak terduga (dibunuh OS) saat sesi lokal masih jalan.
    if (m['recording'] != true) {
      state = state.copyWith(
        status: TrackStatus.error,
        message:
            'Pelacakan latar berhenti (HP mematikan app). Ketuk "Rekam Lagi" untuk sesi baru.',
      );
      _useBg = false;
      _ticker?.cancel();
      return;
    }
    if (state.status != TrackStatus.recording &&
        state.status != TrackStatus.paused &&
        state.status != TrackStatus.locating) {
      return;
    }
    _applyBgSnapshot(m, append: true);
  }

  void _onBgFull(dynamic e) {
    if (!_useBg || e is! Map) return;
    if (state.status == TrackStatus.idle ||
        state.status == TrackStatus.finished) {
      return;
    }
    _syncPending = false;
    final m = Map<String, dynamic>.from(e);
    final raw = m['points'] as List? ?? const [];
    final pts = <GpsPoint>[];
    for (final n in raw) {
      final p = _decodePt(n);
      if (p != null) pts.add(p);
      if (pts.length >= 20000) break;
    }
    _uiSeq = (m['seq'] as int?) ?? _uiSeq;
    state = state.copyWith(points: pts);
    _applyBgSnapshot(m, append: false);
  }

  /// UI dibuka ulang saat service merekam → tempel ke sesi berjalan.
  void _onBgPong(dynamic e) {
    if (e is! Map) return;
    final m = Map<String, dynamic>.from(e);
    if (m['recording'] != true) return;
    if (state.status != TrackStatus.idle) return;
    _useBg = true;
    _uiSeq = 0;
    _syncPending = false;
    final startedMs = (m['startedAtMs'] as int?) ?? 0;
    final now = DateTime.now();
    state = TrackState(
      status: m['paused'] == true
          ? TrackStatus.paused
          : TrackStatus.recording,
      autoPause: state.autoPause,
      startedAt: startedMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(startedMs)
          : now,
      lastEventMs: now.millisecondsSinceEpoch,
    );
    _applyBgSnapshot(m, append: false);
    try {
      _svc.invoke('sync');
    } catch (_) {}
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tickBg());
  }

  void _applyBgSnapshot(Map<String, dynamic> m, {required bool append}) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var pts = state.points;
    if (append) {
      final seq = (m['seq'] as int?) ?? _uiSeq;
      final rawNew = m['newPts'] as List? ?? const [];
      if (seq > _uiSeq && rawNew.isNotEmpty) {
        final got = <GpsPoint>[];
        for (final n in rawNew) {
          final p = _decodePt(n);
          if (p != null) got.add(p);
        }
        if (got.isNotEmpty) pts = [...pts, ...got];
        _uiSeq = seq;
        // nPts tak cocok = event terlewat saat UI dibekukan → minta full.
        final nPts = m['nPts'] as int?;
        if (nPts != null && nPts != pts.length && !_syncPending) {
          _syncPending = true;
          try {
            _svc.invoke('sync');
          } catch (_) {}
        }
      }
    }
    final distM =
        (m['distM'] as num?)?.toDouble() ?? state.distanceM;
    final elapsed = (m['elapsed'] as int?) ?? state.elapsedSec;
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    final streamError = m['streamError'] == true;
    state = state.copyWith(
      status: m['paused'] == true
          ? TrackStatus.paused
          : (state.status == TrackStatus.locating
              ? TrackStatus.recording
              : state.status),
      points: pts,
      distanceM: distM,
      elevationGainM:
          (m['gainM'] as num?)?.toDouble() ?? state.elevationGainM,
      elapsedSec: elapsed,
      movingSec: (m['moving'] as int?) ?? state.movingSec,
      currentSpeedMs:
          (m['spd'] as num?)?.toDouble() ?? state.currentSpeedMs,
      avgSpeedMs: elapsed > 0 ? distM / elapsed : 0.0,
      accuracyM: (m['acc'] as num?)?.toDouble() ?? state.accuracyM,
      lastEventMs: nowMs,
      message: streamError
          ? 'Sinyal GPS hilang — pastikan GPS HP menyala.'
          : (state.status == TrackStatus.paused ? state.message : ''),
    );
    if (lat != null && lng != null) {
      state = state.copyWith(currentLat: lat, currentLng: lng);
    }
  }

  GpsPoint? _decodePt(dynamic n) {
    if (n is List && n.length >= 2) {
      final lat = (n[0] as num?)?.toDouble();
      final lng = (n[1] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
      return GpsPoint(
        lat: lat,
        lng: lng,
        ele: n.length > 2 ? ((n[2] as num?)?.toDouble() ?? 0) : 0,
        t: n.length > 3 ? ((n[3] as num?)?.toInt() ?? 0) : 0,
      );
    }
    return null;
  }

  // ------------------------- jalur lama -------------------------

  Future<void> _startLegacy() async {
    // Fix pertama cepat (lastKnown) agar peta langsung tampil.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        state = state.copyWith(
            currentLat: last.latitude,
            currentLng: last.longitude,
            accuracyM: last.accuracy);
      }
    } catch (_) {}
    await _sub?.cancel();
    _startWall = DateTime.now();
    _pausedTotalSec = 0;
    _pauseBegan = null;
    _autoPausedNow = false;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    state = TrackState(
      status: TrackStatus.recording,
      message: '',
      autoPause: state.autoPause,
      startedAt: _startWall,
      currentLat: state.currentLat,
      currentLng: state.currentLng,
      accuracyM: state.accuracyM,
      lastEventMs: nowMs,
    );
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5, // hemat baterai: update tiap ~5 m
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onFix,
      onError: (Object e) {
        state = state.copyWith(
            status: TrackStatus.error, message: 'GPS error: $e');
      },
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (_useBg) return;
    if (state.status != TrackStatus.recording &&
        state.status != TrackStatus.paused) {
      return;
    }
    if (_startWall == null) return;
    final wallSec =
        DateTime.now().difference(_startWall!).inSeconds - _pausedTotalSec;
    state = state.copyWith(elapsedSec: wallSec < 0 ? 0 : wallSec);
  }

  void _onFix(Position pos) {
    if (_useBg) return;
    if (state.status != TrackStatus.recording &&
        state.status != TrackStatus.paused) {
      return;
    }
    // Akurasi buruk → tampilkan tapi jangan rekam ke rute.
    state = state.copyWith(
      currentLat: pos.latitude,
      currentLng: pos.longitude,
      accuracyM: pos.accuracy,
      currentSpeedMs: pos.speed < 0 ? 0 : pos.speed,
      lastEventMs: DateTime.now().millisecondsSinceEpoch,
    );
    if (pos.accuracy > 0 && pos.accuracy > 25) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final pts = List<GpsPoint>.of(state.points);
    final seed = rawFixToFilteredSeed(
        pos.latitude, pos.longitude, pos.altitude, now, pos.accuracy);
    if (seed == null) return;
    if (pts.isEmpty) {
      pts.add(seed);
    } else {
      final prev = pts.last;
      final dt = (seed.t - prev.t) / 1000.0;
      if (dt <= 0) return;
      final d = haversineM(prev.lat, prev.lng, seed.lat, seed.lng);
      if (d / dt > 22.2) return; // GPS jump
      if (d < 2.0 && dt < 3) {
        // Diam: jangan tambah poin, tapi deteksi auto-pause.
      } else {
        pts.add(seed);
      }
    }

    // Auto-pause ala Strava: diam >10 dtk → pause otomatis (jarak berhenti).
    if (state.autoPause && pts.length >= 2) {
      final still = pos.speed < 0.8;
      if (still && !_autoPausedNow) {
        _lastAutoMovingSec = state.movingSec;
        _autoPausedNow = true;
      } else if (!still && _autoPausedNow) {
        _autoPausedNow = false;
      }
    }

    final paused = state.status == TrackStatus.paused || _autoPausedNow;
    final dist = routeDistanceM(pts);
    final gain = routeElevationGain(pts);
    final moving = paused ? _lastAutoMovingSec : state.elapsedSec;
    final avg = state.elapsedSec > 0 ? dist / state.elapsedSec : 0.0;
    state = state.copyWith(
      points: pts,
      distanceM: dist,
      elevationGainM: gain,
      avgSpeedMs: avg,
      movingSec: moving,
    );
  }

  // ------------------------- kontrol (dua jalur) -------------------------

  void pause() {
    if (state.status != TrackStatus.recording) return;
    if (_useBg) {
      try {
        _svc.invoke('pause');
      } catch (_) {}
    } else {
      _pauseBegan = DateTime.now();
      _autoPausedNow = false;
    }
    state = state.copyWith(status: TrackStatus.paused, message: 'Jeda');
  }

  void resume() {
    if (state.status != TrackStatus.paused) return;
    if (_useBg) {
      try {
        _svc.invoke('resume');
      } catch (_) {}
    } else {
      if (_pauseBegan != null) {
        _pausedTotalSec += DateTime.now().difference(_pauseBegan!).inSeconds;
        _pauseBegan = null;
      }
    }
    state = state.copyWith(status: TrackStatus.recording, message: '');
  }

  void toggleAutoPause(bool v) {
    state = state.copyWith(autoPause: v);
    if (!v) _autoPausedNow = false;
    if (_useBg) {
      try {
        _svc.invoke('autoPause', {'enabled': v});
      } catch (_) {}
    }
  }

  /// Hentikan & kembalikan poin tersaring (disimplify agar DB ringan).
  List<GpsPoint> finish() {
    try {
      _svc.invoke('stop');
    } catch (_) {}
    _sub?.cancel();
    _ticker?.cancel();
    _sub = null;
    _ticker = null;
    final pts = simplifyRoute(state.points, 4);
    state = state.copyWith(status: TrackStatus.finished, points: pts);
    return pts;
  }

  void discard() {
    try {
      _svc.invoke('stop');
    } catch (_) {}
    _sub?.cancel();
    _ticker?.cancel();
    _sub = null;
    _ticker = null;
    _startWall = null;
    _pausedTotalSec = 0;
    _pauseBegan = null;
    _autoPausedNow = false;
    _useBg = false;
    _uiSeq = 0;
    _syncPending = false;
    state = const TrackState();
  }

  /// Bangun CyclingActivity dari hasil rekaman (dipanggil layar Finish).
  CyclingActivity toActivity({
    required String name,
    double heartRate = 0,
    String note = '',
  }) {
    final pts = state.points;
    final dist = routeDistanceM(pts);
    final gain = routeElevationGain(pts);
    final elapsed = state.elapsedSec;
    final avgMs = elapsed > 0 ? dist / elapsed : 0.0;
    final start = state.startedAt ?? DateTime.now();
    String p2(int n) => n.toString().padLeft(2, '0');
    final iso =
        '${start.year}-${p2(start.month)}-${p2(start.day)}T${p2(start.hour)}:${p2(start.minute)}:${p2(start.second)}Z';
    return CyclingActivity(
      name: name.trim().isEmpty ? 'Gowes GPS' : name.trim(),
      distance: dist,
      totalElevationGain: gain,
      averageSpeed: avgMs,
      startDate: iso,
      averageHeartRate: heartRate,
      note: note.trim(),
      routeJson: pts.length >= 2 ? encodeRoute(pts) : '',
      durationSec: elapsed.toDouble(),
    );
  }
}

final trackRecorderProvider =
    NotifierProvider<TrackRecorder, TrackState>(TrackRecorder.new);
