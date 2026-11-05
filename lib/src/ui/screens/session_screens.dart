import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../core/health_stats.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../../core/geo_utils.dart' show decodeRoute, elevationSamples, movingTimeSec, ElevSample, KmSplit, computeSplits, maxSpeedMs, routeElevationLoss, movingAvgKmh, fastestSplit, eleMinMax;
import '../widgets/activity_form.dart';
import '../widgets/common.dart';
import '../widgets/elev_chart.dart';
import '../widgets/responsive.dart';
import '../widgets/route_map.dart';
import '../theme/app_theme.dart';
import 'track_screen.dart' show shareGpx;

/// Pembungkus detail: daftar aktivitas kini ringan (tanpa `route_json`),
/// jadi rute lengkap diambil per-ID saat layar dibuka. Ini mencegah HP
/// dengan riwayat panjang kehabisan memori.
class DetailScreen extends ConsumerWidget {
  final CyclingActivity activity;
  const DetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (activity.id <= 0) return _DetailBody(activity: activity);
    final full = ref.watch(activityByIdProvider(activity.id));
    return full.when(
      loading: () => Scaffold(
        appBar: AppBar(
            title: Text(activity.name,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: const AppLoading(message: 'Memuat detail latihan...'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
            title: Text(activity.name,
                maxLines: 1, overflow: TextOverflow.ellipsis)),
        body: ResponsiveList(children: [
          AppError(
              error: e,
              onRetry: () =>
                  ref.invalidate(activityByIdProvider(activity.id))),
        ]),
      ),
      data: (a) => _DetailBody(activity: a ?? activity),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  final CyclingActivity activity;
  const _DetailBody({required this.activity});

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
              label: 'Bagikan GPX (${routePts.length} titik)',
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
    // Wajib tepat satu Kekuatan & satu Perhatian. Guard agar layar tak
    // pernah crash bila mesin evaluasi mengembalikan daftar kosong.
    final strength =
        ev.strengths.isNotEmpty ? ev.strengths.first : 'Sesi tercatat baik.';
    final attention = ev.gaps.isNotEmpty
        ? ev.gaps.first
        : 'Tidak ada catatan kritis pada sesi ini.';
    final color = ev.tone == SessionTone.good
        ? context.success
        : ev.tone == SessionTone.warn
            ? context.danger
            : context.infoColor;

    // --- GPS data untuk mini-chart (harus didefinisikan dulu sebelum dipakai) ---
    final routePts = decodeRoute(activity.routeJson);
    final hasGps = routePts.length >= 2;
    final elevSamples = hasGps ? elevationSamples(routePts) : <ElevSample>[];

    // --- Metrik sesi ---
    final distKm = activity.distance / 1000.0;
    final durMin = durationMinOf(activity);
    final speedKmh = activity.speedKmh;
    final hr = activity.averageHeartRate;
    final zone = hr > 0 ? hrZoneName(hr, prefs.maxHr) : '-';
    final trimp = trimpOf(activity, prefs.maxHr);
    final kcal = estimateCaloriesKcal(activity, prefs.weightKg);
    final tssSession = tssOfActivity(activity, others.isNotEmpty ? others : [activity]);
    final npKmh = an.normalizedPower > 0 ? an.normalizedPower * 3.6 : 0.0;
    final ifVal = an.intensityFactor;
    final viVal = an.variabilityIndex;
    final moveMin = hasGps ? (movingTimeSec(routePts) / 60.0) : 0.0;
    final gain = activity.totalElevationGain;

    // --- Rata-rata 7 & 30 hari untuk perbandingan ---
    final now = DateTime.now();
    int daysAgo(CyclingActivity a) {
      final d = parseActivityDate(a.startDate);
      if (d == null) return 999;
      return (now.millisecondsSinceEpoch - d.millisecondsSinceEpoch) ~/ (1000 * 60 * 60 * 24);
    }
    double avg7(String field) {
      final last7 = others.where((a) => daysAgo(a) <= 6).toList();
      if (last7.isEmpty) return 0;
      switch (field) {
        case 'tss': return last7.fold<double>(0, (s, a) => s + tssOfActivity(a, others)) / last7.length;
        case 'trimp': return last7.fold<double>(0, (s, a) => s + trimpOf(a, prefs.maxHr)) / last7.length;
        case 'dist': return last7.fold<double>(0, (s, a) => s + a.distance / 1000.0) / last7.length;
        case 'dur': return last7.fold<double>(0, (s, a) => s + durationMinOf(a)) / last7.length;
        case 'gain': return last7.fold<double>(0, (s, a) => s + a.totalElevationGain) / last7.length;
        case 'speed': return last7.fold<double>(0, (s, a) => s + a.speedKmh) / last7.length;
        default: return 0;
      }
    }
    double avg30(String field) {
      final last30 = others.where((a) => daysAgo(a) <= 29).toList();
      if (last30.isEmpty) return 0;
      switch (field) {
        case 'tss': return last30.fold<double>(0, (s, a) => s + tssOfActivity(a, others)) / last30.length;
        case 'trimp': return last30.fold<double>(0, (s, a) => s + trimpOf(a, prefs.maxHr)) / last30.length;
        case 'dist': return last30.fold<double>(0, (s, a) => s + a.distance / 1000.0) / last30.length;
        case 'dur': return last30.fold<double>(0, (s, a) => s + durationMinOf(a)) / last30.length;
        case 'gain': return last30.fold<double>(0, (s, a) => s + a.totalElevationGain) / last30.length;
        case 'speed': return last30.fold<double>(0, (s, a) => s + a.speedKmh) / last30.length;
        default: return 0;
      }
    }
    String pctDiff(double current, double avg) {
      if (avg <= 0) return '';
      final pct = ((current - avg) / avg * 100).round();
      return pct >= 0 ? ' (+$pct%)' : ' ($pct%)';
    }

    final hrZones = {'Z1': 0, 'Z2': 0, 'Z3': 0, 'Z4': 0, 'Z5': 0};
    if (hr > 0) {
      final z = hrZoneName(hr, prefs.maxHr);
      hrZones[z] = durMin.toInt();
    } else {
      // Estimasi berdasarkan kecepatan jika tidak ada HR
      hrZones['Z2'] = durMin.toInt();
    }

    // --- Nutrisi ---
    String nutritionAdvice() {
      if (tssSession >= 100) {
        return 'TSS $tssSession sangat besar: 1.2–1.5 g/kgBB karbo + 0.3–0.4 g/kgBB protein dalam 30 menit, lalu makan besar 2 jam kemudian. Elektrolit 500–750 mg natrium.';
      } else if (tssSession >= 80) {
        return 'TSS $tssSession besar: 1.0–1.2 g/kgBB karbo + 0.3 g/kgBB protein dalam 2 jam. Minum 500–750 ml elektrolit.';
      } else if (tssSession >= 50) {
        return 'TSS $tssSession sedang: 0.8–1.0 g/kgBB karbo + protein normal. Hidrasi 400–600 ml.';
      } else {
        return 'TSS $tssSession ringan: makan normal, minum sesuai dahaga.';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('Evaluasi Sesi')),
      body: ResponsiveList(
        children: [
          // ===== 1. METRIK UTAMA =====
          SectionTitle('Metrik Sesi'),
          AppStatsGrid(children: [
            _MetricTile('TSS', tssSession.toStringAsFixed(0), 'Training Stress Score', Icons.timer_outlined, pctDiff(tssSession, avg7('tss'))),
            _MetricTile('NP', npKmh > 0 ? '${npKmh.toStringAsFixed(1)} km/h' : '—', 'Normalized Power (estimasi)', Icons.speed_outlined, ''),
            _MetricTile('IF', ifVal > 0 ? ifVal.toStringAsFixed(2) : '—', 'Intensity Factor', Icons.bolt_outlined, ''),
            _MetricTile('VI', viVal > 0 ? viVal.toStringAsFixed(2) : '—', 'Variability Index', Icons.show_chart_outlined, ''),
            _MetricTile('Kalori', kcal > 0 ? '${kcal.toStringAsFixed(0)} kkal' : '—', 'Estimasi pembakaran', Icons.local_fire_department_outlined, ''),
            _MetricTile('Moving Time', moveMin > 0 ? '${moveMin.toStringAsFixed(0)} mnt' : '—', 'Waktu gerak (tanpa jeda)', Icons.directions_bike_outlined, ''),
            _MetricTile('TRIMP', trimp > 0 ? trimp.toStringAsFixed(0) : '—', 'Training Impulse (HR-based)', Icons.favorite_outline, pctDiff(trimp, avg7('trimp'))),
            _MetricTile('Elevasi', '${gain.toStringAsFixed(0)} m', 'Total kenaikan', Icons.terrain_outlined, pctDiff(gain, avg7('gain'))),
          ]),
          const SizedBox(height: AppSpacing.sm),

          // ===== 2. MINI CHARTS (jika GPS) =====
          if (hasGps && elevSamples.length >= 2) ...[
            SectionTitle('Profil Elevasi & Zona'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Elevasi', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ElevProfileChart(samples: elevSamples),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // ===== 3. ZONA HR BREAKDOWN =====
          SectionTitle('Distribusi Zona HR'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hr > 0)
                    Text('HR rata-rata: $hr bpm ($zone)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700))
                  else
                    Text('Tidak ada data HR — estimasi berdasarkan pace', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.warning)),
                  const SizedBox(height: 12),
                  _ZoneBar(zones: hrZones, totalMin: durMin, maxHr: prefs.maxHr),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ===== 4. PERBANDINGAN RATA-RATA =====
          SectionTitle('vs Rata-rata 7 / 30 Hari'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _ComparisonRow('TSS', tssSession.toStringAsFixed(0), avg7('tss').toStringAsFixed(0), avg30('tss').toStringAsFixed(0)),
                  _ComparisonRow('TRIMP', trimp.toStringAsFixed(0), avg7('trimp').toStringAsFixed(0), avg30('trimp').toStringAsFixed(0)),
                  _ComparisonRow('Jarak (km)', distKm.toStringAsFixed(1), avg7('dist').toStringAsFixed(1), avg30('dist').toStringAsFixed(1)),
                  _ComparisonRow('Durasi (mnt)', durMin.toStringAsFixed(0), avg7('dur').toStringAsFixed(0), avg30('dur').toStringAsFixed(0)),
                  _ComparisonRow('Kecepatan (km/j)', speedKmh.toStringAsFixed(1), avg7('speed').toStringAsFixed(1), avg30('speed').toStringAsFixed(1)),
                  _ComparisonRow('Elevasi (m)', gain.toStringAsFixed(0), avg7('gain').toStringAsFixed(0), avg30('gain').toStringAsFixed(0)),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ===== 5. KESIMPULAN UTAMA =====
          Card(
            color: color.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('KESIMPULAN UTAMA',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1)),
                  const SizedBox(height: 6),
                  Row(
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
                        child: Text(ev.verdict,
                            maxLines: 2,
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ===== 6. KEKUATAN =====
          SectionTitle('Kekuatan'),
          Card(
              child: ListTile(
                  leading:
                      Icon(Icons.check_circle_outline, color: context.success),
                  title:
                      Text(strength, maxLines: 4, overflow: TextOverflow.ellipsis))),
          const SizedBox(height: AppSpacing.sm),

          // ===== 7. PERHATIAN =====
          SectionTitle('Perhatian'),
          Card(
              child: ListTile(
                  leading: Icon(Icons.warning_amber_outlined,
                      color: context.warning),
                  title:
                      Text(attention, maxLines: 4, overflow: TextOverflow.ellipsis))),
          const SizedBox(height: AppSpacing.sm),

          // ===== 8. NUTRISI =====
          SectionTitle('Nutrisi & Recovery'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restaurant_outlined, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(nutritionAdvice())),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ===== 9. FOKUS BERIKUTNYA =====
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

/// Mini metric tile dengan perbandingan
class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final String diff;
  const _MetricTile(this.label, this.value, this.subtitle, this.icon, this.diff);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5))),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (diff.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('vs 7-hari$diff', style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: diff.contains('-') ? context.success : context.warning,
                fontWeight: FontWeight.w600,
              )),
            ] else ...[
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bar zona HR horizontal
class _ZoneBar extends StatelessWidget {
  final Map<String, int> zones;
  final double totalMin;
  final int maxHr;
  const _ZoneBar({required this.zones, required this.totalMin, required this.maxHr});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const order = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    final colors = {
      'Z1': Colors.blue,
      'Z2': Colors.green,
      'Z3': Colors.yellow[700]!,
      'Z4': Colors.orange,
      'Z5': Colors.red,
    };
    final total = zones.values.fold(0, (a, b) => a + b);
    if (total == 0) return const Text('Tidak ada data zona');
    return Column(
      children: order.map((z) {
        final min = zones[z] ?? 0;
        final pct = total > 0 ? min / total : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(width: 36, child: Text(z, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colors[z]!),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 55, child: Text('${pct > 0 ? '${(pct * 100).round()}%' : ''} ${min > 0 ? '${min}mnt' : ''}', textAlign: TextAlign.end, style: const TextStyle(fontSize: 11))),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Baris perbandingan
class _ComparisonRow extends StatelessWidget {
  final String label;
  final String current;
  final String avg7;
  final String avg30;
  const _ComparisonRow(this.label, this.current, this.avg7, this.avg30);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
          Expanded(child: Text(current, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: cs.primary))),
          Expanded(child: Text('7H: $avg7', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
          Expanded(child: Text('30H: $avg30', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}
