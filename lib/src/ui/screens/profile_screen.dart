import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/backup.dart';
import '../../providers/providers.dart';
import '../../data/prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Profil')),
      body: ResponsiveList(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text((p.userName.isEmpty ? 'C' : p.userName[0])
                      .toUpperCase(),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium)),
              title: Text(p.userName.isEmpty ? 'Rider' : p.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                  'Umur ${p.userAge} • ${p.weightKg.toStringAsFixed(0)} kg • MaxHR ${p.maxHr} • Target ${p.weeklyTargetKm.toStringAsFixed(0)} km/minggu',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit profil',
                onPressed: () => _profileDialog(context, ref, p),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: Text('Tema',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                trailing: DropdownButton<int>(
                    value: p.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                          value: 0, child: Text('Sistem')),
                      DropdownMenuItem(
                          value: 1, child: Text('Terang')),
                      DropdownMenuItem(
                          value: 2, child: Text('Gelap')),
                    ],
                    onChanged: (v) => ref
                        .read(prefsProvider.notifier)
                        .updateTheme(v ?? 0)),
              ),
              Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                  color: scheme.outlineVariant
                      .withValues(alpha: 0.4)),
              ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: Text('Ubah MaxHR',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              fontWeight: FontWeight.w700)),
                  subtitle: const Text(
                      'Zona latihan mengikuti MaxHR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        final c =
                            TextEditingController(text: '${p.maxHr}');
                        showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                                    title: const Text('MaxHR (bpm)'),
                                    content: AppTextField(
                                        controller: c,
                                        label: 'MaxHR',
                                        hint: 'cth 190',
                                        icon: Icons.favorite_outline,
                                        suffix: 'bpm',
                                        keyboardType:
                                            TextInputType.number),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child:
                                              const Text('Batal')),
                                      FilledButton(
                                          onPressed: () {
                                            ref
                                                .read(prefsProvider
                                                    .notifier)
                                                .updateMaxHr(
                                                    int.tryParse(
                                                            c.text) ??
                                                        p.maxHr);
                                            Navigator.pop(context);
                                          },
                                          child:
                                              const Text('Simpan'))
                                    ]));
                      })),
            ],
          ),
        ),
        const SectionTitle('Data'),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text('Backup (JSON)',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: const Text(
                    'Simpan semua latihan, event & pengaturan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportBackup(context, ref),
              ),
              Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                  color: scheme.outlineVariant
                      .withValues(alpha: 0.4)),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text('Restore (JSON)',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                subtitle: const Text('Timpa data dari file backup',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importBackup(context, ref),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          icon: Icons.delete_outline,
          label: 'Hapus semua data',
          tonal: true,
          destructive: true,
          onPressed: () async {
            final ok = await showAppConfirm(context,
                title: 'Hapus semua?',
                message:
                    'Tidak bisa dibatalkan. Buat backup dulu bila ragu.',
                confirmLabel: 'Hapus');
            if (ok) {
              await ref.read(dbProvider).clearAll();
              if (context.mounted) {
                showAppSnack(context, 'Semua data dihapus.');
              }
            }
          },
        ),
      ]),
    );
  }

  void _profileDialog(
      BuildContext context, WidgetRef ref, PrefsState p) {
    final nameC = TextEditingController(text: p.userName);
    final ageC = TextEditingController(text: '${p.userAge}');
    final weightC = TextEditingController(
        text: p.weightKg.toStringAsFixed(0));
    final targetC = TextEditingController(
        text: p.weeklyTargetKm.toStringAsFixed(0));
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 24),
              title: const Text('Edit Profil'),
              content: SizedBox(
                width: context.isCompact
                    ? double.maxFinite
                    : 400,
                child: SingleChildScrollView(
                  child: Column(children: [
                    AppTextField(
                        controller: nameC,
                        label: 'Nama panggilan',
                        hint: 'cth Rizky',
                        icon: Icons.person_outline),
                    const SizedBox(height: AppSpacing.md),
                    ResponsiveTwoColumn(
                      first: AppTextField(
                          controller: ageC,
                          label: 'Umur',
                          hint: '25',
                          icon: Icons.cake_outlined,
                          suffix: 'thn',
                          keyboardType: TextInputType.number),
                      second: AppTextField(
                          controller: weightC,
                          label: 'Berat badan',
                          hint: '70',
                          icon: Icons.monitor_weight_outlined,
                          suffix: 'kg',
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                        controller: targetC,
                        label: 'Target mingguan',
                        hint: '100',
                        icon: Icons.flag_outlined,
                        suffix: 'km',
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true)),
                  ]),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                FilledButton(
                    onPressed: () {
                      final age = int.tryParse(ageC.text);
                      final weight = double.tryParse(
                          weightC.text.replaceAll(',', '.'));
                      final target = double.tryParse(
                          targetC.text.replaceAll(',', '.'));
                      if (nameC.text.trim().isEmpty ||
                          age == null ||
                          age < 10 ||
                          age > 100) {
                        return;
                      }
                      final notifier =
                          ref.read(prefsProvider.notifier);
                      notifier.updateProfile(nameC.text, age);
                      if (weight != null) notifier.updateWeight(weight);
                      if (target != null && target > 0) {
                        notifier.updateTarget(target);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Simpan')),
              ],
            ));
  }

  Future<void> _exportBackup(
      BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(dbProvider);
      final prefs = await SharedPreferences.getInstance();
      final json = exportBackupJson(
        activities: await db.getActivities(),
        events: await db.getEvents(),
        prefs: {
          'weekly_target_km': prefs.getDouble('weekly_target_km'),
          'max_hr': prefs.getInt('max_hr'),
          'user_name': prefs.getString('user_name'),
          'user_age': prefs.getInt('user_age'),
          'weight_kg': prefs.getDouble('weight_kg'),
          'theme_mode': prefs.getInt('theme_mode'),
        },
      );
      final stamp =
          DateTime.now().toIso8601String().substring(0, 10);
      final f =
          File('${Directory.systemTemp.path}/cyclingcoach_backup_$stamp.json');
      await f.writeAsString(json);
      await SharePlus.instance.share(
          ShareParams(files: [XFile(f.path)], subject: 'Backup CyclingCoach'));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal backup: $e')));
      }
    }
  }

  Future<void> _importBackup(
      BuildContext context, WidgetRef ref) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    final f = files.first;
    String text;
    try {
      if (f.path != null) {
        text = await File(f.path!).readAsString();
      } else {
        text = await f.xFile.readAsString();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal baca file: $e')));
      }
      return;
    }
    final parsed = importBackupJson(text);
    if (!context.mounted) return;
    if (parsed.activities.isEmpty && parsed.skipped > 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('File backup tidak valid (version != 1)')));
      }
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore backup?'),
        content: Text(
            '${parsed.activities.length} latihan & ${parsed.events.length} event akan MENIMPA data sekarang (${parsed.skipped} baris dilewati).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Timpa')),
        ],
      ),
    );
    if (ok != true) return;
    final db = ref.read(dbProvider);
    await db.restoreAll(parsed.activities, parsed.events);
    final notifier = ref.read(prefsProvider.notifier);
    final p = parsed.prefs;
    final t = (p['weekly_target_km'] as num?)?.toDouble();
    if (t != null && t > 0) notifier.updateTarget(t);
    final age = (p['user_age'] as num?)?.toInt();
    final name = (p['user_name'] as String?) ?? '';
    if (age != null) notifier.updateProfile(name, age);
    final maxHr = (p['max_hr'] as num?)?.toInt();
    if (maxHr != null) notifier.updateMaxHr(maxHr);
    final w = (p['weight_kg'] as num?)?.toDouble();
    if (w != null) notifier.updateWeight(w);
    final theme = (p['theme_mode'] as num?)?.toInt();
    if (theme != null) notifier.updateTheme(theme);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Restore selesai: ${parsed.activities.length} latihan masuk')));
    }
  }
}
