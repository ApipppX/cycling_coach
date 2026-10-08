import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/geo_utils.dart';
import '../theme/app_theme.dart';

/// Grafik profil elevasi ala Strava: garis + area, sumbu X jarak (km),
/// label min/max. Mengembalikan placeholder bila tak ada data elevasi
/// (mis. rekaman browser yang altitudenya 0 semua).
class ElevProfileChart extends StatelessWidget {
  final List<ElevSample> samples;
  const ElevProfileChart({super.key, required this.samples});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (samples.length < 2) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.terrain_outlined,
              size: 32, color: cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text('Tanpa data elevasi',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700)),
          Text('GPS tidak memberi altitude pada sesi ini',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant)),
        ]),
      );
    }
    final eles = samples.map((s) => s.eleM).toList();
    var minE = eles.reduce((a, b) => a < b ? a : b);
    var maxE = eles.reduce((a, b) => a > b ? a : b);
    if ((maxE - minE).abs() < 5) {
      // Rute datar: beri ruang visual agar garis tak menempel tepi.
      minE -= 5;
      maxE += 5;
    }
    final totalKm = samples.last.distKm;
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('Profil Elevasi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                ),
                Chip(
                  label: Text(
                      '↗ ${maxE.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                Chip(
                  label: Text('↘ ${minE.toStringAsFixed(0)} m',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                  visualDensity: VisualDensity.compact,
                ),
              ]),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 170,
                child: LineChart(
                  LineChartData(
                    minY: minE,
                    maxY: maxE,
                    gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                            color: cs.outlineVariant
                                .withValues(alpha: 0.4),
                            strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval:
                              ((maxE - minE) / 3).clamp(1, 1e9),
                          getTitlesWidget: (v, _) => Text(
                            v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 24,
                          interval: (totalKm / 4).clamp(0.5, 1e9),
                          getTitlesWidget: (v, _) => Text(
                            v.toStringAsFixed(v >= 10 ? 0 : 1),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                'km ${s.x.toStringAsFixed(1)}\n${s.y.toStringAsFixed(0)} m',
                                const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)))
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (final s in samples)
                            FlSpot(s.distKm, s.eleM),
                        ],
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: cs.tertiary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color:
                              cs.tertiary.withValues(alpha: 0.22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Text('Jarak (km) • Elevasi (m)',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}
