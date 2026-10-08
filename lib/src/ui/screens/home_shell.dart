import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/responsive.dart';
import 'dashboard_screen.dart';
import 'track_screen.dart';
import 'coach_screen.dart';
import 'stats_screen.dart';
import 'event_screen.dart';
import 'profile_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<HomeShell> {
  int idx = 0;
  // Disimpan sebagai field agar state tiap tab (scroll, form) tidak hilang
  // saat pindah tab — IndexedStack menjaga semua halaman tetap hidup.
  static const _pages = [
    DashboardScreen(),
    TrackScreen(),
    CoachScreen(),
    StatsScreen(),
    EventScreen(),
    ProfileScreen(),
  ];
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tablet landscape / desktop / web: navigasi samping agar konten
        // luas + tidak makan ruang vertikal. HP: NavigationBar bawah.
        final wide = constraints.maxWidth >= AppBreakpoints.rail;
        if (wide) {
          final extended =
              constraints.maxWidth >= AppBreakpoints.expanded;
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: idx,
                  extended: extended,
                  onDestinationSelected: (i) => setState(() => idx = i),
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Beranda')),
                    NavigationRailDestination(
                        icon: Icon(Icons.fiber_manual_record_outlined),
                        selectedIcon:
                            Icon(Icons.fiber_manual_record),
                        label: Text('Rekam')),
                    NavigationRailDestination(
                        icon: Icon(Icons.favorite_outline),
                        selectedIcon: Icon(Icons.favorite),
                        label: Text('Coach AI')),
                    NavigationRailDestination(
                        icon: Icon(Icons.bar_chart_outlined),
                        selectedIcon: Icon(Icons.bar_chart),
                        label: Text('Statistik')),
                    NavigationRailDestination(
                        icon: Icon(Icons.flag_outlined),
                        selectedIcon: Icon(Icons.flag),
                        label: Text('Event')),
                    NavigationRailDestination(
                        icon: Icon(Icons.person_outline),
                        selectedIcon: Icon(Icons.person),
                        label: Text('Profil')),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child:
                      IndexedStack(index: idx, children: _pages),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(index: idx, children: _pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: (i) => setState(() => idx = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Beranda'),
              NavigationDestination(
                  icon: Icon(Icons.fiber_manual_record_outlined),
                  selectedIcon: Icon(Icons.fiber_manual_record),
                  label: 'Rekam'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Coach AI'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Statistik'),
              NavigationDestination(
                  icon: Icon(Icons.flag_outlined),
                  selectedIcon: Icon(Icons.flag),
                  label: 'Event'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil'),
            ],
          ),
        );
      },
    );
  }
}
