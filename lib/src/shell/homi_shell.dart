import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/home/home_page.dart';
import '../features/people/people_page.dart';
import '../features/profile/profile_settings_page.dart';
import '../features/routines/routines_page.dart';
import '../features/supplies/supplies_page.dart';
import '../features/today/today_page.dart';
import '../services/auth_service.dart';
import '../state/homi_app_controller.dart';
import '../theme/homi_theme.dart';
import '../widgets/google_provider_mark.dart';
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

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Homi user';
  }

  Future<void> _openAccount() async {
    final user = widget.authService.currentUser;
    if (user == null) {
      widget.onOpenAuth();
      return;
    }

    final google = widget.authService.signedInWithGoogle(user);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AccountAvatar(user: user, size: 54),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _displayName(user),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (google) ...[
                              const SizedBox(width: 8),
                              const GoogleProviderMark(size: 18),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          user.email ?? 'Signed in',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              user.emailVerified
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded,
                              size: 16,
                              color: user.emailVerified
                                  ? const Color(0xFF6F8B65)
                                  : HomiColors.coral,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              user.emailVerified
                                  ? 'Verified email'
                                  : 'Email not verified',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: user.emailVerified
                                    ? const Color(0xFF6F8B65)
                                    : HomiColors.coral,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 120),
                    );
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ProfileSettingsPage(
                          authService: widget.authService,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.manage_accounts_outlined),
                  label: const Text('Profile settings'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await widget.authService.signOut();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
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
          onToggleRoutine: widget.controller.toggleRoutine,
          onOpenRoutines: () => _selectPage(1),
          onOpenSupplies: () => _selectPage(3),
        ),
        RoutinesPage(
          items: widget.controller.routines,
          onAdd: widget.controller.addRoutine,
          onToggle: widget.controller.toggleRoutine,
          onRemove: widget.controller.removeRoutine,
        ),
        HomePage(
          homeName: widget.controller.homeName,
          homeType: widget.controller.homeType,
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
    final user = widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;

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
                user: user,
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
    required this.user,
    required this.onAccountTap,
  });

  final User? user;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          const HomiLogo(width: 94),
          const Spacer(),
          Tooltip(
            message: user == null ? 'Sign in' : 'Account',
            child: InkWell(
              onTap: onAccountTap,
              customBorder: const CircleBorder(),
              child: _AccountAvatar(user: user, size: 42),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user, required this.size});

  final User? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.72),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(
              user == null ? Icons.person_outline_rounded : Icons.person_rounded,
              size: size * 0.52,
              color: HomiColors.slate,
            )
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_rounded,
                size: size * 0.52,
                color: HomiColors.slate,
              ),
            ),
    );
  }
}
