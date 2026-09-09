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
import '../widgets/homi_bottom_nav.dart';
import '../widgets/homi_brand.dart';

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
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  void _selectPage(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _pages() => [
        TodayPage(
          homeName: widget.controller.homeName,
          quickItems: widget.controller.quickItems,
          routines: widget.controller.routines,
          supplies: widget.controller.supplies,
          onAddQuickItem: widget.controller.addQuickItem,
          onRemoveQuickItem: widget.controller.removeQuickItem,
          onOpenRoutines: () => _selectPage(2),
          onOpenSupplies: () => _selectPage(3),
        ),
        HomePage(
          homeName: widget.controller.homeName,
          homeType: widget.controller.homeType,
        ),
        RoutinesPage(
          items: widget.controller.routines,
          onAdd: widget.controller.addRoutine,
          onToggle: widget.controller.toggleRoutine,
          onRemove: widget.controller.removeRoutine,
        ),
        SuppliesPage(
          items: widget.controller.supplies,
          onAdd: widget.controller.addSupply,
          onUpdateStatus: widget.controller.updateSupplyStatus,
          onRemove: widget.controller.removeSupply,
        ),
        PeoplePage(firebaseReady: widget.firebaseReady),
      ];

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.firebaseReady && FirebaseAuth.instance.currentUser != null;

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _index != 0) _selectPage(0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _PersistentHeader(
                signedIn: signedIn,
                onAccountTap: _openAccount,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    if (index != _index) setState(() => _index = index);
                  },
                  children: _pages(),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: HomiBottomNav(
              selectedIndex: _index,
              onSelected: _selectPage,
            ),
          ),
        ),
      ),
    );
  }
}

class _PersistentHeader extends StatelessWidget {
  const _PersistentHeader({
    required this.signedIn,
    required this.onAccountTap,
  });

  final bool signedIn;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          const HomiLogo(width: 94),
          const Spacer(),
          IconButton.filledTonal(
            onPressed: onAccountTap,
            tooltip: signedIn ? 'Account' : 'Sign in',
            style: IconButton.styleFrom(
              backgroundColor: HomiColors.sage.withValues(alpha: 0.72),
              foregroundColor: HomiColors.slate,
            ),
            icon: Icon(
              signedIn ? Icons.person_rounded : Icons.person_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
