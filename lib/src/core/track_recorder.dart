import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
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
      );
}

/// Perekam GPS foreground: stream Geolocator akurasi terbaik,
/// filter anti-jump, auto-pause saat diam, dan ringkasan Strava-like.
///
/// Bukan background service (cukup untuk v1; OS boleh kill bila layar mati
/// lama — dijelaskan di README + banner UI).
class TrackRecorder extends Notifier<TrackState> {
  StreamSubscription<Position>? _sub;
  Timer? _ticker;
  DateTime? _startWall;
  int _pausedTotalSec = 0;
  DateTime? _pauseBegan;
  int _lastAutoMovingSec = 0;
  bool _autoPausedNow = false;

  @override
  TrackState build() => const TrackState();

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

  Future<void> start() async {
    state = state.copyWith(status: TrackStatus.locating, message: 'Mencari GPS…');
    if (!await ensurePermission()) return;
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
    state = TrackState(
      status: TrackStatus.recording,
      message: '',
      autoPause: state.autoPause,
      startedAt: _startWall,
      currentLat: state.currentLat,
      currentLng: state.currentLng,
      accuracyM: state.accuracyM,
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
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
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

  void pause() {
    if (state.status != TrackStatus.recording) return;
    _pauseBegan = DateTime.now();
    _autoPausedNow = false;
    state = state.copyWith(status: TrackStatus.paused, message: 'Jeda');
  }

  void resume() {
    if (state.status != TrackStatus.paused) return;
    if (_pauseBegan != null) {
      _pausedTotalSec += DateTime.now().difference(_pauseBegan!).inSeconds;
      _pauseBegan = null;
    }
    state = state.copyWith(status: TrackStatus.recording, message: '');
  }

  void toggleAutoPause(bool v) {
    state = state.copyWith(autoPause: v);
    if (!v) _autoPausedNow = false;
  }

  /// Hentikan & kembalikan poin tersaring (disimplify agar DB ringan).
  List<GpsPoint> finish() {
    _sub?.cancel();
    _ticker?.cancel();
    _sub = null;
    _ticker = null;
    final pts = simplifyRoute(state.points, 4);
    state = state.copyWith(status: TrackStatus.finished, points: pts);
    return pts;
  }

  void discard() {
    _sub?.cancel();
    _ticker?.cancel();
    _sub = null;
    _ticker = null;
    _startWall = null;
    _pausedTotalSec = 0;
    _pauseBegan = null;
    _autoPausedNow = false;
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
