import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/geo_utils.dart';
import '../../core/track_recorder.dart';
import '../../data/prefs.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/route_map.dart';

String _fmtClock(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String p2(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${p2(m)}:${p2(s)}' : '${p2(m)}:${p2(s)}';
}

/// Layar Rekam GPS ala Strava: peta OSM live + stats + start/pause/finish.
///
/// Alur: Start → locating → recording (peta mengikuti) → pause/resume →
/// Finish → dialog simpan (nama/HR/catatan) → tersimpan ke Drift + evaluasi.
class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});
  @override
  ConsumerState<TrackScreen> createState() => _TrackState();
}

class _TrackState extends ConsumerState<TrackScreen> {
  final _map = MapController();
  bool _follow = true;
  LatLng? _lastCentered;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _maybeFollow(TrackState t) {
    if (!_follow || t.currentLat == null || t.currentLng == null) return;
    final cur = LatLng(t.currentLat!, t.currentLng!);
    if (_lastCentered == null ||
        haversineM(_lastCentered!.latitude, _lastCentered!.longitude,
                cur.latitude, cur.longitude) >
            15) {
      _lastCentered = cur;
      try {
        _map.move(cur, _map.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trackRecorderProvider);
    final rec = ref.read(trackRecorderProvider.notifier);
    ref.listen(trackRecorderProvider, (_, next) => _maybeFollow(next));

    final live = t.status == TrackStatus.recording ||
        t.status == TrackStatus.paused ||
        t.status == TrackStatus.locating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekam GPS'),
        actions: [
          Row(children: [
            const Icon(Icons.pause_circle_outline, size: 18),
            Switch(
              value: t.autoPause,
              onChanged: live ? null : rec.toggleAutoPause,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ],
      ),
      body: Column(children: [
        // Banner akurasi / status.
        if (t.status == TrackStatus.error)
          MaterialBanner(
            content: Text(t.message,
                maxLines: 3, overflow: TextOverflow.ellipsis),
            leading: const Icon(Icons.warning_amber_rounded),
            actions: [
              TextButton(
                  onPressed: () => rec.discard(),
                  child: const Text('Tutup')),
            ],
          ),
        if (!live && t.status != TrackStatus.finished)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.6),
            child: Text(
              'GPS foreground aktif saat merekam. Kunci layar lama bisa menghentikan update di sebagian HP — biarkan app di depan untuk hasil terbaik.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          flex: 5,
          child: Stack(children: [
            LiveTrackMap(
              points: t.points,
              currentLat: t.currentLat,
              currentLng: t.currentLng,
              controller: _map,
            ),
            // Chip status di atas peta.
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(children: [
                _StatusChip(track: t),
                const Spacer(),
                if (t.accuracyM > 0 && live)
                  Chip(
                    avatar: Icon(
                      t.accuracyM <= 15
                          ? Icons.gps_fixed
                          : Icons.gps_not_fixed,
                      size: 16,
                    ),
                    label: Text('±${t.accuracyM.toStringAsFixed(0)} m'),
                    visualDensity: VisualDensity.compact,
                  ),
              ]),
            ),
            // Tombol follow / recenter + zoom ala GMaps.
            if (live)
              Positioned(
                bottom: 12,
                right: 12,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'follow_btn',
                        tooltip: _follow ? 'Ikuti saya: ON' : 'Ikuti saya: OFF',
                        onPressed: () {
                          final next = !_follow;
                          setState(() => _follow = next);
                          // Saat dinyalakan lagi → langsung lompat ke posisi.
                          if (next &&
                              t.currentLat != null &&
                              t.currentLng != null) {
                            try {
                              _map.move(
                                  LatLng(t.currentLat!, t.currentLng!),
                                  _map.camera.zoom);
                            } catch (_) {}
                          }
                        },
                        child: Icon(_follow
                            ? Icons.my_location
                            : Icons.location_searching),
                      ),
                      const SizedBox(height: 8),
                      MapZoomButtons(controller: _map),
                    ]),
              ),
            // Zoom tetap tersedia sebelum GPS lock agar user bisa jelajah.
            if (!live)
              Positioned(
                bottom: 12,
                right: 12,
                child: MapZoomButtons(controller: _map),
              ),
            const Positioned(
              left: 10,
              bottom: 10,
              child: MapOfflineHint(),
            ),
          ]),
        ),
        // Panel statistik live.
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LiveStat(
                    value: t.distanceKm.toStringAsFixed(2),
                    label: 'Jarak (km)'),
                _LiveStat(
                    value: _fmtClock(t.elapsedSec), label: 'Waktu'),
                _LiveStat(
                    value: t.currentKmh > 0.5
                        ? t.currentKmh.toStringAsFixed(1)
                        : (t.elapsedSec > 0
                            ? (t.distanceM / t.elapsedSec * 3.6)
                                .toStringAsFixed(1)
                            : '0.0'),
                    label: 'Kec (km/h)'),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _LiveStat(
                    value: '${t.elevationGainM.toStringAsFixed(0)} m',
                    label: 'Elevasi',
                    small: true),
                _LiveStat(
                    value: '${t.points.length} titik',
                    label: 'GPS',
                    small: true),
                _LiveStat(
                    value: t.startedAt == null
                        ? '-'
                        : '${t.startedAt!.hour.toString().padLeft(2, '0')}:${t.startedAt!.minute.toString().padLeft(2, '0')}',
                    label: 'Mulai',
                    small: true),
              ],
            ),
          ]),
        ),
        // Kontrol rekaman.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _controls(context, ref, t),
          ),
        ),
      ]),
    );
  }

  Widget _controls(
      BuildContext context, WidgetRef ref, TrackState t) {
    final rec = ref.read(trackRecorderProvider.notifier);
    switch (t.status) {
      case TrackStatus.idle:
      case TrackStatus.error:
      case TrackStatus.finished:
        return AppButton(
          icon: Icons.fiber_manual_record,
          label: t.status == TrackStatus.finished
              ? 'Rekam Lagi'
              : 'Mulai Rekam',
          onPressed: () async {
            if (t.status == TrackStatus.finished) rec.discard();
            await rec.start();
          },
        );
      case TrackStatus.locating:
        return const AppButton(
            icon: Icons.gps_fixed, label: 'Mencari GPS…', onPressed: null, loading: true);
      case TrackStatus.recording:
        return Row(children: [
          Expanded(
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Jeda'),
              onPressed: rec.pause,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Selesai'),
              style: FilledButton.styleFrom(
                  backgroundColor: context.success),
              onPressed: () => _finishFlow(context, ref),
            ),
          ),
        ]);
      case TrackStatus.paused:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          if (t.message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Jeda — jarak & waktu berhenti.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Lanjut'),
                onPressed: rec.resume,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Selesai'),
                onPressed: () => _finishFlow(context, ref),
              ),
            ),
          ]),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Buang rekaman'),
            onPressed: () async {
              final ok = await showAppConfirm(context,
                  title: 'Buang rekaman?',
                  message:
                      '${t.distanceKm.toStringAsFixed(1)} km (${_fmtClock(t.elapsedSec)}) akan hilang.');
              if (ok) rec.discard();
            },
          ),
        ]);
    }
  }

  Future<void> _finishFlow(BuildContext context, WidgetRef ref) async {
    final rec = ref.read(trackRecorderProvider.notifier);
    final t = ref.read(trackRecorderProvider);
    if (t.points.length < 2 || t.distanceM < 50) {
      final ok = await showAppConfirm(context,
          title: 'Rekaman terlalu pendek?',
          message:
              'Jarak ${t.distanceKm.toStringAsFixed(2)} km. Simpan tetap, atau buang?',
          confirmLabel: 'Tetap simpan',
          cancelLabel: 'Buang',
          destructive: false);
      if (!ok) {
        rec.discard();
        return;
      }
    }
    rec.finish();
    if (!context.mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SaveDialog(),
    );
    if (saved == true && context.mounted) {
      showAppSnack(context,
          'Tersimpan! Lihat di Beranda + peta rute di Detail.');
      // Kembali ke Beranda agar user langsung lihat hasilnya.
      // (HomeShell pakai IndexedStack — cukup reset recorder.)
      rec.discard();
    } else {
      rec.discard();
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TrackState track;
  const _StatusChip({required this.track});
  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (track.status) {
      TrackStatus.recording =>
        (track.autoPause ? '● MEREKAM' : '● MEREKAM', Colors.red),
      TrackStatus.paused => ('⏸ JEDA', Colors.orange),
      TrackStatus.locating => ('… MENCARI GPS', Colors.blue),
      TrackStatus.finished => ('✓ SELESAI', Colors.green),
      TrackStatus.error => ('! GPS ERROR', Colors.red),
      TrackStatus.idle => ('○ SIAP', Colors.grey),
    };
    return Chip(
      label: Text(label,
          style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 12)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
    );
  }
}

class _LiveStat extends StatelessWidget {
  final String value;
  final String label;
  final bool small;
  const _LiveStat(
      {required this.value, required this.label, this.small = false});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value,
            style: TextStyle(
                fontSize: small ? 15 : 22,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ),
      Text(label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

/// Dialog simpan hasil rekaman → tulis ke Drift (termasuk routeJson).
class _SaveDialog extends ConsumerStatefulWidget {
  const _SaveDialog();
  @override
  ConsumerState<_SaveDialog> createState() => _SaveState();
}

class _SaveState extends ConsumerState<_SaveDialog> {
  final _name = TextEditingController();
  final _hr = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _name.text =
        'Gowes ${now.day}/${now.month} ${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trackRecorderProvider);
    final prefs = ref.watch(prefsProvider);
    final dist = t.distanceKm;
    // Estimasi kalori inline (rumus sama dengan health_stats, tanpa
    // encode ulang rute): faktor 0,20 + 0,008×kecepatan.
    final avgKmh =
        t.elapsedSec > 0 ? t.distanceM / t.elapsedSec * 3.6 : 0.0;
    final kcal = dist *
        prefs.weightKg.clamp(30.0, 200.0) *
        (0.20 + 0.008 * avgKmh.clamp(0.0, 60.0));
    return AlertDialog(
      title: const Text('Simpan Hasil Rekaman'),
      content: SizedBox(
        width: context.isCompact ? double.maxFinite : 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Card(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _sum('${dist.toStringAsFixed(2)} km', 'Jarak'),
                    _sum(_fmtClock(t.elapsedSec), 'Waktu'),
                    _sum('${t.elevationGainM.toStringAsFixed(0)} m',
                        'Elevasi'),
                    _sum(kcal.toStringAsFixed(0), 'kkal'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
                controller: _name,
                label: 'Nama',
                hint: 'cth Gowes Pagi Sudirman',
                icon: Icons.directions_bike_outlined),
            const SizedBox(height: 12),
            AppTextField(
                controller: _hr,
                label: 'HR rata-rata (opsional)',
                hint: 'cth 140',
                icon: Icons.favorite_outline,
                suffix: 'bpm',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false)),
            const SizedBox(height: 12),
            AppTextField(
                controller: _note,
                label: 'Catatan (opsional)',
                hint: 'Rute, cuaca, perasaan…',
                icon: Icons.notes_outlined,
                maxLines: 2),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Buang')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }

  Widget _sum(String v, String l) => Column(children: [
        Text(v,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15)),
        Text(l, style: const TextStyle(fontSize: 11)),
      ]);

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final rec = ref.read(trackRecorderProvider.notifier);
      final hr = double.tryParse(_hr.text.replaceAll(',', '.')) ?? 0;
      if (hr != 0 && (hr < 40 || hr > 220)) {
        throw 'HR harus 40–220 bpm (atau kosong).';
      }
      final act = rec.toActivity(
          name: _name.text, heartRate: hr, note: _note.text);
      final db = ref.read(dbProvider);
      await db.upsertActivity(act);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _saving = false;
        _err = '$e';
      });
    }
  }
}

/// Tombol ekspor GPX untuk DetailScreen (Strava/Garmin compatible).
Future<void> shareGpx(
    BuildContext context, String name, String routeJson, String startIso) async {
  final pts = decodeRoute(routeJson);
  if (pts.length < 2) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada rute GPS.')));
    return;
  }
  DateTime start;
  try {
    start = DateTime.parse(startIso);
  } catch (_) {
    start = DateTime.now();
  }
  final gpx = buildGpx(name, pts, start);
  final safe =
      name.replaceAll(RegExp(r'[^\w\- ]+'), '').trim().replaceAll(' ', '_');
  final f = File(
      '${Directory.systemTemp.path}/${safe.isEmpty ? 'route' : safe}.gpx');
  await f.writeAsString(gpx);
  await SharePlus.instance
      .share(ShareParams(files: [XFile(f.path)], subject: 'Rute GPX $name'));
}
