import 'package:flutter/material.dart';

/// Breakpoint ala Strava / Material 3 window size class:
/// - compact  : HP portrait (< 600)
/// - medium   : HP landscape / tablet kecil (600–1099)
/// - expanded : tablet besar / desktop / web (>= 1100)
/// - rail     : tampilkan NavigationRail samping (>= 800)
class AppBreakpoints {
  static const double medium = 600;
  static const double rail = 800;
  static const double expanded = 1100;

  /// Lebar konten maksimal agar di tablet/desktop tidak melebar penuh
  /// (keterbacaan + tidak ada ruang kosong aneh di kanan-kiri).
  static double contentMaxWidth(double width, {double? override}) {
    if (override != null) return override;
    if (width >= expanded) return 960;
    if (width >= medium) return 720;
    return double.infinity; // HP: pakai lebar penuh
  }
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  bool get isCompact => screenWidth < AppBreakpoints.medium;

  /// HP sempit 320–380px: paksa 1 kolom / menu ringkas.
  bool get isNarrow => screenWidth < 380;
  bool get isMedium =>
      screenWidth >= AppBreakpoints.medium &&
      screenWidth < AppBreakpoints.expanded;
  bool get isExpanded => screenWidth >= AppBreakpoints.expanded;
  bool get showRail => screenWidth >= AppBreakpoints.rail;

  /// Padding horizontal responsif: 16 di HP, 24 di tablet/desktop.
  EdgeInsets get responsivePagePadding {
    final h = isCompact ? 16.0 : 24.0;
    return EdgeInsets.symmetric(horizontal: h, vertical: 12);
  }
}

/// Pembungkus konten halaman: di HP full-width, di tablet/desktop konten
/// di tengah dengan lebar maksimal agar tidak overflow / terlalu renggang.
///
/// Pakai sebagai `body` Scaffold:
/// ```dart
/// body: ResponsivePage(
///   child: ListView(children: [...]),
/// )
/// ```
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cap = AppBreakpoints.contentMaxWidth(width, override: maxWidth);
    if (cap == double.infinity) {
      if (padding != null) {
        return Padding(padding: padding!, child: child);
      }
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child:
            padding == null ? child : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// ListView yang otomatis di tengah + padding responsif.
/// Pengganti `ListView(padding: EdgeInsets.all(16))` agar konsisten di
/// semua halaman: HP tetap 16, tablet/desktop 24 + max-width.
class ResponsiveList extends StatelessWidget {
  final List<Widget> children;
  final double? maxWidth;
  final EdgeInsets? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const ResponsiveList({
    super.key,
    required this.children,
    this.maxWidth,
    this.padding,
    this.controller,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cap = AppBreakpoints.contentMaxWidth(width, override: maxWidth);
    // Selalu kembalikan ListView langsung (tanpa pembungkus Align) agar
    // tetap kompatibel dengan RefreshIndicator / ScrollController yang
    // mensyaratkan child scrollable langsung. Centering di tablet/desktop
    // dilakukan via padding horizontal tambahan.
    if (cap == double.infinity) {
      final pad = padding ?? context.responsivePagePadding;
      return ListView(
        controller: controller,
        physics: physics,
        padding: pad,
        children: children,
      );
    }
    if (padding != null) {
      final side = ((width - cap) / 2).clamp(0.0, double.infinity);
      return ListView(
        controller: controller,
        physics: physics,
        padding:
            EdgeInsets.symmetric(horizontal: side).add(padding!),
        children: children,
      );
    }
    final base = width < AppBreakpoints.medium ? 16.0 : 24.0;
    final side = ((width - cap) / 2).clamp(0.0, double.infinity);
    return ListView(
      controller: controller,
      physics: physics,
      padding:
          EdgeInsets.fromLTRB(side + base, 12, side + base, 24),
      children: children,
    );
  }
}

/// Baris input 2 kolom yang otomatis menumpuk vertikal di layar sempit.
/// Mengganti `Row(Expanded, Expanded)` mentah yang overflow di HP 320px
/// saat font dibesarkan / ada prefixIcon.
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget first;
  final Widget second;
  final double breakpoint;
  final double spacing;

  const ResponsiveTwoColumn({
    super.key,
    required this.first,
    required this.second,
    this.breakpoint = 380,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              first,
              SizedBox(height: spacing),
              second,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            SizedBox(width: spacing),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// Grid adaptif untuk kartu metrik: jumlah kolom mengikuti lebar + jumlah
/// item agar tidak ada sel terlalu gepeng / overflow teks.
///
/// - HP sempit (< 360): 2 kolom
/// - HP normal (< 600): pakai `compactColumns` (default 3)
/// - Tablet (>= 600): 3–4 kolom
/// - Desktop (>= 1100): sampai `expandedColumns`
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int compactColumns;
  final int expandedColumns;
  final double spacing;
  final double minItemWidth;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.compactColumns = 3,
    this.expandedColumns = 4,
    this.spacing = 12,
    this.minItemWidth = 150,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        int cols;
        if (w < 360) {
          cols = 2;
        } else if (w < AppBreakpoints.medium) {
          cols = compactColumns;
        } else if (w < AppBreakpoints.expanded) {
          cols = expandedColumns.clamp(3, 6);
        } else {
          cols = (expandedColumns + 2).clamp(3, 6);
        }
        // Jangan buat kolom lebih banyak dari item (mis. 2 item -> 2 kolom).
        cols = cols.clamp(1, children.isEmpty ? 1 : children.length);
        // Pastikan tiap sel tidak lebih sempit dari minItemWidth.
        final maxByWidth =
            (w / (minItemWidth + spacing)).floor().clamp(1, 6);
        cols = cols.clamp(1, maxByWidth == 0 ? 1 : maxByWidth);
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          // Rasio melebar di layar besar agar kartu tidak terlalu tinggi.
          childAspectRatio: w >= AppBreakpoints.medium ? 1.5 : 1.35,
          children: children,
        );
      },
    );
  }
}
