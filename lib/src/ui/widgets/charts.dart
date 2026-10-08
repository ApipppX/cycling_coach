import 'package:flutter/material.dart';
import '../../core/coach_engine.dart';

class KmBarChart extends StatelessWidget {
  final List<PeriodStat> periods;
  const KmBarChart({super.key, required this.periods});
  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();
    final maxV = periods.map((e) => e.km).fold<double>(1, (a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 210,
      child: CustomPaint(
          painter: _BarPainter(periods, maxV, scheme,
              scheme.onSurfaceVariant)),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<PeriodStat> periods;
  final double maxV;
  final ColorScheme scheme;
  final Color labelColor;
  _BarPainter(this.periods, this.maxV, this.scheme, this.labelColor);
  @override
  void paint(Canvas canvas, Size size) {
    const padT = 26.0, padB = 34.0;
    final ch = size.height - padT - padB;
    final n = periods.length;
    const gap = 8.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final paintMax = Paint()..color = scheme.primary;
    final paintDim = Paint()..color = scheme.primaryContainer;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n; i++) {
      final p = periods[i];
      final frac = (p.km / maxV).clamp(0.0, 1.0);
      final bh = (ch * frac).clamp(p.km > 0 ? 8.0 : 2.0, ch);
      final x = i * (barW + gap);
      final y = padT + ch - bh;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barW, bh), const Radius.circular(8)),
        p.km >= maxV - 0.001 && p.km > 0 ? paintMax : paintDim,
      );
      tp.text = TextSpan(text: p.km > 0 ? p.km.toStringAsFixed(0) : '', style: TextStyle(fontSize: 10, color: labelColor));
      tp.layout();
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, y - 16));
      tp.text = TextSpan(text: p.label, style: TextStyle(fontSize: 10, color: labelColor));
      tp.layout();
      tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, padT + ch + 6));
    }
  }
  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.periods != periods || old.labelColor != labelColor;
}

class KmLineChart extends StatelessWidget {
  final List<double> kmPerRide;
  const KmLineChart({super.key, required this.kmPerRide});
  @override
  Widget build(BuildContext context) {
    final points = kmPerRide.length > 8 ? kmPerRide.sublist(kmPerRide.length - 8) : kmPerRide;
    if (points.length < 2) return const SizedBox.shrink();
    return SizedBox(height: 190, child: CustomPaint(painter: _LinePainter(points, Theme.of(context).colorScheme)));
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final ColorScheme scheme;
  _LinePainter(this.points, this.scheme);
  @override
  void paint(Canvas canvas, Size size) {
    final maxV = points.reduce((a, b) => a > b ? a : b) * 1.15;
    const padT = 20.0, padB = 30.0, padL = 10.0;
    final cw = size.width - padL - 10, ch = size.height - padT - padB;
    Offset px(int i) {
      final x = padL + cw * (i / (points.length - 1));
      final y = padT + ch - ch * (points[i] / maxV);
      return Offset(x, y);
    }
    final line = Paint()..color = scheme.primary..strokeWidth = 4..style = PaintingStyle.stroke;
    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(px(i), px(i + 1), line);
    }
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(px(i), 6, Paint()..color = scheme.tertiary);
    }
  }
  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}

/// Distribusi sesi per zona HR (Z1–Z5) sebagai bar horizontal.
/// Grid rapi: label 36px kiri, bar fleksibel, nilai 64px kanan tabular.
class ZoneDistribution extends StatelessWidget {
  final Map<String, int> zones;
  const ZoneDistribution({super.key, required this.zones});

  @override
  Widget build(BuildContext context) {
    const order = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'];
    final maxV = order
        .map((z) => zones[z] ?? 0)
        .fold<int>(1, (a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final z in order)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 32, maxWidth: 44),
                  child: Text(z,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (zones[z] ?? 0) / maxV,
                    minHeight: 16,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: z == 'Z5'
                        ? Colors.red
                        : z == 'Z4'
                            ? Colors.orange
                            : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 56, maxWidth: 80),
                  child: Text('${zones[z] ?? 0} sesi',
                      textAlign: TextAlign.end,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12))),
            ]),
          ),
      ],
    );
  }
}
