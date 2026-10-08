import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/coach_engine.dart';
import '../theme/app_theme.dart';

/// Grafik batang performa mingguan (fl_chart).
/// Dibungkus RepaintBoundary agar scroll 60fps, animasi fade-in halus.
class PerfChart extends StatelessWidget {
  final List<PeriodStat> periods;
  final String title;

  const PerfChart(
      {super.key, required this.periods, this.title = ''});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (periods.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title.isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              LayoutBuilder(builder: (context, constraints) {
                // Lebar bar mengikuti ruang: tidak terlalu kurus di desktop,
                // tidak overflow di HP sempit.
                final n = periods.isEmpty ? 1 : periods.length;
                final barW = (constraints.maxWidth / n * 0.55)
                    .clamp(10.0, 28.0);
                // Di layar sangat sempit, izinkan scroll horizontal agar
                // label tidak bertumpuk.
                final needScroll = constraints.maxWidth < n * 44.0;
                final chart = SizedBox(
                  height: 200,
                  width: needScroll ? n * 44.0 : null,
                  child: BarChart(
                    BarChartData(
                      gridData:
                          const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (v, _) {
                              final i = v.toInt();
                              if (i < 0 ||
                                  i >= periods.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Text(
                                  periods[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles:
                                SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipItem:
                              (group, groupIndex, rod, rodIndex) =>
                                  BarTooltipItem(
                            '${periods[group.x].km.toStringAsFixed(0)} km\n${periods[group.x].rides} sesi',
                            const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0;
                            i < periods.length;
                            i++)
                          BarChartGroupData(
                            x: i,
                            barRods: [
                              BarChartRodData(
                                toY: periods[i].km,
                                width: barW,
                                borderRadius:
                                    BorderRadius.circular(6),
                                color: i ==
                                        periods.length - 1
                                    ? cs.primary
                                    : cs.primary.withValues(
                                        alpha: 0.35),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
                if (!needScroll) return chart;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: chart,
                );
              }),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}

/// Grafik garis tren per sesi (fl_chart) — 8 sesi terakhir kronologis.
class TrendLineChart extends StatelessWidget {
  final List<double> kmPerRide;
  const TrendLineChart({super.key, required this.kmPerRide});

  @override
  Widget build(BuildContext context) {
    final points = kmPerRide.length > 8
        ? kmPerRide.sublist(kmPerRide.length - 8)
        : kmPerRide;
    if (points.length < 2) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(
                            color: cs.outlineVariant
                                .withValues(alpha: 0.4),
                            strokeWidth: 1)),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0;
                          i < points.length;
                          i++)
                        FlSpot(
                            i.toDouble(), points[i]),
                    ],
                    isCurved: true,
                    color: cs.primary,
                    barWidth: 4,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter:
                            (spot, percent, bar, index) =>
                                FlDotCirclePainter(
                          radius: 4,
                          color: cs.tertiary,
                          strokeWidth: 0,
                        )),
                    belowBarData: BarAreaData(
                      show: true,
                      color: cs.primary
                          .withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 350.ms),
    );
  }
}
