import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../core/health_stats.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../../core/geo_utils.dart';
import '../widgets/activity_form.dart';
import '../widgets/common.dart';
import '../widgets/elev_chart.dart';
import '../widgets/responsive.dart';
import '../widgets/route_map.dart';
import '../theme/app_theme.dart';
import 'track_screen.dart' show shareGpx;

class DetailScreen extends ConsumerWidget {
  final CyclingActivity activity;
  const DetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final kcal = estimateCaloriesKcal(activity, prefs.weightKg);
    final trimp = trimpOf(activity, prefs.maxHr);
    final zone = hrZoneName(activity.averageHeartRate, prefs.maxHr);
    // Statistik turunan GPS (Strava-like) — SEMUA otomatis dari rute,
    // tanpa input user. Sesi manual → list kosong, UI fallback ke tabel.
    final routePts = decodeRoute(activity.routeJson);
    final hasGps = routePts.length >= 2;
    final elev = hasGps ? elevationSamples(routePts) : const <ElevSample>[];
    final splits = hasGps ? computeSplits(routePts) : const <KmSplit>[];
    final maxKmh = hasGps ? maxSpeedMs(routePts) * 3.6 : 0.0;
    final lossM = hasGps ? routeElevationLoss(routePts) : 0.0;
    final moveKmh = hasGps ? movingAvgKmh(routePts) : 0.0;
    final moveSec = hasGps ? movingTimeSec(routePts).round() : 0;
    final fast = hasGps ? fastestSplit(splits) : null;
    final eleMM = hasGps ? eleMinMax(routePts) : (min: 0.0, max: 0.0);
    String fmtDur(double min) {
      if (min <= 0) return '-';
      if (min >= 60) return '${(min ~/ 60)}j ${min.round() % 60}m';
      return '${min.toStringAsFixed(0)} mnt';
    }

    final rows = <List<String>>[
      ['Tanggal', formatDateShort(activity.startDate)],
      ['Jarak', '${activity.distanceKm.toStringAsFixed(2)} km'],
      [
        'Durasi total',
        activity.durationMin > 0
            ? fmtDur(activity.durationMin)
            : '-'
      ],
      if (hasGps && moveSec > 0)
        ['Waktu gerak', fmtDur(moveSec / 60.0)],
      ['Kecepatan avg', '${activity.speedKmh.toStringAsFixed(1)} km/h'],
      if (hasGps && moveKmh > 0)
        ['Avg gerak', '${moveKmh.toStringAsFixed(1)} km/h'],
      if (hasGps && maxKmh > 0)
        ['Max', '${maxKmh.toStringAsFixed(1)} km/h'],
      if (hasGps && fast != null)
        [
          'Terkencang',
          'KM ${fast.index} • ${fast.avgKmh.toStringAsFixed(1)} km/h'
        ],
      ['Elevasi naik', '${activity.totalElevationGain.toStringAsFixed(0)} m'],
      if (hasGps && lossM > 0)
        ['Elevasi turun', '${lossM.toStringAsFixed(0)} m'],
      if (hasGps && eleMM.max > eleMM.min)
        [
          'Elev min–maks',
          '${eleMM.min.toStringAsFixed(0)}–${eleMM.max.toStringAsFixed(0)} m'
        ],
      [
        'HR rata-rata',
        activity.averageHeartRate > 0
            ? '${activity.averageHeartRate.toInt()} bpm ($zone)'
            : '-'
      ],
      ['TRIMP', trimp > 0 ? trimp.toStringAsFixed(0) : '-'],      ['Est. kalori', kcal > 0 ? '${kcal.toStringAsFixed(0)} kkal' : '-'],
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(activity.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit latihan',
            onPressed: () async {
              final saved = await showActivityForm(context, ref, activity);
              if (saved != null && context.mounted) Navigator.pop(context, saved);
            },
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: context.danger),
            tooltip: 'Hapus latihan',
            onPressed: () async {
              final ok = await showAppConfirm(context,
                  title: 'Hapus latihan?',
                  message:
                      '"${activity.name}" akan dihapus permanen.');
              if (ok) {
                await ref.read(dbProvider).deleteActivity(activity);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ResponsiveList(
        children: [
          // Peta rute GPS (Strava-like). Sesi manual → placeholder ramah.
          RouteMap(routeJson: activity.routeJson, height: 230),
          const SizedBox(height: AppSpacing.sm),
          if (activity.hasRoute)
            AppButton(
              icon: Icons.share_outlined,
              label:
                  'Bagikan GPX (${decodeRoute(activity.routeJson).length} titik)',
              tonal: true,
              onPressed: () => shareGpx(context, activity.name,
                  activity.routeJson, activity.startDate),
            ),
          const SizedBox(height: AppSpacing.sm),
          // --- Ringkasan ala Strava: tiles + grafik elevasi + splits/km ---
          if (hasGps) ...[
            AppStatsGrid(children: [
              StatTile(activity.distanceKm.toStringAsFixed(2), 'Jarak (km)',
                  icon: Icons.route_outlined),
              StatTile(
                  activity.durationMin >= 60
                      ? '${(activity.durationMin ~/ 60)}j ${activity.durationMin.round() % 60}m'
                      : '${activity.durationMin.toStringAsFixed(0)} mnt',
                  'Durasi total',
                  icon: Icons.timer_outlined),
              StatTile(activity.speedKmh.toStringAsFixed(1), 'Avg km/h',
                  icon: Icons.speed_outlined),
              if (moveKmh > 0)
                StatTile(moveKmh.toStringAsFixed(1), 'Avg gerak',
                    icon: Icons.directions_bike_outlined,
                    sub: moveSec > 0
                        ? '${(moveSec ~/ 60)} mnt gerak'
                        : null),
              if (maxKmh > 0)
                StatTile(maxKmh.toStringAsFixed(1), 'Max km/h',
                    icon: Icons.bolt_outlined,
                    sub: fast != null ? 'KM ${fast.index}' : null),
              StatTile(
                  '+${activity.totalElevationGain.toStringAsFixed(0)}',
                  'Elevasi (m)',
                  icon: Icons.terrain_outlined,
                  sub: lossM > 0
                      ? '−${lossM.toStringAsFixed(0)} m turun'
                      : null),
              StatTile(kcal.toStringAsFixed(0), 'Kalori (kkal)',
                  icon: Icons.local_fire_department_outlined),
            ]),
            // Banner "di mana tercepat": KM tercepat otomatis dari splits.
            if (fast != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Card(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.7),
                child: ListTile(
                  leading: Icon(Icons.bolt_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: Text(
                      'Terkencang: KM ${fast.index} • ${fast.avgKmh.toStringAsFixed(1)} km/h',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(
                      '${_fmtSplit(fast.seconds)} • +${fast.elevGainM.toStringAsFixed(0)} m elev pada KM itu',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            ElevProfileChart(samples: elev),
            if (splits.isNotEmpty) ...[
              const SectionTitle('Split per km'),
              ScrollTable(
                headers: const ['KM', 'WAKTU', 'KEC', 'ELEV'],
                flexes: const [2, 3, 3, 3],
                rows: [
                  for (final s in splits)
                    [
                      Text(
                          s.index.toString() +
                              (fast != null && s.index == fast.index
                                  ? ' ⚡'
                                  : ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: fast != null &&
                                      s.index == fast.index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: fast != null &&
                                      s.index == fast.index
                                  ? Theme.of(context).colorScheme.primary
                                  : null)),
                      Text(_fmtSplit(s.seconds),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: fast != null &&
                                      s.index == fast.index
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      Text('${s.avgKmh.toStringAsFixed(1)} km/h',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: fast != null &&
                                      s.index == fast.index
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                      Text('+${s.elevGainM.toStringAsFixed(0)} m',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
          ],
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    ListTile(
                      dense: true,
                      title: Text(rows[i][0],
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall),
                      trailing: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth:
                                context.isNarrow ? 140 : 220),
                        child: Text(rows[i][1],
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (i < rows.length - 1)
                      Divider(
                          height: 1,
                          indent: AppSpacing.lg,
                          endIndent: AppSpacing.lg,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.4)),
                  ],
                ],
              ),
            ),
          ),
          if (activity.note.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.notes_outlined),
                title: Text('Catatan',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium),
                subtitle: Text(activity.note,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            icon: Icons.analytics_outlined,
            label: 'Evaluasi Sesi',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EvaluationScreen(activity: activity)),
            ),
          ),
        ],
      ),
    );
  }
}

/// mm:ss (atau h:mm:ss bila ≥1 jam) untuk tabel split/km.
String _fmtSplit(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  String p2(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${p2(m)}:${p2(s)}' : '${p2(m)}:${p2(s)}';
}

class EvaluationScreen extends ConsumerWidget {
  final CyclingActivity activity;
  const EvaluationScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final acts = ref.watch(activitiesProvider).value ?? [];
    final prefs = ref.watch(prefsProvider);
    final others = acts.where((a) => a.id != activity.id).toList();
    final an = ref.watch(coachAnalysisProvider);
    final ev = evaluateSession(activity, others, prefs.maxHr, an.tsb);
    final color = ev.tone == SessionTone.good
        ? context.success
        : ev.tone == SessionTone.warn
            ? context.danger
            : context.infoColor;
    return Scaffold(
      appBar: AppBar(title: Text('Evaluasi Sesi')),
      body: ResponsiveList(
        children: [
          Card(
            color: color.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(
                      ev.tone == SessionTone.good
                          ? Icons.check_circle_rounded
                          : ev.tone == SessionTone.warn
                              ? Icons.warning_amber_rounded
                              : Icons.info_rounded,
                      color: color,
                      size: 28),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(ev.verdict,
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SectionTitle('Kekuatan'),
          ...ev.strengths.map((s) => Card(
              child: ListTile(
                  leading:
                      Icon(Icons.check_circle_outline, color: context.success),
                  title: Text(s, maxLines: 3, overflow: TextOverflow.ellipsis)))),
          const SectionTitle('Perhatian'),
          ...ev.gaps.map((g) => Card(
              child: ListTile(
                  leading: Icon(Icons.warning_amber_outlined,
                      color: context.warning),
                  title: Text(g, maxLines: 3, overflow: TextOverflow.ellipsis)))),
          const SizedBox(height: AppSpacing.sm),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.track_changes,
                          color:
                              Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'Fokus berikutnya: ${ev.focusNext}')),
                    ],
                  ))),
        ],
      ),
    );
  }
}
