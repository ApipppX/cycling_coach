import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Avatar zona HR: Z1–Z5 dengan warna khas agar terbaca sekilas.
/// Z5 merah, Z4 orange, Z3 biru, Z2 hijau, tanpa HR = inisial nama.
class ZoneAvatar extends StatelessWidget {
  final String zone;
  final String fallbackLetter;

  const ZoneAvatar(
      {super.key, required this.zone, required this.fallbackLetter});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (zone.isEmpty) {
      return CircleAvatar(
        child: Text(fallbackLetter.isEmpty
            ? 'C'
            : fallbackLetter[0].toUpperCase()),
      );
    }
    final color = AppColors.zoneColor(zone, cs);
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(zone,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: color)),
    );
  }
}

/// Chip kecil zona untuk dipakai di detail / evaluasi sesi.
class ZoneChip extends StatelessWidget {
  final String zone;
  const ZoneChip({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = AppColors.zoneColor(zone, cs);
    return Chip(
      label: Text(zone),
      labelStyle: TextStyle(
          color: color, fontWeight: FontWeight.w800, fontSize: 11),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
