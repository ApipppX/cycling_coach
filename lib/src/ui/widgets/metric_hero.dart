import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Kartu hero angka mingguan ala Strava: label kecil abu + angka besar
/// tabular + progress oranye + insight ringkas.
class MetricHero extends StatelessWidget {
  final double weekKm;
  final double targetKm;
  final int sessions;
  final String insight;
  final String subInsight;

  const MetricHero({
    super.key,
    required this.weekKm,
    required this.targetKm,
    required this.sessions,
    required this.insight,
    required this.subInsight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress =
        (weekKm / (targetKm <= 0 ? 1 : targetKm)).clamp(0.0, 1.0);
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TARGET MINGGUAN • SENIN–MINGGU',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${weekKm.toStringAsFixed(1)} / ${targetKm.toStringAsFixed(0)} km',
                maxLines: 1,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) =>
                  LinearProgressIndicator(value: v, minHeight: 8),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('$sessions sesi minggu ini',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(insight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium),
            Text(subInsight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
        begin: 0.08, end: 0, curve: Curves.easeOutCubic);
  }
}
