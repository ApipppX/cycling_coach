import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/prefs.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnbState();
}

class _OnbState extends ConsumerState<OnboardingScreen> {
  final nameC = TextEditingController();
  final ageC = TextEditingController();
  final weightC = TextEditingController(text: '70');
  String? err;

  @override
  void dispose() {
    nameC.dispose();
    ageC.dispose();
    weightC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final age = int.tryParse(ageC.text);
    final previewMax = age == null ? null : (220 - age).clamp(140, 220);
    return Scaffold(
      body: SafeArea(
        child: ResponsiveList(maxWidth: 560, children: [
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Container(
              width: 88,
              height: 88,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_bike,
                  size: 44, color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('CyclingCoach',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
              'Pelatih sepeda pribadimu: analisis AI, planner event, dan statistik.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xl),
          AppTextField(
              controller: nameC,
              label: 'Nama panggilan',
              hint: 'cth Rizky',
              icon: Icons.person_outline,
              textInputAction: TextInputAction.next),
          const SizedBox(height: 12),
          AppTextField(
              controller: ageC,
              label: 'Umur (tahun)',
              hint: 'cth 25',
              icon: Icons.cake_outlined,
              suffix: 'thn',
              keyboardType: TextInputType.number,
              errorText: err,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 4),
          Text(
              previewMax != null
                  ? 'MaxHR otomatis: $previewMax bpm.'
                  : 'Umur dipakai menghitung MaxHR dan zona latihanmu.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          AppTextField(
              controller: weightC,
              label: 'Berat badan',
              hint: 'cth 70',
              icon: Icons.monitor_weight_outlined,
              suffix: 'kg',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done),
          const SizedBox(height: 4),
          Text('Berat dipakai untuk estimasi kalori tiap sesi.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
              onPressed: () {
                final age = int.tryParse(ageC.text);
                final weight = double.tryParse(
                    weightC.text.replaceAll(',', '.'));
                if (nameC.text.trim().isEmpty) {
                  setState(() => err = 'Nama tidak boleh kosong');
                  return;
                }
                if (age == null || age < 10 || age > 100) {
                  setState(() => err = 'Umur harus 10–100 tahun');
                  return;
                }
                if (weight == null || weight < 30 || weight > 200) {
                  setState(
                      () => err = 'Berat harus 30–200 kg');
                  return;
                }
                ref
                    .read(prefsProvider.notifier)
                    .finishOnboarding(nameC.text, age);
                ref.read(prefsProvider.notifier).updateWeight(weight);
              },
              child: const Text('Mulai Berlatih',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ]),
      ),
    );
  }
}
