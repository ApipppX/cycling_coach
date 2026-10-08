import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../core/health_stats.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../widgets/activity_form.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../theme/app_theme.dart';

class DetailScreen extends ConsumerWidget {
  final CyclingActivity activity;
  const DetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(prefsProvider);
    final kcal = estimateCaloriesKcal(activity, prefs.weightKg);
    final trimp = trimpOf(activity, prefs.maxHr);
    final zone = hrZoneName(activity.averageHeartRate, prefs.maxHr);
    final rows = <List<String>>[
      ['Tanggal', formatDateShort(activity.startDate)],
      ['Jarak', '${activity.distanceKm.toStringAsFixed(2)} km'],
      [
        'Durasi',
        activity.durationMin > 0
            ? '${activity.durationMin.toStringAsFixed(0)} mnt'
            : '-'
      ],
      ['Kecepatan', '${activity.speedKmh.toStringAsFixed(1)} km/h'],
      ['Elevasi', '${activity.totalElevationGain.toInt()} m'],
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
