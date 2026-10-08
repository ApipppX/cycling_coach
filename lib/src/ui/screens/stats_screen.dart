import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/coach_engine.dart';
import '../../core/health_stats.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/perf_chart.dart';
import '../widgets/responsive.dart';
import '../theme/app_theme.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actsAsync = ref.watch(activitiesProvider);
    if (actsAsync.isLoading && !actsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text('Statistik')),
        body: AppLoading(message: 'Menghitung statistik...'),
      );
    }
    final acts = actsAsync.value ?? [];
    final prefs = ref.watch(prefsProvider);
    final weeks = statsLastWeeks(acts);
    final months = statsLastMonths(acts);
    final years = statsLastYears(acts);
    final rec = computeRecords(acts);
    final totals = lifetimeTotals(acts, prefs.weightKg);
    final analysis = ref.watch(coachAnalysisProvider);
    final avgSpd =
        totals.minutes > 0 ? totals.km / (totals.minutes / 60) : 0.0;
    return Scaffold(
      appBar: AppBar(title: Text('Statistik')),
      body: ResponsiveList(children: [
        // Ringkasan tanpa kartu pembungkus — tiap tile adalah kartu
        // sendiri agar tidak terlihat menempel (nested card).
        SectionTitle('Total Keseluruhan',
            action: Text('${totals.rides} sesi',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w700))),
        AppStatsGrid(
            columns: 3,
            spacing: AppSpacing.md,
            children: [
              StatTile(totals.km.toStringAsFixed(0), 'km',
                  icon: Icons.route_outlined),
              StatTile('${totals.rides}', 'sesi',
                  icon: Icons.directions_bike_outlined),
              StatTile(fmtInt(totals.elevM.toInt()), 'm elev',
                  icon: Icons.terrain_outlined),
              StatTile((totals.minutes / 60).toStringAsFixed(1),
                  'jam',
                  icon: Icons.timer_outlined),
              StatTile(fmtInt(totals.kcal.toInt()), 'kkal',
                  icon: Icons.local_fire_department_outlined),
              StatTile(
                  avgSpd > 0 ? avgSpd.toStringAsFixed(1) : '-',
                  'avg km/h',
                  icon: Icons.speed_outlined),
            ]),
        const SectionTitle('8 Minggu Terakhir'),
        PerfChart(periods: weeks),
        const SizedBox(height: AppSpacing.md),
        _periodTable(weeks),
        const SectionTitle('6 Bulan Terakhir'),
        PerfChart(periods: months),
        const SizedBox(height: AppSpacing.md),
        _periodTable(months),
        const SectionTitle('3 Tahun Terakhir'),
        PerfChart(periods: years),
        const SizedBox(height: AppSpacing.md),
        _periodTable(years),
        const SectionTitle('Tren per Sesi (8 terakhir, kronologis)'),
        Builder(builder: (_) {
          final byDate = List.of(acts)
            ..sort((a, b) => a.startDate.compareTo(b.startDate));
          final km = byDate.map((a) => a.distanceKm).toList();
          if (km.length < 2) {
            return Card(
                child: Padding(
                    padding:
                        const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                        'Butuh minimal 2 sesi untuk melihat tren.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)));
          }
          return TrendLineChart(kmPerRide: km);
        }),
        const SizedBox(height: AppSpacing.md),
        const SectionTitle('Distribusi Zona HR'),
        Card(
            child: Padding(
                padding:
                    const EdgeInsets.all(AppSpacing.lg),
                child: ZoneDistribution(zones: analysis.hrZones))),
        if (rec != null) ...[
          const SectionTitle('Rekor & Streak'),
          AppStatsGrid(
              columns: 2,
              spacing: AppSpacing.md,
              children: [
                StatTile(
                    '${rec.longestKm.toStringAsFixed(1)} km',
                    'Terjauh',
                    icon: Icons.route_outlined,
                    sub: rec.longestName),
                StatTile(
                    '${rec.fastestKmh.toStringAsFixed(1)} km/h',
                    'Tercepat',
                    icon: Icons.speed_outlined,
                    sub: rec.fastestName),
                StatTile('${fmtInt(rec.maxElevM.toInt())} m',
                    'Tanjakan',
                    icon: Icons.terrain_outlined,
                    sub: rec.maxElevName),
                StatTile('${computeWeekStreak(acts)} mgg',
                    'Streak',
                    icon: Icons.local_fire_department_outlined,
                    sub: '${rec.totalRides} sesi'),
              ]),
        ],
        const SizedBox(height: AppSpacing.xl),
      ]),
    );
  }

  Widget _periodTable(List<PeriodStat> periods) {
    final shown = periods.length > 4
        ? periods.sublist(periods.length - 4)
        : periods;
    return ScrollTable(
      headers: const ['Periode', 'Jarak', 'Sesi', 'Waktu'],
      flexes: const [3, 2, 1, 2],
      aligns: const [0, 2, 1, 2],
      rows: [
        for (final p in shown)
          [
            Text(p.label),
            Text('${p.km.toStringAsFixed(1)} km'),
            Text('${p.rides}'),
            Text('${p.minutes.toStringAsFixed(0)} mnt'),
          ],
      ],
    );
  }
}
