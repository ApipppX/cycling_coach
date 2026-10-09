import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../core/csv_utils.dart';
import '../../core/health_stats.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../widgets/activity_form.dart';
import '../widgets/common.dart';
import '../widgets/metric_hero.dart';
import '../widgets/responsive.dart';
import '../widgets/zone_chip.dart';
import '../theme/app_theme.dart';
import 'session_screens.dart';
import 'track_screen.dart';

const _sampleCsv = '''id,nama,tanggal,jarak_km,elevasi_m,kecepatan_kmh,hr_bpm,catatan
,Gowes Pagi,2026-09-01,25.50,150,25.0,140,"Rute biasa, angin sepoi"
,Long Ride,2026-09-06,60.00,400,24.0,135,"Santai, bawa 2 botol"
''';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashState();
}

/// Tombol mini di menu speed-dial dashboard (GPS/Manual/CSV).
class _FabMini extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FabMini(
      {required this.heroTag,
      required this.icon,
      required this.label,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
    ).animate().fadeIn(duration: 150.ms).scale(
        begin: const Offset(0.85, 0.85), curve: Curves.easeOut);
  }
}

class _DashState extends ConsumerState<DashboardScreen> {
  String query = '';
  SortMode sort = SortMode.terbaru;
  bool selectionMode = false;
  Set<int> selected = {};
  bool _fabOpen = false;

  @override
  Widget build(BuildContext context) {
    final actsAsync = ref.watch(activitiesProvider);
    final prefs = ref.watch(prefsProvider);
    // Hindari flash "Belum ada data": tampilkan loading saat stream dibuka.
    if (actsAsync.isLoading && !actsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text('CyclingCoach')),
        body: AppLoading(message: 'Memuat riwayat latihan...'),
      );
    }
    if (actsAsync.hasError && !actsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text('CyclingCoach')),
        body: ResponsiveList(children: [
          AppError(error: actsAsync.error!,
              onRetry: () => ref.invalidate(activitiesProvider)),
        ]),
      );
    }
    final acts = actsAsync.value ?? [];
    final weekKm = weekKmOf(acts);
    final streak = computeWeekStreak(acts);
    final sisa = (prefs.weeklyTargetKm - weekKm).clamp(0, 1e9);
    final subInsight = sisa <= 0
        ? 'Target tercapai! Pertahankan momentum.'
        : 'Sisa ${sisa.toStringAsFixed(1)} km • ±${requiredPerDay(weekKm, prefs.weeklyTargetKm).toStringAsFixed(1)} km/hari (${daysLeftInWeek()} hari tersisa)';
    var filtered = query.isEmpty
        ? List<CyclingActivity>.from(acts)
        : acts
            .where((a) =>
                a.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
    // Terbaru = tanggal mulai terbaru (bukan urutan input).
    if (sort == SortMode.terbaru) {
      filtered.sort((a, b) => b.startDate.compareTo(a.startDate));
    }
    if (sort == SortMode.terjauh) {
      filtered.sort((a, b) => b.distance.compareTo(a.distance));
    }
    if (sort == SortMode.tercepat) {
      filtered.sort((a, b) => b.averageSpeed.compareTo(a.averageSpeed));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            selectionMode ? '${selected.length} dipilih' : 'CyclingCoach'),
        actions: [
          if (selectionMode)
            IconButton(
                icon: Icon(Icons.delete, color: context.danger),
                tooltip: 'Hapus yang dipilih',
                onPressed: selected.isEmpty
                    ? null
                    : () async {
                        final db = ref.read(dbProvider);
                        for (final a in acts.where(
                            (e) => selected.contains(e.id))) {
                          await db.deleteActivity(a);
                        }
                        setState(() {
                          selectionMode = false;
                          selected = {};
                        });
                      })
          else ...[
            IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Bagikan CSV',
                onPressed: () async {
                  final f = File(
                      '${Directory.systemTemp.path}/cyclingcoach_riwayat.csv');
                  await f.writeAsString(buildActivitiesCsv(acts));
                  await SharePlus.instance.share(ShareParams(
                      files: [XFile(f.path)],
                      subject: 'Riwayat Latihan'));
                }),
            IconButton(
                icon: const Icon(Icons.flag),
                tooltip: 'Target mingguan',
                onPressed: () =>
                    _targetDialog(prefs.weeklyTargetKm, weekKm)),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Menu tambah ala speed-dial: 1 tombol utama, 3 aksi
          // (GPS/Manual/CSV) muncul di atasnya. Lebih ramping di HP kecil
          // dan sekalian menaikkan discoverability Impor CSV.
          if (_fabOpen) ...[
            _FabMini(
              heroTag: 'dashboard_gps',
              icon: Icons.fiber_manual_record,
              label: 'Rekam GPS',
              onTap: () {
                setState(() => _fabOpen = false);
                _goTrack();
              },
            ),
            const SizedBox(height: 10),
            _FabMini(
              heroTag: 'dashboard_manual',
              icon: Icons.add,
              label: 'Manual',
              onTap: () {
                setState(() => _fabOpen = false);
                _openForm(null);
              },
            ),
            const SizedBox(height: 10),
            _FabMini(
              heroTag: 'dashboard_csv',
              icon: Icons.upload,
              label: 'Impor CSV',
              onTap: () {
                setState(() => _fabOpen = false);
                _importCsv();
              },
            ),
            const SizedBox(height: 10),
          ],
          FloatingActionButton(
            heroTag: 'dashboard_fab',
            tooltip: _fabOpen ? 'Tutup' : 'Tambah latihan',
            onPressed: () =>
                setState(() => _fabOpen = !_fabOpen),
            child: AnimatedRotation(
              turns: _fabOpen ? 0.125 : 0,
              duration: 200.ms,
              child: Icon(_fabOpen ? Icons.close : Icons.add),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(activitiesProvider),
        child: ResponsiveList(children: [
        Row(children: [
          Expanded(
            child: Text(
                'Halo, ${prefs.userName.isEmpty ? 'Rider' : prefs.userName}!',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
          if (streak > 0) ...[
            const SizedBox(width: 8),
            Chip(
              avatar: const Icon(Icons.local_fire_department,
                  size: 16, color: Colors.deepOrange),
              label: Text('$streak mgg',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ]).animate().fadeIn(duration: 250.ms).slideY(
            begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        const SizedBox(height: AppSpacing.md),
        MetricHero(
          weekKm: weekKm,
          targetKm: prefs.weeklyTargetKm,
          sessions: acts
              .where((a) =>
                  a.dateKey.compareTo(weekStartMonday(0)) >= 0)
              .length,
          insight:
              generateCoachInsight(acts, prefs.weeklyTargetKm),
          subInsight: subInsight,
        ),
        const SizedBox(height: AppSpacing.md),
        SearchBar(
            hintText: 'Cari latihan...',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => query = v)),
        SectionTitle('Riwayat (${filtered.length})',
            action: TextButton(
                onPressed: () => setState(() {
                      selectionMode = true;
                      selected = {};
                    }),
                child: const Text('Pilih banyak'))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in SortMode.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(s == SortMode.terbaru
                      ? 'Terbaru'
                      : s == SortMode.terjauh
                          ? 'Terjauh'
                          : 'Tercepat'),
                  selected: sort == s,
                  onSelected: (_) => setState(() => sort = s),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.upload, size: 16),
              label: const Text('Impor CSV'),
              onPressed: _importCsv,
            ),
          ]),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Contoh CSV'),
              onPressed: () async {
                final f = File(
                    '${Directory.systemTemp.path}/contoh_cyclingcoach.csv');
                await f.writeAsString(_sampleCsv);
                await SharePlus.instance.share(ShareParams(
                    files: [XFile(f.path)],
                    subject: 'Contoh CSV CyclingCoach'));
              },
            ),
            Flexible(
              child: Text(
                  'Format: nama,tanggal,jarak,elevasi,kecepatan,HR,catatan',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
        if (acts.isEmpty)
          EmptyState(
            icon: Icons.directions_bike,
            title: 'Belum ada latihan.',
            subtitle:
                'Rekam GPS dengan peta, tambah manual, atau impor CSV.',
            actionLabel: 'Rekam GPS pertama',
            onAction: () => _goTrack(),
          ),
        ...filtered.asMap().entries.map((entry) {
          final a = entry.value;
          final kcal = estimateCaloriesKcal(a, prefs.weightKg);
          final zone = a.averageHeartRate > 0
              ? hrZoneName(a.averageHeartRate, prefs.maxHr)
              : '';
          return Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              selected: selected.contains(a.id),
              selectedTileColor:
                  Theme.of(context).colorScheme.primaryContainer,
              leading: selectionMode
                  ? Checkbox(
                      value: selected.contains(a.id),
                      onChanged: (_) => _toggle(a.id))
                  : ZoneAvatar(
                      zone: zone,
                      fallbackLetter: a.name.isEmpty ? 'C' : a.name),
              title: Text(a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                  '${formatDateShort(a.startDate)} • ${(a.distance / 1000).toStringAsFixed(1)} km • ${msToKmh(a.averageSpeed).toStringAsFixed(1)} km/h'
                  '${a.averageHeartRate > 0 ? ' • ${a.averageHeartRate.toInt()} bpm $zone' : ''} • ${kcal.toStringAsFixed(0)} kkal'
                  '${a.hasRoute ? ' • 🗺 GPS' : ''}'
                  '${a.note.isNotEmpty ? ' • ada catatan' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              trailing: selectionMode
                  ? null
                  : Builder(builder: (context) {
                      final narrow = context.isNarrow;
                      if (narrow) {
                        // HP sempit: satu menu agar tidak overflow.
                        return PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          padding: EdgeInsets.zero,
                          onSelected: (v) {
                            if (v == 'edit') {
                              _openForm(a);
                            } else {
                              ref.read(dbProvider).deleteActivity(a);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete',
                                child: Text('Hapus',
                                    style: TextStyle(
                                        color: context.danger))),
                          ],
                        );
                      }
                      return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit',
                                onPressed: () => _openForm(a)),
                            IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: context.danger),
                                tooltip: 'Hapus',
                                onPressed: () => ref
                                    .read(dbProvider)
                                    .deleteActivity(a)),
                          ]);
                    }),
              onTap: selectionMode
                  ? () => _toggle(a.id)
                  : () async {
                      final saved = await Navigator.push<CyclingActivity>(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  DetailScreen(activity: a)));
                      if (saved != null && context.mounted) {
                        _pushEvaluation(saved);
                      }
                    },
            ),
          );
        }),
        const SizedBox(height: 80),
        ]),
      ),
    );
  }

  void _toggle(int id) => setState(
      () => selected.contains(id) ? selected.remove(id) : selected.add(id));

  /// Buka layar Rekam GPS (peta OSM live + auto-pause + simpan ke DB).
  void _goTrack() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const TrackScreen()));
  }

  void _pushEvaluation(CyclingActivity saved) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => EvaluationScreen(activity: saved)));
  }

  Future<void> _openForm(CyclingActivity? initial) async {
    final saved = await showActivityForm(context, ref, initial);
    if (saved != null && mounted) _pushEvaluation(saved);
  }

  Future<void> _importCsv() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final f = files.first;
    String text;
    try {
      if (f.path != null) {
        text = await File(f.path!).readAsString();
      } else {
        text = await f.xFile.readAsString();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal impor: $e')));
      }
      return;
    }
    final parsed = parseActivitiesCsv(text);
    final db = ref.read(dbProvider);
    for (final a in parsed.activities) {
      await db.upsertActivity(a);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Impor: ${parsed.activities.length} masuk, ${parsed.skipped} dilewati')));
    }
  }

  void _targetDialog(double current, double weekKm) {
    final c = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Ubah target mingguan'),
              content: AppTextField(
                  controller: c,
                  label: 'Target (km/minggu)',
                  hint: 'cth 100',
                  icon: Icons.flag_outlined,
                  suffix: 'km',
                  keyboardType: TextInputType.number),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      final v = double.tryParse(c.text);
                      if (v != null && v > 0) {
                        ref.read(prefsProvider.notifier).updateTarget(v);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Simpan')),
              ],
            ));
  }
}
