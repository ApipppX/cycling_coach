import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/responsive.dart';
import 'dashboard_screen.dart';
import 'track_screen.dart';
import 'explore_screen.dart';
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
    ExploreScreen(),
    CoachScreen(),
    StatsScreen(),
    EventScreen(),
    ProfileScreen(),
  ];

  /// Tab yang SUDAH pernah dibuka. IndexedStack di bawah me-build SEMUA
  /// children di frame pertama — termasuk 2 peta + stream GPS — sehingga
  /// di HP kentang Beranda lama muncul / terlihat blank. Dengan lazy ini
  /// hanya Beranda yang dibangun saat start; tab lain dibangun saat
  /// pertama dibuka, lalu tetap hidup (state tidak hilang).
  final _built = <int>{0};

  void _go(int i) => setState(() {
        idx = i;
        _built.add(i);
      });

  List<Widget> get _stackChildren => [
        for (var i = 0; i < _pages.length; i++)
          _built.contains(i) ? _pages[i] : const SizedBox.shrink(),
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
                  onDestinationSelected: _go,
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
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: Text('Jelajah')),
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
                      IndexedStack(index: idx, children: _stackChildren),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: IndexedStack(index: idx, children: _stackChildren),
          bottomNavigationBar: NavigationBar(
            selectedIndex: idx,
            onDestinationSelected: _go,
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
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Jelajah'),
              NavigationDestination(
                  icon: Icon(Icons.favorite_outline),
                  selectedIcon: Icon(Icons.favorite),
                  label: 'Coach'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Stats'),
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
