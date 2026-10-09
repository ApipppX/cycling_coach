import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../models/models.dart';
import 'geo_utils.dart';

// TODO(ios): butuh kapabilitas "Background Modes" dicentang di Xcode
// (Runner target → Signing & Capabilities → + Capability → Background Modes
// → Location + Background fetch). Tanpa itu iOS tetap merekam saat app di
// depan, tapi bisa disetop sistem saat layar lama mati.

/// ID kanal notifikasi perekaman (muncul permanen saat merekam).
const trackNotifChannelId = 'cycling_track';

/// Inisialisasi sekali di main() (khusus mobile; aman dipanggil di mana saja).
Future<void> initializeTrackService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: trackServiceEntry,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: trackNotifChannelId,
      initialNotificationTitle: 'CyclingCoach merekam',
      initialNotificationContent: 'Menyiapkan GPS…',
      foregroundServiceNotificationId: 888,
      foregroundServiceTypes: [AndroidForegroundType.location],
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: trackServiceEntry,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Entry-point isolate latar. JANGAN panggil langsung — dijalankan OS.
@pragma('vm:entry-point')
Future<void> trackServiceEntry(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final engine = _BgEngine(service);
  service.on('start').listen((e) => engine.start(e));
  service.on('pause').listen((_) => engine.pause());
  service.on('resume').listen((_) => engine.resume());
  service.on('autoPause').listen((e) => engine.setAutoPause(
      (e?['enabled'] as bool?) ?? true));
  service.on('stop').listen((_) => engine.stop());
  service.on('sync').listen((_) => engine.pushFull());
  service.on('ping').listen((_) => engine.pong());
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
  }
  // Beri tahu UI yang (re)attach bahwa service hidup.
  engine.pong();
}

String _fmtClock(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String p2(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${p2(m)}:${p2(s)}' : '${p2(m)}:${p2(s)}';
}

/// Mesin GPS yang hidup di isolate latar (foreground service Android).
/// UI (TrackRecorder) hanya klien tipis: start/pause/resume/stop/sync/ping
/// dan menerima event 'pos' (delta) + 'full' (sinkron penuh) + 'pong'.
///
/// Perbedaan perilaku vs perekam lama (disengaja, lebih benar):
/// - Jeda MANUAL benar-benar menghentikan jarak (dulu stream tetap jalan
///   sehingga jarak bertambah saat jeda — teks UI sendiri bilang berhenti).
/// - elapsed dihitung di sini dari wall-clock, jadi tetap akurat walau
///   isolate UI disetop OS saat layar mati.
class _BgEngine {
  final ServiceInstance _service;
  StreamSubscription<Position>? _sub;

  final List<GpsPoint> _pts = [];
  int _seq = 0;
  bool _recording = false;
  bool _paused = false;
  bool _autoPaused = false;
  bool _autoPauseEnabled = true;

  DateTime? _startWall;
  int _pausedTotalSec = 0;
  DateTime? _pauseBegan;
  int _frozenMovingSec = 0;

  double? _curLat;
  double? _curLng;
  double _lastAcc = 0;
  double _lastSpeedMs = 0;
  int _notifCount = 0;

  _BgEngine(this._service);

  int get _elapsedSec {
    final w = _startWall;
    if (w == null) return 0;
    final v =
        DateTime.now().difference(w).inSeconds - _pausedTotalSec;
    return v < 0 ? 0 : v;
  }

  void start(Map<String, dynamic>? args) {
    // Selalu sesi baru (UI hanya invoke ini dari tombol Mulai).
    _pts.clear();
    _seq = 0;
    _recording = true;
    _paused = false;
    _autoPaused = false;
    _autoPauseEnabled = (args?['autoPause'] as bool?) ?? true;
    _startWall = DateTime.now();
    _pausedTotalSec = 0;
    _pauseBegan = null;
    _frozenMovingSec = 0;
    _curLat = null;
    _curLng = null;
    _notifCount = 0;
    // Fix cepat agar peta UI langsung punya titik tengah.
    Geolocator.getLastKnownPosition().then((last) {
      if (last != null && _recording) {
        _curLat = last.latitude;
        _curLng = last.longitude;
        _lastAcc = last.accuracy;
        _push(snapshot());
      }
    }).catchError((_) {});
    _sub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onFix,
      onError: (_) {
        // Stream mati (GPS dimatikan user?) — beri tahu UI.
        if (_recording) {
          _service.invoke('pos', {
            ...snapshot(),
            'streamError': true,
          });
        }
      },
    );
    _push(snapshot());
  }

  void _onFix(Position pos) {
    if (!_recording) return;
    _curLat = pos.latitude;
    _curLng = pos.longitude;
    _lastAcc = pos.accuracy;
    _lastSpeedMs = pos.speed < 0 ? 0 : pos.speed;

    // Jeda manual: titik hidup tetap dikirim (dot peta), rute berhenti.
    if (_paused) {
      _push(snapshot());
      return;
    }

    if (pos.accuracy > 0 && pos.accuracy > 25) {
      _push(snapshot());
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final seed = rawFixToFilteredSeed(
        pos.latitude, pos.longitude, pos.altitude, now, pos.accuracy);
    if (seed == null) {
      _push(snapshot());
      return;
    }
    var appended = false;
    if (_pts.isEmpty) {
      _pts.add(seed);
      appended = true;
    } else {
      final prev = _pts.last;
      final dt = (seed.t - prev.t) / 1000.0;
      if (dt > 0) {
        final d = haversineM(prev.lat, prev.lng, seed.lat, seed.lng);
        if (d / dt <= 22.2) {
          // GPS jump.
          if (!(d < 2.0 && dt < 3)) {
            // Diam di lampu merah: hemat poin.
            _pts.add(seed);
            appended = true;
          }
        }
      }
    }
    if (appended) _seq++;

    // Auto-pause ala Strava.
    if (_autoPauseEnabled && _pts.length >= 2) {
      final still = pos.speed < 0.8;
      if (still && !_autoPaused) {
        _frozenMovingSec = _elapsedSec;
        _autoPaused = true;
      } else if (!still && _autoPaused) {
        _autoPaused = false;
      }
    }

    final snap = snapshot(newPts: appended ? [_pts.last] : const []);
    _push(snap);
    if (appended) _notify(snap);
  }

  void pause() {
    if (!_recording || _paused) return;
    _paused = true;
    _pauseBegan = DateTime.now();
    _autoPaused = false;
    _push(snapshot());
  }

  void resume() {
    if (!_recording || !_paused) return;
    if (_pauseBegan != null) {
      _pausedTotalSec +=
          DateTime.now().difference(_pauseBegan!).inSeconds;
      _pauseBegan = null;
    }
    _paused = false;
    _push(snapshot());
  }

  void setAutoPause(bool v) {
    _autoPauseEnabled = v;
    if (!v) _autoPaused = false;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _recording = false;
    _paused = false;
    try {
      _service.stopSelf();
    } catch (_) {}
  }

  void pushFull() {
    if (!_recording && _pts.isEmpty && _startWall == null) {
      // Belum pernah merekam sesi ini — tetap jawab agar UI tak menunggu.
      _service.invoke('full', snapshot());
      return;
    }
    final m = snapshot();
    m['points'] = [
      for (final p in _pts.take(20000)) [p.lat, p.lng, p.ele, p.t],
    ];
    _service.invoke('full', m);
  }

  void pong() => _service.invoke('pong', snapshot());

  Map<String, dynamic> snapshot({List<GpsPoint> newPts = const []}) {
    final elapsed = _elapsedSec;
    return {
      'seq': _seq,
      'recording': _recording,
      'paused': _paused,
      'autoPaused': _autoPaused,
      'lat': _curLat,
      'lng': _curLng,
      'acc': _lastAcc,
      'spd': _lastSpeedMs,
      'newPts': [
        for (final p in newPts) [p.lat, p.lng, p.ele, p.t],
      ],
      'distM': routeDistanceM(_pts),
      'gainM': routeElevationGain(_pts),
      'elapsed': elapsed,
      'moving': _autoPaused ? _frozenMovingSec : elapsed,
      'nPts': _pts.length,
      'startedAtMs': _startWall?.millisecondsSinceEpoch ?? 0,
    };
  }

  void _push(Map<String, dynamic> m) {
    try {
      _service.invoke('pos', m);
    } catch (_) {}
  }

  void _notify(Map<String, dynamic> snap) {
    final s = _service;
    if (s is! AndroidServiceInstance) return;
    _notifCount++;
    if (_notifCount % 2 == 0) return; // hemat: tiap ~2 titik
    final distKm = (snap['distM'] as double) / 1000.0;
    final elapsed = snap['elapsed'] as int;
    final spdKmh = (snap['spd'] as double) * 3.6;
    final acc = snap['acc'] as double;
    try {
      s.setForegroundNotificationInfo(
        title: '● Merekam ${distKm.toStringAsFixed(2)} km',
        content:
            '${_fmtClock(elapsed)} • ${spdKmh.toStringAsFixed(1)} km/h • GPS ±${acc.toStringAsFixed(0)} m',
      );
    } catch (_) {}
  }
}
