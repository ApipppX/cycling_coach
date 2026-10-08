import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../providers/providers.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../theme/app_theme.dart';
import 'eta_predictor_screen.dart';

class EventScreen extends ConsumerStatefulWidget {
  const EventScreen({super.key});
  @override
  ConsumerState<EventScreen> createState() => _EventState();
}

class _EventState extends ConsumerState<EventScreen> {
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final actsAsync = ref.watch(activitiesProvider);
    final checksAsync = ref.watch(planChecksProvider);
    if ((eventsAsync.isLoading && !eventsAsync.hasValue) ||
        (actsAsync.isLoading && !actsAsync.hasValue)) {
      return Scaffold(
        appBar: AppBar(title: Text('Event')),
        body: AppLoading(message: 'Memuat plan event...'),
      );
    }
    final events = eventsAsync.value ?? [];
    final acts = actsAsync.value ?? [];
    final checks = checksAsync.value ?? {};
    final ev = events.isEmpty ? null : events.first;
    final plan = ev == null ? <TrainingDay>[] : generateEventPlan(ev, acts);
    final doneCount =
        plan.where((d) => planDayDone(d, acts, checks)).length;
    final planProgress =
        plan.isEmpty ? 0.0 : (doneCount / plan.length).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: Text('Event')),
      floatingActionButton: FloatingActionButton(
          heroTag: 'event_fab',
          tooltip: 'Tambah event',
          onPressed: _eventForm,
          child: const Icon(Icons.add)),
      body: ResponsiveList(children: [
        if (ev == null)
          EmptyState(
            icon: Icons.flag_outlined,
            title: 'Belum ada event.',
            subtitle:
                'Tambahkan target event untuk dapat plan latihan + kalkulator ETA.',
            actionLabel: 'Tambah event',
            onAction: _eventForm,
          )
        else ...[
          _EventHeaderCard(
              ev: ev,
              onDelete: () =>
                  ref.read(dbProvider).deleteEvent(ev)),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final readiness = Builder(builder: (_) {
              final an = ref.watch(coachAnalysisProvider);
              final r = eventReadiness(ev, acts, an.ctl, an.weekKm);
              return _ReadinessCard(
                  pct: r.pct, verdict: r.verdict);
            });
            final progress = _PlanProgressCard(
                done: doneCount, total: plan.length, value: planProgress);
            if (!wide) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  readiness,
                  const SizedBox(height: AppSpacing.md),
                  if (plan.isNotEmpty) ...[
                    progress,
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              );
            }
            // Tablet/desktop: dua kartu ringkasan berdampingan.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: readiness),
                const SizedBox(width: AppSpacing.md),
                if (plan.isNotEmpty) Expanded(child: progress),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.speed_outlined, size: 18),
              label: const Text('Kalkulator ETA Anti-COT'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => EtaPredictorScreen(event: ev))),
            ),
          ),
          if (plan.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            SectionTitle('Jadwal latihan (${plan.length} hari)',
                action: Text('$doneCount selesai',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700))),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth >= 600;
              if (!wide) {
                // HP: satu kolom dengan jarak lega 12px.
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final d in plan) ...[
                      _PlanDayTile(
                        d: d,
                        done: planDayDone(d, acts, checks),
                        enabled: isPastOrToday(d.date) ||
                            checks.contains(d.date),
                        onChanged: (v) => ref
                            .read(dbProvider)
                            .togglePlanDay(d.date, v ?? false),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                );
              }
              // Tablet/desktop: grid 2 kolom lega.
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisExtent: 92,
                ),
                itemCount: plan.length,
                itemBuilder: (_, i) {
                  final d = plan[i];
                  return _PlanDayTile(
                    d: d,
                    done: planDayDone(d, acts, checks),
                    enabled: isPastOrToday(d.date) ||
                        checks.contains(d.date),
                    onChanged: (v) => ref
                        .read(dbProvider)
                        .togglePlanDay(d.date, v ?? false),
                  );
                },
              );
            }),
          ],
          // Ruang bawah agar FAB tidak menutupi item terakhir.
          const SizedBox(height: 88),
        ],
      ]),
    );
  }

  void _eventForm() {
    final nameC = TextEditingController();
    final dateC = TextEditingController(
        text: DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String()
            .substring(0, 10));
    final distC = TextEditingController(text: '100');
    final elevC = TextEditingController(text: '0');
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Target Event'),
              content: SizedBox(
                width: context.isCompact
                    ? double.maxFinite
                    : 400,
                child: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min, children: [
                AppTextField(
                    controller: nameC,
                    label: 'Nama event',
                    hint: 'cth Audax 100K',
                    icon: Icons.flag_outlined),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                    controller: dateC,
                    label: 'Tanggal (yyyy-MM-dd)',
                    hint: '2026-12-01',
                    icon: Icons.calendar_today_outlined),
                const SizedBox(height: AppSpacing.md),
                ResponsiveTwoColumn(
                  first: AppTextField(
                      controller: distC,
                      label: 'Jarak (km)',
                      hint: '100',
                      icon: Icons.route_outlined,
                      suffix: 'km',
                      keyboardType: TextInputType.number),
                  second: AppTextField(
                      controller: elevC,
                      label: 'Elevasi (m)',
                      hint: '0',
                      icon: Icons.terrain_outlined,
                      suffix: 'm',
                      keyboardType: TextInputType.number),
                ),
                  ]),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      final dist =
                          double.tryParse(distC.text) ?? 100;
                      if (dist <= 0 || dist > 1000) return;
                      ref.read(dbProvider).saveSingleEvent(EventGoal(
                            name: nameC.text.trim().isEmpty
                                ? 'Event'
                                : nameC.text.trim(),
                            eventDate: dateC.text.trim(),
                            targetDistanceKm: dist,
                            targetElevationM:
                                double.tryParse(elevC.text) ?? 0,
                            createdAt: DateTime.now()
                                .millisecondsSinceEpoch,
                          ));
                      Navigator.pop(context);
                    },
                    child: const Text('Simpan')),
              ],
            ));
  }
}

/// Kartu identitas event: avatar flag + nama + meta + hapus.
class _EventHeaderCard extends StatelessWidget {
  final EventGoal ev;
  final VoidCallback onDelete;
  const _EventHeaderCard({required this.ev, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: AppSizes.avatarSm,
              height: AppSizes.avatarSm,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.flag_outlined,
                  color: scheme.onPrimaryContainer, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ev.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                      '${ev.eventDate} • ${ev.targetDistanceKm.toInt()} km • H-${daysUntil(ev.eventDate)}${ev.targetElevationM > 0 ? ' • ${ev.targetElevationM.toInt()} m elev' : ''}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
                icon: Icon(Icons.delete_outline,
                    color: context.danger),
                tooltip: 'Hapus event',
                onPressed: () async {
                  final ok = await showAppConfirm(context,
                      title: 'Hapus event?',
                      message:
                          '"${ev.name}" dan plan latihannya akan dihapus.');
                  if (ok) onDelete();
                }),
          ],
        ),
      ),
    );
  }
}

/// Kartu kesiapan: persen + badge + progress + verdict.
class _ReadinessCard extends StatelessWidget {
  final int pct;
  final String verdict;
  const _ReadinessCard({required this.pct, required this.verdict});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Kesiapan: $pct%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text('$pct%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ])),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  LinearProgressIndicator(
                      value: pct / 100, minHeight: 8),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(verdict,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodyMedium),
                ])));
  }
}

/// Kartu progres plan: hitungan + progress.
class _PlanProgressCard extends StatelessWidget {
  final int done;
  final int total;
  final double value;
  const _PlanProgressCard(
      {required this.done, required this.total, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progres plan: $done/$total hari',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm + 2),
                  LinearProgressIndicator(
                      value: value, minHeight: 8),
                ])));
  }
}

/// Satu hari plan: avatar huruf + judul + catatan + checkbox 44px.
/// Kartu min-height 76 agar tidak rapat & mudah disentuh.
class _PlanDayTile extends StatelessWidget {
  final TrainingDay d;
  final bool done;
  final bool enabled;
  final ValueChanged<bool?> onChanged;
  const _PlanDayTile(
      {required this.d,
      required this.done,
      required this.enabled,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: enabled ? () => onChanged(!done) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  Container(
                    width: AppSizes.avatarSm,
                    height: AppSizes.avatarSm,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: done
                          ? context.success.withValues(alpha: 0.15)
                          : scheme.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      planTypeLabel(d.type).substring(0, 1),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: done
                              ? context.success
                              : scheme.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            '${d.dayLabel} • ${planTypeLabel(d.type)}${d.distanceKm > 0 ? ' • ${d.distanceKm.toStringAsFixed(0)} km' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    decoration: done
                                        ? TextDecoration.lineThrough
                                        : null)),
                        const SizedBox(height: 2),
                        Text(d.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: AppSizes.touchMin,
                    height: AppSizes.touchMin,
                    child: Checkbox(
                      value: done,
                      onChanged:
                          enabled ? onChanged : null,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
