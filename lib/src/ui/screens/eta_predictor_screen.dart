import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/models.dart';
import '../../core/eta_predictor.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../theme/app_theme.dart';

/// Kalkulator ETA Anti-COT — MODE MANUAL.
///
/// Sengaja TIDAK otomatis: mengetik tidak pernah mengubah field lain dan
/// tidak memicu hitung ulang (menghindari hasil kedip-kedip dari ketikan
/// setengah jadi). Isi data → tekan HITUNG → hasil dikunci sampai HITUNG
/// ditekan lagi.
class EtaPredictorScreen extends ConsumerStatefulWidget {
  final EventGoal? event;
  const EtaPredictorScreen({super.key, this.event});

  @override
  ConsumerState<EtaPredictorScreen> createState() => _EtaState();
}

class _EtaState extends ConsumerState<EtaPredictorScreen> {
  late TextEditingController targetC;
  late TextEditingController cotC; // total jam, mis. 8 / 6.5
  late TextEditingController kmC;
  late TextEditingController elapsedC; // menit tempuh
  late TextEditingController speedC; // avg speed km/h
  late TextEditingController stepC; // checkpoint tiap X km
  TimeOfDay start = TimeOfDay.now();
  Timer? _live;
  bool get liveOn => _live != null;
  final _scroll = ScrollController();

  EtaPrediction? _result;
  DateTime? _resultStart;
  String? _derivedNote;
  String? _error;

  /// Jumlah field posisi yang sudah terisi (0–3) — untuk progress "isi 2 dari 3".
  int get filledCount {
    var n = 0;
    if (_num(kmC) > 0) n++;
    if (_num(speedC) > 0) n++;
    if (_num(elapsedC) > 0) n++;
    return n;
  }

  bool get canHitung => filledCount >= 2;

  @override
  void initState() {
    super.initState();
    targetC = TextEditingController(
        text: (widget.event?.targetDistanceKm ?? 100).toStringAsFixed(0));
    cotC = TextEditingController(text: '8');
    kmC = TextEditingController();
    elapsedC = TextEditingController();
    speedC = TextEditingController();
    stepC = TextEditingController(text: '10');
    // Refresh indikator "x dari 3" saat mengetik, tanpa menghitung ulang.
    kmC.addListener(_refresh);
    speedC.addListener(_refresh);
    elapsedC.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _live?.cancel();
    _scroll.dispose();
    targetC.dispose();
    cotC.dispose();
    kmC.dispose();
    elapsedC.dispose();
    speedC.dispose();
    stepC.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  DateTime get _startDateTime {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, start.hour, start.minute);
  }

  String get _startLabel =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

  void _fail(String msg) {
    setState(() {
      _error = msg;
      _result = null;
      _derivedNote = null;
    });
    _scrollToResult();
  }

  void _hitung() {
    FocusScope.of(context).unfocus();
    final target = _num(targetC);
    final cotH = _num(cotC);
    if (target <= 0 || target > 1000) {
      _fail('Isi target jarak dulu (1–1000 km).');
      return;
    }
    if (cotH <= 0 || cotH > 72) {
      _fail('Isi COT total dulu (jam, maks 72).');
      return;
    }
    final r = resolveTriple(
        km: _num(kmC),
        speedKmh: _num(speedC),
        elapsedMin: _num(elapsedC));
    if (r == null) {
      _fail('Isi minimal 2 dari 3: KM posisi, avg speed, waktu tempuh.');
      return;
    }
    if (r.speedKmh > 60) {
      _fail('Pace ${r.speedKmh.toStringAsFixed(1)} km/h tidak wajar (maks 60).');
      return;
    }
    if (r.km > target) {
      _fail(
          'Posisi KM (${r.km.toStringAsFixed(1)}) melebihi target ($target km).');
      return;
    }
    // Tulis balik nilai turunan SEKALI, hanya saat tombol ditekan.
    String? note;
    if (_num(kmC) <= 0) {
      kmC.text = r.km.toStringAsFixed(1);
      note = 'Jarak dilengkapi otomatis: ${r.km.toStringAsFixed(1)} km.';
    } else if (_num(elapsedC) <= 0) {
      elapsedC.text = r.elapsedMin.toStringAsFixed(0);
      note =
          'Waktu tempuh dilengkapi otomatis: ${formatDuration(r.elapsedMin)}.';
    } else if (_num(speedC) <= 0) {
      speedC.text = r.speedKmh.toStringAsFixed(1);
      note = 'Pace dilengkapi otomatis: ${r.speedKmh.toStringAsFixed(1)} km/h.';
    }
    final step = _num(stepC);
    final p = predictEta(
      targetKm: target,
      currentKm: r.km,
      elapsedMin: r.elapsedMin,
      cotMin: cotH * 60,
      checkpointEveryKm: step > 0 ? step : 10,
    );
    setState(() {
      _error = null;
      _result = p;
      _resultStart = _startDateTime;
      _derivedNote = note;
    });
    _scrollToResult();
  }

  void _fillElapsedFromStart() {
    elapsedC.text =
        '${DateTime.now().difference(_startDateTime).inMinutes.clamp(0, 1 << 20)}';
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Waktu tempuh diisi dari jam start: ${elapsedC.text} mnt'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  void _toggleLive() {
    if (_live != null) {
      _live!.cancel();
      _live = null;
    } else {
      _fillElapsedFromStart();
      _live = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        _fillElapsedFromStart();
      });
    }
    setState(() {});
  }

  void _startNow() {
    setState(() => start = TimeOfDay.now());
    _fillElapsedFromStart();
  }

  void _reset() {
    _live?.cancel();
    _live = null;
    kmC.clear();
    elapsedC.clear();
    speedC.clear();
    setState(() {
      start = TimeOfDay.now();
      _result = null;
      _derivedNote = null;
      _error = null;
    });
  }

  void _bump(TextEditingController c, double delta, {int fraction = 0}) {
    final v = (_num(c) + delta).clamp(0, 1e6).toDouble();
    c.text = v.toStringAsFixed(fraction);
  }

  void _scrollToResult() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut);
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: start);
    if (t != null) setState(() => start = t);
  }

  @override
  Widget build(BuildContext context) {
    final p = _result;
    final scheme = Theme.of(context).colorScheme;
    final color = p == null
        ? scheme.primary
        : switch (p.verdict) {
            EtaVerdict.aman => context.success,
            EtaVerdict.waspada => context.warning,
            EtaVerdict.overCot => context.danger,
            EtaVerdict.finished => context.success,
            EtaVerdict.belumJalan => scheme.primary,
          };
    final startUsed = _resultStart ?? _startDateTime;
    final finishClock = (p != null && p.hasPace)
        ? formatClock(startUsed
            .add(Duration(minutes: p.projectedTotalMin.round())))
        : '-';

    return Scaffold(
      appBar: AppBar(
          title: const Text('ETA Anti-COT'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Cara pakai',
              onPressed: _showGuide,
            ),
          ]),
      // Tombol HITUNG sticky di bawah — selalu terlihat tanpa scroll.
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
          child: FilledButton.icon(
            icon: const Icon(Icons.calculate_outlined, size: 20),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('HITUNG PREDIKSI',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text('$filledCount/3',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size.fromHeight(AppSizes.buttonHeightLarge),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppRadius.button)),
            ),
            onPressed: _hitung,
          ),
        ),
      ),
      body: ResponsiveList(controller: _scroll, children: [
        if (widget.event != null) _EventHeader(event: widget.event!),
        // ---------- HASIL ----------
        if (p == null && _error == null) _EmptyHint(liveOn: liveOn),
        if (_error != null)
          Card(
            color: context.danger.withValues(alpha: 0.12),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md + 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      color: context.danger, size: 22),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Belum bisa dihitung',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium),
                        const SizedBox(height: 2),
                        Text(_error!,
                            style:
                                TextStyle(color: context.danger)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Tutup',
                    onPressed: () => setState(() => _error = null),
                  ),
                ],
              ),
            ),
          ),
        if (p != null) ...[
          _ResultCard(
            p: p,
            color: color,
            finishClock: finishClock,
            liveOn: liveOn,
            derivedNote: _derivedNote,
          ),
          const SizedBox(height: 10),
          _EtaStatsGrid(
            paceNow: p.currentAvgKmh > 0
                ? '${p.currentAvgKmh.toStringAsFixed(1)} km/h'
                : '-',
            paceNeed: p.requiredAvgKmh.isFinite && p.requiredAvgKmh > 0
                ? '${p.requiredAvgKmh.toStringAsFixed(1)} km/h'
                : '-',
            remainingKm: '${p.remainingKm.toStringAsFixed(1)} km',
            remainingTime: p.remainingMinVsCot >= 0
                ? formatDuration(p.remainingMinVsCot)
                : 'habis',
            remainingTimeAlert: p.remainingMinVsCot < 0,
            buffer: p.bufferMin.isFinite
                ? formatDuration(p.bufferMin.abs())
                : '-',
            bufferShort: p.bufferMin.isFinite && p.bufferMin < 0,
            cotClock: formatClock(
                startUsed.add(Duration(minutes: p.cotMin.round()))),
          ),
          const SizedBox(height: AppSpacing.md),
          const SectionTitle('Checkpoint (tiba sebelum COT)'),
          if (p.checkpoints.isEmpty)
            Card(
                child: Padding(
                    padding:
                        const EdgeInsets.all(AppSpacing.lg),
                    child: Text('Tidak ada checkpoint tersisa.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium)))
          else
            ScrollTable(
              headers: const ['KM', 'Harus tiba', 'Status'],
              flexes: const [2, 3, 2],
              aligns: const [0, 2, 1],
              rows: [
                for (final c in p.checkpoints)
                  [
                    Text('KM ${c.km.toStringAsFixed(0)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                                fontWeight: FontWeight.w700)),
                    Text(c.etaMinFromStart.isFinite
                        ? formatClock(startUsed.add(Duration(
                            minutes: c.etaMinFromStart.round())))
                        : '-'),
                    _CheckpointBadge(ok: c.reachableOnPace),
                  ],
              ],
            ),
          const SizedBox(height: AppSpacing.md),
        ],
        // ---------- INPUT 1: RENCANA ----------
        AppSectionCard(
          step: '1',
          title: 'Rencana gowes',
          subtitle: 'Target & batas waktu dari panitia',
          child: Column(
            children: [
              ResponsiveTwoColumn(
                breakpoint: 360,
                first: AppTextField(
                  controller: targetC,
                  label: 'Target jarak',
                  hint: 'cth 100',
                  icon: Icons.flag_outlined,
                  suffix: 'km',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  textInputAction: TextInputAction.next,
                ),
                second: AppTextField(
                  controller: cotC,
                  label: 'COT total',
                  hint: 'cth 8',
                  icon: Icons.timer_outlined,
                  suffix: 'jam',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              AppTextField(
                controller: stepC,
                label: 'Pengingat tiap',
                hint: 'cth 10',
                icon: Icons.location_on_outlined,
                suffix: 'km',
                keyboardType:
                    const TextInputType.numberWithOptions(
                        decimal: true),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _StartTile(
                time: _startLabel,
                onPick: _pickStart,
                onNow: _startNow,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        // ---------- INPUT 2: POSISI ----------
        AppSectionCard(
          step: '2',
          title: 'Posisi saat ini',
          subtitle: 'Isi minimal 2 dari 3 — sisanya dihitung otomatis',
          trailing: _FilledBadge(
              text: '$filledCount/3',
              done: canHitung,
              tooltip: 'Jumlah field posisi yang terisi'),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
                child: LinearProgressIndicator(
                  value: filledCount / 3,
                  minHeight: 6,
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  canHitung
                      ? 'Siap dihitung — tekan HITUNG di bawah.'
                      : 'Kurang ${2 - filledCount} lagi agar bisa dihitung.',
                  style: TextStyle(
                      fontSize: 12,
                      color: canHitung
                          ? context.success
                          : scheme.onSurfaceVariant,
                      fontWeight:
                          canHitung ? FontWeight.w700 : FontWeight.w400),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _StepperField(
                controller: kmC,
                label: 'Saya di KM berapa?',
                hint: 'cth 45',
                icon: Icons.route_outlined,
                suffix: 'km',
                minusTooltip: 'Kurangi 1 km',
                plusTooltip: 'Tambah 1 km',
                onMinus: () => _bump(kmC, -1, fraction: 1),
                onPlus: () => _bump(kmC, 1, fraction: 1),
                extra: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(56, 48),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _bump(kmC, 5, fraction: 1),
                  child: const Text('+5',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _StepperField(
                controller: speedC,
                label: 'Rata-rata speed',
                hint: 'cth 22.5',
                icon: Icons.speed_outlined,
                suffix: 'km/h',
                minusTooltip: 'Kurangi 1 km/h',
                plusTooltip: 'Tambah 1 km/h',
                onMinus: () => _bump(speedC, -1, fraction: 1),
                onPlus: () => _bump(speedC, 1, fraction: 1),
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              _StepperField(
                controller: elapsedC,
                label: 'Waktu tempuh',
                hint: 'cth 120',
                icon: Icons.schedule_outlined,
                suffix: 'mnt',
                minusTooltip: 'Kurangi 5 menit',
                plusTooltip: 'Tambah 5 menit',
                onMinus: () => _bump(elapsedC, -5),
                onPlus: () => _bump(elapsedC, 5),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.history_outlined, size: 18),
                  label: const Text('Dari jam start'),
                  onPressed: _fillElapsedFromStart,
                ),
                FilledButton.tonalIcon(
                  icon: Icon(
                      liveOn ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      size: 18),
                  label: Text(liveOn ? 'Live ON' : 'Timer live'),
                  onPressed: _toggleLive,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt_outlined, size: 18),
                  label: const Text('Reset'),
                  onPressed: _reset,
                ),
              ]),
              if (liveOn)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                            'Timer live jalan — waktu tempuh diperbarui tiap 30 dtk.',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm + 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm - 2),
            Expanded(
              child: Text(
                'Tips: jaga pace sedikit di atas "Butuh sisa" sejak awal agar punya cadangan untuk tanjakan & pit-stop.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
      ]),
    );
  }

  /// Panduan penggunaan Anti-COT untuk hari-H event.
  void _showGuide() {
    const steps = [
      ('1. Siapkan rencana', 'Isi Target (km) dan COT total (jam) dari panitia. Atur jam start sesuai flag-off. Buka dari tab Event agar target terisi otomatis.'),
      ('2. Catat posisi live', 'Selama gowes, isi minimal 2 dari 3: KM posisi, avg speed, waktu tempuh. Sisanya dilengkapi otomatis saat tekan HITUNG.'),
      ('3. Tekan HITUNG', 'Hasil dikunci: verdict AMAN / WASPADA / OVER COT, proyeksi jam finis, dan pace yang dibutuhkan di sisa jarak.'),
      ('4. Ikuti checkpoint', 'Tabel checkpoint menunjukkan jam berapa kamu HARUS tiba di tiap KM agar tidak kena COT. Badge hijau = pace-mu cukup, merah = perlu ngebut sedikit.'),
      ('5. Update tiap checkpoint', 'Tiap tiba di pos, update KM + tekan HITUNG lagi. Nyalakan Timer live agar waktu tempuh berjalan sendiri tiap 30 detik.'),
      ('Aturan praktis', 'Jaga pace sedikit DI ATAS "Butuh sisa" sejak awal — tanjakan, angin, dan pit-stop selalu memakan cadangan waktumu.'),
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Cara pakai Anti-COT',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final s in steps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.$1,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(s.$2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Mengerti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header event: ikon flag dalam lingkaran aksen + nama + meta.
class _EventHeader extends StatelessWidget {
  final EventGoal event;
  const _EventHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              ),
              child: Icon(Icons.flag_outlined,
                  color: scheme.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                      'Target ${event.targetDistanceKm.toStringAsFixed(0)} km • ${event.eventDate}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Petunjuk awal sebelum ada hasil — lebih jelas dari sekadar teks tengah.
class _EmptyHint extends StatelessWidget {
  final bool liveOn;
  const _EmptyHint({required this.liveOn});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm + 1),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_bike_outlined,
                  size: 20, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Isi data lalu tekan HITUNG',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '1. Isi rencana → 2. Isi 2 dari 3 posisi → 3. HITUNG. Hasil dikunci sampai HITUNG ditekan lagi.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu hasil verdict: ikon + label besar + proyeksi finis + note.
class _ResultCard extends StatelessWidget {
  final EtaPrediction p;
  final Color color;
  final String finishClock;
  final bool liveOn;
  final String? derivedNote;
  const _ResultCard(
      {required this.p,
      required this.color,
      required this.finishClock,
      required this.liveOn,
      required this.derivedNote});

  @override
  Widget build(BuildContext context) {
    final icon = switch (p.verdict) {
      EtaVerdict.aman => Icons.check_circle_rounded,
      EtaVerdict.finished => Icons.emoji_events_outlined,
      EtaVerdict.waspada => Icons.warning_amber_rounded,
      EtaVerdict.overCot => Icons.dangerous_outlined,
      EtaVerdict.belumJalan => Icons.info_outline,
    };
    final progress = p.cotMin > 0
        ? (p.projectedTotalMin.isFinite
            ? (p.projectedTotalMin / p.cotMin).clamp(0.0, 1.0)
            : 1.0)
        : 0.0;
    return Card(
      color: color.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg + 2),
        child: Column(children: [
          Icon(icon, size: 34, color: color),
          const SizedBox(height: AppSpacing.sm),
          Text(etaVerdictLabel(p.verdict),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: color)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.verdict == EtaVerdict.finished
                ? 'Waktu tempuh ${formatDuration(p.elapsedMin)}'
                : p.hasPace
                    ? 'Proyeksi finis $finishClock (${formatDuration(p.projectedTotalMin)})'
                    : 'Belum ada pace — lengkapi data lalu HITUNG lagi',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.hasPace
                ? 'Terpakai ${(progress * 100).toStringAsFixed(0)}% dari COT'
                : 'Progres COT akan muncul setelah ada pace',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (derivedNote != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm - 2),
              child: Text(derivedNote!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          if (liveOn)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                  'Timer live jalan — tekan HITUNG untuk refresh hasil.',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ]),
      ),
    );
  }
}

/// Badge kecil "2/3" — sukses bila syarat terpenuhi.

/// Baris stepper: tombol − 48dp, field tengah, tombol + 48dp, opsional ekstra.
class _StepperField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String suffix;
  final String minusTooltip;
  final String plusTooltip;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final Widget? extra;
  const _StepperField(
      {required this.controller,
      required this.label,
      required this.hint,
      required this.icon,
      required this.suffix,
      required this.minusTooltip,
      required this.plusTooltip,
      required this.onMinus,
      required this.onPlus,
      this.extra});

  @override
  Widget build(BuildContext context) {
    Widget stepBtn(
        {required IconData icon,
        required String tooltip,
        required VoidCallback onTap}) {
      return SizedBox(
        width: AppSizes.touchComfort,
        height: AppSizes.inputHeight,
        child: FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppRadius.button)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: onTap,
          child: Tooltip(message: tooltip, child: Icon(icon, size: 20)),
        ),
      );
    }

    return Row(
      children: [
        stepBtn(
            icon: Icons.remove, tooltip: minusTooltip, onTap: onMinus),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AppTextField(
            controller: controller,
            label: label,
            hint: hint,
            icon: icon,
            suffix: suffix,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        stepBtn(icon: Icons.add, tooltip: plusTooltip, onTap: onPlus),
        if (extra != null) ...[
          const SizedBox(width: AppSpacing.sm),
          SizedBox(height: AppSizes.touchComfort, child: extra!),
        ],
      ],
    );
  }
}

/// Tile jam start: jam besar + tombol Ubah & Sekarang.
class _StartTile extends StatelessWidget {
  final String time;
  final VoidCallback onPick;
  final VoidCallback onNow;
  const _StartTile(
      {required this.time, required this.onPick, required this.onNow});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.sm - 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(Icons.schedule_outlined,
                color: scheme.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          const Expanded(
            child: Text('Jam start',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(time,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ])),
            ),
          ),
          TextButton(onPressed: onPick, child: const Text('Ubah')),
          IconButton(
            icon: const Icon(Icons.my_location_outlined, size: 20),
            tooltip: 'Set ke jam sekarang',
            onPressed: onNow,
          ),
        ],
      ),
    );
  }
}

/// Badge kecil "2/3" — sukses bila syarat terpenuhi.
class _FilledBadge extends StatelessWidget {
  final String text;
  final bool done;
  final String tooltip;
  const _FilledBadge(
      {required this.text, required this.done, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    final bg = done ? context.success : Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: bg.withValues(alpha: 0.45)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: bg)),
      ),
    );
  }
}

/// Badge status checkpoint: OK sukses / KEJAR bahaya — selalu sama lebar.
class _CheckpointBadge extends StatelessWidget {
  final bool ok;
  const _CheckpointBadge({required this.ok});

  @override
  Widget build(BuildContext context) {
    final bg = ok ? context.success : context.danger;
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              size: 14, color: bg),
          const SizedBox(width: 4),
          Text(ok ? 'OK' : 'KEJAR',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: bg)),
        ],
      ),
    );
  }
}

/// Grid hasil ETA: 3 baris × 2 kolom TETAP, bukan GridView.
///
/// Kenapa tidak pakai GridView.count: childAspectRatio memaksa tinggi
/// tetap sehingga teks panjang ("1j 30m", "25.0 km/h") kepotong/ellipsis
/// tidak rata di HP sempit. Dengan Row + Expanded tiap baris, tinggi
/// mengikuti konten dan kedua sel selalu sejajar.
class _EtaStatsGrid extends StatelessWidget {
  final String paceNow;
  final String paceNeed;
  final String remainingKm;
  final String remainingTime;
  final bool remainingTimeAlert;
  final String buffer;
  final bool bufferShort;
  final String cotClock;

  const _EtaStatsGrid({
    required this.paceNow,
    required this.paceNeed,
    required this.remainingKm,
    required this.remainingTime,
    required this.remainingTimeAlert,
    required this.buffer,
    required this.bufferShort,
    required this.cotClock,
  });

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: b),
            ],
          ),
        );
    return Column(
      children: [
        row(
          _EtaStat(
              icon: Icons.speed_outlined,
              label: 'Pace kini',
              value: paceNow),
          _EtaStat(
              icon: Icons.track_changes_outlined,
              label: 'Butuh sisa',
              value: paceNeed,
              accent: context.warning),
        ),
        const SizedBox(height: AppSpacing.sm),
        row(
          _EtaStat(
              icon: Icons.route_outlined,
              label: 'Sisa jarak',
              value: remainingKm),
          _EtaStat(
              icon: Icons.timer_outlined,
              label: 'Sisa waktu COT',
              value: remainingTime,
              accent: remainingTimeAlert ? context.danger : null),
        ),
        const SizedBox(height: AppSpacing.sm),
        row(
          _EtaStat(
              icon: Icons.savings_outlined,
              label: bufferShort ? 'Kurang waktu' : 'Cadangan',
              value: buffer,
              accent: bufferShort ? context.danger : context.success),
          _EtaStat(
              icon: Icons.flag_outlined, label: 'COT (jam)', value: cotClock),
        ),
      ],
    );
  }
}

/// Satu sel ETA: ikon + label kecil di atas, angka besar 1 baris di bawah.
/// Value dibungkus FittedBox scaleDown agar selalu muat tanpa ellipsis
/// berantakan — teks mengecil, bukan kepotong.
class _EtaStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  const _EtaStat(
      {required this.icon,
      required this.label,
      required this.value,
      this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = accent ?? scheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: ink),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  maxLines: 1,
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                      color: accent)),
            ),
          ],
        ),
      ),
    );
  }
}
