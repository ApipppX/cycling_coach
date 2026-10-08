import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../core/coach_engine.dart';
import '../../providers/providers.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'responsive.dart';

final _ymd = DateFormat('yyyy-MM-dd', 'en_US');

double? _pos(String s) {
  final v = double.tryParse(s.replaceAll(',', '.'));
  return (v == null || v <= 0) ? null : v;
}

/// Dialog tambah/edit latihan. Mengembalikan aktivitas tersimpan, atau null
/// jika dibatalkan.
///
/// Jarak, durasi, dan kecepatan saling melengkapi dengan pola yang konsisten:
/// mengetik TIDAK pernah menimpa field lain (hanya preview yang update),
/// nilai otomatis diisi saat selesai edit (tombol done / pindah field)
/// dan saat disimpan. Cukup isi 2 dari 3.
Future<CyclingActivity?> showActivityForm(
    BuildContext context, WidgetRef ref, CyclingActivity? initial) {
  final nameC = TextEditingController(text: initial?.name ?? '');
  final distC = TextEditingController(
      text: initial == null ? '' : initial.distanceKm.toStringAsFixed(2));
  final durC = TextEditingController(
      text: initial == null || initial.durationMin <= 0
          ? ''
          : initial.durationMin.toStringAsFixed(0));
  final speedC = TextEditingController(
      text: initial == null ? '' : initial.speedKmh.toStringAsFixed(1));
  final elevC = TextEditingController(
      text: initial == null ? '' : initial.totalElevationGain.toStringAsFixed(0));
  final hrC = TextEditingController(
      text: initial == null || initial.averageHeartRate <= 0
          ? ''
          : initial.averageHeartRate.toInt().toString());
  final noteC = TextEditingController(text: initial?.note ?? '');
  var date = parseActivityDate(initial?.startDate ?? '') ?? DateTime.now();
  final errors = <String, String?>{};

  /// Hitung nilai yang hilang dari dua nilai yang ada.
  /// Mengembalikan (distKm, durMin, speedKmh) yang konsisten.
  (double, double, double)? infer() {
    final d = _pos(distC.text);
    final dur = _pos(durC.text);
    final sp = _pos(speedC.text);
    if (d != null && dur != null) return (d, dur, d / (dur / 60.0));
    if (d != null && sp != null) return (d, d / sp * 60.0, sp);
    if (dur != null && sp != null) return (sp * (dur / 60.0), dur, sp);
    return null;
  }

  /// Tulis hasil inferensi ke field yang masih kosong (dipanggil saat selesai
  /// edit atau sebelum simpan — tidak pernah saat mengetik).
  void fillMissing() {
    final r = infer();
    if (r == null) return;
    if (_pos(distC.text) == null) distC.text = r.$1.toStringAsFixed(2);
    if (_pos(durC.text) == null) durC.text = r.$2.toStringAsFixed(0);
    if (_pos(speedC.text) == null) speedC.text = r.$3.toStringAsFixed(1);
  }

  bool validate() {
    errors.clear();
    if (nameC.text.trim().isEmpty) errors['name'] = 'Nama wajib diisi';
    final r = infer();
    if (r == null) {
      errors['dist'] = 'Isi minimal 2 dari: jarak, durasi, kecepatan';
    } else {
      if (r.$1 > 500) errors['dist'] = 'Jarak maksimal 500 km';
      if (r.$2 > 1440) errors['dur'] = 'Durasi maksimal 24 jam';
      if (r.$3 > 60) errors['speed'] = 'Kecepatan maksimal 60 km/h';
    }
    final elev = elevC.text.trim().isEmpty
        ? 0.0
        : double.tryParse(elevC.text.replaceAll(',', '.'));
    if (elev == null || elev < 0 || elev > 10000) {
      errors['elev'] = 'Elevasi harus 0–10000 m';
    }
    final hr = hrC.text.trim().isEmpty
        ? 0.0
        : double.tryParse(hrC.text.replaceAll(',', '.'));
    if (hr == null || hr < 0 || (hr > 0 && hr < 40) || hr > 220) {
      errors['hr'] = 'HR harus 40–220 bpm (atau kosong)';
    }
    return errors.isEmpty;
  }

  return showDialog<CyclingActivity>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
        title: Text(initial == null ? 'Tambah Latihan' : 'Edit Latihan',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        contentPadding:
            const EdgeInsets.fromLTRB(24, 16, 24, 0),
        content: SizedBox(
          // Dialog responsif: penuh di HP, max 440 di tablet/desktop.
          width: ctx.isCompact ? double.maxFinite : 440,
          child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTextField(
              controller: nameC,
              label: 'Nama',
              hint: 'cth Gowes Pagi',
              icon: Icons.directions_bike_outlined,
              errorText: errors['name'],
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(prettyDay(date),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: const Text('Tanggal latihan',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: TextButton(
                child: const Text('Ubah'),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (picked != null) setState(() => date = picked);
                },
              ),
            ),
            AppTextField(
              controller: distC,
              label: 'Jarak',
              hint: 'cth 25.5',
              icon: Icons.route_outlined,
              suffix: 'km',
              errorText: errors['dist'],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              onEditingComplete: () => setState(() => fillMissing()),
            ),
            const SizedBox(height: AppSpacing.md),
            ResponsiveTwoColumn(
              first: AppTextField(
                controller: durC,
                label: 'Durasi',
                hint: 'mnt',
                icon: Icons.timer_outlined,
                suffix: 'mnt',
                errorText: errors['dur'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onEditingComplete: () => setState(() => fillMissing()),
              ),
              second: AppTextField(
                controller: speedC,
                label: 'Kecepatan',
                hint: 'km/h',
                icon: Icons.speed_outlined,
                suffix: 'km/h',
                errorText: errors['speed'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
                onEditingComplete: () => setState(() => fillMissing()),
              ),
            ),
            Builder(builder: (_) {
              final r = infer();
              final scheme = Theme.of(ctx).colorScheme;
              if (r != null && r.$3 > 0 && r.$3 <= 60) {
                return Padding(
                  padding:
                      const EdgeInsets.only(top: AppSpacing.sm - 2),
                  child: Text(
                    '${r.$1.toStringAsFixed(1)} km • ${r.$2.toStringAsFixed(0)} mnt • ${r.$3.toStringAsFixed(1)} km/h',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                );
              }
              return Padding(
                padding:
                    const EdgeInsets.only(top: AppSpacing.sm - 2),
                child: Text(
                  'Isi 2 dari 3 (jarak, durasi, kecepatan) — sisanya otomatis.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              );
            }),
            const SizedBox(height: AppSpacing.md),
            ResponsiveTwoColumn(
              first: AppTextField(
                controller: elevC,
                label: 'Elevasi',
                hint: 'cth 150',
                icon: Icons.terrain_outlined,
                suffix: 'm',
                errorText: errors['elev'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
              second: AppTextField(
                controller: hrC,
                label: 'HR rata-rata',
                hint: 'opsional',
                icon: Icons.favorite_outline,
                suffix: 'bpm',
                errorText: errors['hr'],
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: noteC,
              label: 'Catatan (opsional)',
              hint: 'Rute, angin, perasaan...',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),
          ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              setState(() => fillMissing());
              if (!validate()) {
                setState(() {});
                return;
              }
              final r = infer()!;
              final time = (initial != null && initial.startDate.length >= 19)
                  ? initial.startDate.substring(10)
                  : 'T07:00:00Z';
              final a = CyclingActivity(
                id: initial?.id ?? 0,
                name: nameC.text.trim(),
                distance: r.$1 * 1000,
                averageSpeed: kmhToMs(r.$3),
                totalElevationGain:
                    double.tryParse(elevC.text.replaceAll(',', '.')) ?? 0,
                startDate: '${_ymd.format(date)}$time',
                averageHeartRate:
                    double.tryParse(hrC.text.replaceAll(',', '.')) ?? 0,
                note: noteC.text.trim(),
              );
              final db = ref.read(dbProvider);
              final newId = await db.upsertActivity(a);
              if (!ctx.mounted) return;
              Navigator.pop(ctx, a.copyWith(id: initial?.id ?? newId));
            },
            child: const Text('Simpan & Evaluasi'),
          ),
        ],
      ),
    ),
  );
}
