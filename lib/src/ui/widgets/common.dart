import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

final _intFmt = NumberFormat('#,###', 'en_US');

/// "1.234.567" ala Indonesia dari angka (pakai titik manual agar tidak
/// tergantung locale device).
String fmtInt(num v) => _intFmt.format(v).replaceAll(',', '.');

/// Judul seksi ala Strava: tegas 16px w800, bukan uppercase kecil.
/// Action dibungkus Flexible agar tidak overflow di layar sempit.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? action;
  const SectionTitle(this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.xl, bottom: AppSpacing.sm),
      child: Row(children: [
        Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800))),
        if (action case final Widget a)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: a,
            ),
          ),
      ]),
    );
  }
}

/// TextField standar ala Strava: padding lega (anti label kepotong),
/// ikon + hint contoh + suffix satuan. Dipakai di SEMUA form/dialog
/// agar konsisten.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final String? suffix;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;

  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.suffix,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.onChanged,
    this.onEditingComplete,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        suffixText: suffix,
        suffixStyle: TextStyle(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            fontSize: 13),
      ),
    );
  }
}

/// Kartu seksi bernomor ala production (ganti duplikasi _InputCard).
/// Header: lingkaran nomor + judul + subtitle + trailing opsional.
/// Body: child dengan spacing konsisten.
class AppSectionCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget child;
  const AppSectionCard({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs),
                      child: Text(step,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimary,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.md + 2),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tombol utama konsisten: full-width opsional + loading state.
/// Menggantikan SizedBox(width:double.infinity)+FilledButton berulang.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  final bool tonal;
  final bool expanded;
  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
    this.tonal = false,
    this.expanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? (Theme.of(context).brightness == Brightness.dark
            ? AppColors.errorDark
            : AppColors.error)
        : null;
    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5))
        else if (icon != null)
          Icon(icon, size: 18),
        if (loading || icon != null)
          const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ),
      ],
    );
    ButtonStyle? style =
        destructive ? FilledButton.styleFrom(backgroundColor: bg, foregroundColor: Colors.white) : null;
    Widget btn;
    if (tonal) {
      btn = icon != null || loading
          ? FilledButton.tonalIcon(
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(strokeWidth: 2.5))
                  : Icon(icon, size: 18),
              label: Text(label),
              onPressed: loading ? null : onPressed,
              style: style,
            )
          : FilledButton.tonal(
              onPressed: loading ? null : onPressed,
              style: style,
              child: content);
    } else {
      btn = icon != null || loading
          ? FilledButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white))
                  : Icon(icon, size: 18),
              label: Text(label),
              onPressed: loading ? null : onPressed,
              style: style ??
                  FilledButton.styleFrom(
                      minimumSize:
                          const Size(AppSizes.touchComfort, AppSizes.buttonHeight)),
            )
          : FilledButton(
              onPressed: loading ? null : onPressed,
              style: style ??
                  FilledButton.styleFrom(
                      minimumSize:
                          const Size(AppSizes.touchComfort, AppSizes.buttonHeight)),
              child: content,
            );
    }
    if (!expanded) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}

/// Dialog konfirmasi standar (hapus/timpa) — konsisten di semua screen.
Future<bool> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Batal',
  String confirmLabel = 'Hapus',
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title,
          maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Text(message,
          maxLines: 5, overflow: TextOverflow.ellipsis),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelLabel)),
        FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness ==
                                Brightness.dark
                            ? AppColors.errorDark
                            : AppColors.error)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel)),
      ],
    ),
  );
  return ok == true;
}

/// Snackbar sukses/error konsisten (tidak mengganggu, floating).
void showAppSnack(BuildContext context, String message,
    {bool isError = false}) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
        content: Text(message,
            maxLines: 3, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? (Theme.of(context).brightness == Brightness.dark
                ? AppColors.errorDark
                : AppColors.error)
            : null,
        duration: const Duration(seconds: 2)),
  );
}
/// Status kosong standar dengan ikon, ajakan, dan tombol aksi.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.actionLabel,
      this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 34, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant)),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
              onPressed: onAction,
            ),
          ],
        ]),
      ),
    );
  }
}

/// Loading standar agar tidak flash "Belum ada data" saat stream DB dibuka.
class AppLoading extends StatelessWidget {
  final String message;
  const AppLoading({super.key, this.message = 'Memuat data...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }
}

/// Error standar untuk stream DB dengan tombol coba lagi (rebuild).
class AppError extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const AppError({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: AppSpacing.sm),
          const Text('Gagal memuat data',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
                onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ]),
      ),
    );
  }
}

/// Grid statistik responsif: jumlah kolom mengikuti lebar layar + jumlah
/// item, tiap sel tidak lebih sempit dari 150px agar teks tidak overflow.
class AppStatsGrid extends StatelessWidget {
  final List<Widget> children;
  final int? columns;
  final double spacing;
  final double aspect;
  const AppStatsGrid(
      {super.key,
      required this.children,
      this.columns,
      this.spacing = 12,
      this.aspect = 1.6});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols;
        if (w < 360) {
          cols = 2;
        } else if (w < 600) {
          final want = columns ?? (w < 380 ? 2 : 3);
          cols = want.clamp(1, children.isEmpty ? 1 : children.length);
        } else if (w < 1100) {
          cols = (columns ?? 3).clamp(3, 4);
          cols = cols.clamp(1, children.isEmpty ? 1 : children.length);
          final maxByWidth = (w / 158).floor().clamp(1, 6);
          cols = cols.clamp(1, maxByWidth == 0 ? 1 : maxByWidth);
        } else {
          cols = ((columns ?? 3) + 2).clamp(3, 6);
          cols = cols.clamp(1, children.isEmpty ? 1 : children.length);
        }
        // Rasio adaptif: layar besar -> kartu lebih melebar, tidak jangkung.
        final effectiveAspect = w >= 600 ? aspect + 0.35 : aspect;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: effectiveAspect,
          children: children,
        );
      },
    );
  }
}

/// Sel angka ala Strava: nilai besar tabular di tengah + label abu di bawah.
/// Nilai dibungkus FittedBox scaleDown agar tidak overflow saat font
/// sistem dibesarkan / layar 320px.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? valueColor;
  final String? sub;
  const StatTile(this.value, this.label,
      {super.key, this.icon, this.valueColor, this.sub});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 20,
                    color:
                        valueColor ?? scheme.primary),
                const SizedBox(height: 4),
              ],
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        height: 1.1,
                        fontFeatures: const [
                          FontFeature.tabularFigures()
                        ],
                        color: valueColor)),
              ),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              if (sub != null && sub!.isNotEmpty)
                Text(sub!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 10)),
            ]),
      ),
    );
  }
}

/// Tabel responsif ala Strava: header abu kecil, divider tiap baris,
/// angka tabular. Bisa scroll horizontal di HP sempit.
class ScrollTable extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<int> flexes;
  final List<int>? aligns;
  const ScrollTable(
      {super.key,
      required this.headers,
      required this.rows,
      required this.flexes,
      this.aligns});

  @override
  Widget build(BuildContext context) {
    assert(headers.length == flexes.length);
    final scheme = Theme.of(context).colorScheme;
    final totalFlex = flexes.fold<int>(0, (a, b) => a + b);
    final headerStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            letterSpacing: 0.5);
    final cellStyle = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);
    Alignment alignOf(int i) {
      final a = (aligns != null && i < aligns!.length)
          ? aligns![i]
          : (i == 0 ? 0 : 2);
      return a == 1
          ? Alignment.center
          : a == 2
              ? Alignment.centerRight
              : Alignment.centerLeft;
    }

    Widget cell(Widget w, int col, {bool header = false}) => Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.sm),
          child: Align(
            alignment: alignOf(col),
            child: DefaultTextStyle.merge(
              style: header ? headerStyle : cellStyle,
              textAlign: alignOf(col) == Alignment.centerRight
                  ? TextAlign.end
                  : alignOf(col) == Alignment.center
                      ? TextAlign.center
                      : TextAlign.start,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              child: w,
            ),
          ),
        );

    // Lebar minimum agar kolom tidak gepeng di HP sempit (bisa scroll
    // horizontal), tapi di tablet/desktop tabel melebar penuh mengikuti Card.
    final minNeeded = totalFlex * 84.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minW = minNeeded > constraints.maxWidth
              ? minNeeded
              : constraints.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minW,
                maxWidth: minNeeded > constraints.maxWidth
                    ? minNeeded
                    : constraints.maxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.55),
                    child: Row(
                      children: [
                        for (var i = 0;
                            i < headers.length;
                            i++)
                          Expanded(
                            flex: flexes[i],
                            child: cell(
                                Text(headers[i].toUpperCase()),
                                i,
                                header: true),
                          ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color: scheme.outlineVariant
                          .withValues(alpha: 0.5)),
                  for (var r = 0; r < rows.length; r++) ...[
                    Container(
                      color: r.isOdd
                          ? scheme.surfaceContainerHighest
                              .withValues(alpha: 0.22)
                          : null,
                      child: Row(
                        children: [
                          for (var i = 0;
                              i < headers.length;
                              i++)
                            Expanded(
                              flex: flexes[i],
                              child: cell(
                                  rows[r][i], i),
                            ),
                        ],
                      ),
                    ),
                    if (r < rows.length - 1)
                      Divider(
                          height: 1,
                          color: scheme.outlineVariant
                              .withValues(alpha: 0.3)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
