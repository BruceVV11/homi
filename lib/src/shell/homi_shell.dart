import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/people/people_page.dart';
import '../features/routines/routines_page.dart';
import '../features/supplies/supplies_page.dart';
import '../features/today/today_page.dart';
import '../theme/homi_theme.dart';

class HomiShell extends StatefulWidget {
  const HomiShell({super.key});

  @override
  State<HomiShell> createState() => _HomiShellState();
}

class _HomiShellState extends State<HomiShell> {
  int _index = 0;

  static const _pages = <Widget>[
    TodayPage(),
    HomePage(),
    RoutinesPage(),
    SuppliesPage(),
    PeoplePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _pages),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HomiColors.border),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 24,
                    offset: Offset(0, 8),
                    color: Color(0x14000000),
                  ),
                ],
              ),
              child: NavigationBar(
                height: 68,
                backgroundColor: Colors.transparent,
                elevation: 0,
                selectedIndex: _index,
                indicatorColor: HomiColors.coral.withValues(alpha: 0.13),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (value) => setState(() => _index = value),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today_rounded),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.checklist_outlined),
                    selectedIcon: Icon(Icons.checklist_rounded),
                    label: 'Routines',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2_rounded),
                    label: 'Supplies',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.people_outline_rounded),
                    selectedIcon: Icon(Icons.people_rounded),
                    label: 'People',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
