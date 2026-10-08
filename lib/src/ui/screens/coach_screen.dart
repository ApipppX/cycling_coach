import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/coach_engine.dart';
import '../../core/health_stats.dart';
import '../../core/report_pdf.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../theme/app_theme.dart';

class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actsAsync = ref.watch(activitiesProvider);
    if (actsAsync.isLoading && !actsAsync.hasValue) {
      return Scaffold(
        appBar: AppBar(title: Text('Coach AI')),
        body: AppLoading(message: 'Menganalisis beban latihan...'),
      );
    }
    final acts = actsAsync.value ?? [];
    final prefs = ref.watch(prefsProvider);
    final events = ref.watch(eventsProvider).value ?? [];
    final event = events.isEmpty ? null : events.first;
    final analysis = ref.watch(coachAnalysisProvider);
    final today = todayString();
    final last7 =
        acts.where((a) => a.dateKey.compareTo(weekStartMonday(0)) >= 0 && a.dateKey.compareTo(today) <= 0).toList();
    final kcal7 = totalCaloriesKcal(last7, prefs.weightKg);
    MapEntry<String, double>? topZone;
    for (final e in analysis.hrZoneMinutes.entries) {
      if ((topZone == null || e.value > topZone.value) && e.value > 0) {
        topZone = e;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text('Coach AI')),
      body: ResponsiveList(children: [
        Card(
          color: analysis.todayType == PlanType.rest
              ? Theme.of(context).colorScheme.secondaryContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SESI LATIHAN BERIKUTNYA',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall),
                    const SizedBox(height: 4),
                    Text(analysis.todayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(analysis.todayDetail,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                        'Berdasarkan "${analysis.latestName}" (${analysis.latestDate}) — lakukan sebagai latihan berikutnya setelah recovery cukup, bukan keharusan hari ini.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          Chip(
              avatar: const Icon(Icons.route, size: 16),
              label: Text('Total ${analysis.totalKm.toStringAsFixed(0)} km')),
          Chip(
              avatar: const Icon(Icons.speed, size: 16),
              label:
                  Text('Avg ${analysis.avgSpeedKmh.toStringAsFixed(1)} km/h')),
          Chip(
              avatar: const Icon(Icons.favorite, size: 16),
              label: Text(analysis.avgHr > 0
                  ? 'HR ${analysis.avgHr.toInt()} bpm'
                  : 'HR -')),
          Chip(
              avatar: Icon(
                  analysis.freshnessLabel.contains('Segar')
                      ? Icons.battery_full
                      : analysis.freshnessLabel.contains('Risiko')
                          ? Icons.warning
                          : Icons.battery_std,
                  size: 16),
              label: Text(analysis.freshnessLabel)),
          Chip(
              avatar: const Icon(Icons.local_fire_department, size: 16),
              label: Text('7 hari: ${kcal7.toStringAsFixed(0)} kkal')),
        ]),
        const SizedBox(height: AppSpacing.md),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Kenapa sesi ini?'),
                      Text(analysis.recoveryReason),
                      const SizedBox(height: AppSpacing.sm),
                      const _Label('Kondisi tubuh'),
                      Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                        Chip(
                            avatar: const Icon(Icons.fitness_center,
                                size: 16),
                            label: Text(
                                'CTL ${analysis.ctl.toStringAsFixed(0)}')),
                        Chip(
                            avatar: const Icon(Icons.speed, size: 16),
                            label: Text(
                                'ATL ${analysis.atl.toStringAsFixed(0)}')),
                        Chip(
                            avatar: const Icon(Icons.battery_charging_full,
                                size: 16),
                            label: Text(
                                'TSB ${analysis.tsb.toStringAsFixed(0)}')),
                      ]),
                      const SizedBox(height: AppSpacing.xs),
                      Text('(${analysis.freshnessLabel})',
                          style:
                              Theme.of(context).textTheme.bodySmall),
                      Text(
                          'TRIMP 7 hari: ${analysis.trimp7.toStringAsFixed(0)} • Elevasi total: ${fmtInt(analysis.totalElevationM.toInt())} m',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.sm),
                      const _Label('Struktur minggu'),
                      Text('Mix 7 hari: ${analysis.weekMix}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text('Plan: ${analysis.weekPlan}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: AppSpacing.sm),
                      Text(analysis.confidence,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontStyle: FontStyle.italic)),
                      if (topZone != null)
                        Text(
                            'Zona dominan: ${topZone.key} (${topZone.value.toStringAsFixed(0)} mnt) — ${hrZoneDesc(topZone.key)}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                    ]))),
        if (analysis.warnings.isNotEmpty)
          const SectionTitle('Perlu perhatian'),
        ...analysis.warnings.map((w) => Card(
            child: ListTile(
                leading:
                    Icon(Icons.warning_amber_rounded, color: context.warning),
                title: Text(w,
                    maxLines: 3, overflow: TextOverflow.ellipsis)))),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          icon: Icons.share_outlined,
          label: 'Bagikan Laporan PDF',
          onPressed: () async {
            final f = await buildWeeklyReportPdf(
                prefs.userName,
                acts,
                prefs.weeklyTargetKm,
                prefs.maxHr,
                prefs.weightKg,
                event);
            await SharePlus.instance.share(ShareParams(
                files: [XFile(f.path)],
                subject: 'Laporan Mingguan'));
          },
        ),
      ]),
    );
  }
}

/// Label seksi kecil (KENAPA SESI INI? / KONDISI TUBUH / STRUKTUR MINGGU).
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800, letterSpacing: 1.1)),
    );
  }
}
