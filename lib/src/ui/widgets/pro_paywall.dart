import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/premium.dart';
import 'common.dart';
import 'responsive.dart';

/// Bottom-sheet paywall ala Strava Summit: daftar manfaat Pro + dua jalan
/// NOL-RUPIAH (donasi → kode, atau bagikan app). Tidak ada SDK iklan/IAP,
/// jadi tidak menambah ukuran APK maupun butuh akun AdMob.
Future<void> showProPaywall(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ProSheet(),
  );
}

class _ProSheet extends ConsumerStatefulWidget {
  const _ProSheet();
  @override
  ConsumerState<_ProSheet> createState() => _ProSheetState();
}

class _ProSheetState extends ConsumerState<_ProSheet> {
  final _code = TextEditingController();
  bool _checking = false;
  String? _err;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPro = ref.watch(premiumProvider).isPro;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('CyclingCoach Pro',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleLarge),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  'Sekali donasi, Pro selamanya di HP ini. Semua fitur inti — rekam GPS, coach, statistik — tetap gratis.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final p in proPerks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle,
                              color: scheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(p,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                        ]),
                  ),
                const SizedBox(height: 12),
                if (isPro)
                  Card(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    child: const ListTile(
                      leading: Icon(Icons.verified),
                      title: Text('Kamu sudah PRO. Terima kasih!'),
                      subtitle: Text('Semua keuntungan aktif di HP ini.'),
                    ),
                  )
                else ...[
                  AppButton(
                    icon: Icons.volunteer_activism_outlined,
                    label: '1. Donasi (Saweria / QRIS)',
                    onPressed: () => launchUrl(Uri.parse(donateUrl),
                        mode: LaunchMode.externalApplication),
                  ),
                  const SizedBox(height: 8),
                  AppTextField(
                    controller: _code,
                    label: '2. Punya kode donasi? Masukkan di sini',
                    hint: 'cth GOWES-PRO-2026',
                    icon: Icons.key_outlined,
                    errorText: _err,
                    textInputAction: TextInputAction.done,
                  ),
                  if (_err != null) const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2))
                          : const Icon(Icons.lock_open_outlined,
                              size: 18),
                      label: const Text('Buka Pro'),
                      onPressed: _checking ? null : _tryUnlock,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Nanti saja'),
                  ),
                ),
                if (context.isCompact) const SizedBox(height: 8),
              ]),
        ),
      ),
    );
  }

  Future<void> _tryUnlock() async {
    setState(() {
      _checking = true;
      _err = null;
    });
    final ok =
        await ref.read(premiumProvider.notifier).unlock(_code.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Selamat datang di PRO! Terima kasih dukungannya.')));
    } else {
      setState(() => _err = 'Kode salah. Cek lagi dari halaman donasi.');
    }
  }
}
