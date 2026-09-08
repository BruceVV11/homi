import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/people/people_page.dart';
import '../features/routines/routines_page.dart';
import '../features/supplies/supplies_page.dart';
import '../features/today/today_page.dart';
import '../services/auth_service.dart';
import '../state/homi_app_controller.dart';
import '../theme/homi_theme.dart';

class HomiShell extends StatefulWidget {
  const HomiShell({
    required this.controller,
    required this.authService,
    required this.firebaseReady,
    required this.onOpenAuth,
    super.key,
  });

  final HomiAppController controller;
  final AuthService authService;
  final bool firebaseReady;
  final VoidCallback onOpenAuth;

  @override
  State<HomiShell> createState() => _HomiShellState();
}

class _HomiShellState extends State<HomiShell> {
  int _index = 0;

  Future<void> _openAccount() async {
    final user = widget.authService.currentUser;
    if (user == null) {
      widget.onOpenAuth();
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Homi account', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(user.email ?? 'Signed in', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.authService.signOut();
                    if (context.mounted) Navigator.pop(context);
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pages(bool signedIn) => [
        TodayPage(homeName: widget.controller.homeName, signedIn: signedIn, onAccountTap: _openAccount),
        HomePage(homeName: widget.controller.homeName, homeType: widget.controller.homeType),
        const RoutinesPage(),
        const SuppliesPage(),
        PeoplePage(firebaseReady: widget.firebaseReady),
      ];

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.firebaseReady && FirebaseAuth.instance.currentUser != null;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) setState(() => _index = 0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _pages(signedIn)),
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
                boxShadow: const [BoxShadow(blurRadius: 24, offset: Offset(0, 8), color: Color(0x14000000))],
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
                  NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today_rounded), label: 'Today'),
                  NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
                  NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist_rounded), label: 'Routines'),
                  NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'Supplies'),
                  NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'People'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
