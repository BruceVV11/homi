import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/household_task.dart';
import '../features/home/home_page.dart';
import '../features/people/people_page.dart';
import '../features/profile/profile_settings_page.dart';
import '../features/routines/routines_page.dart';
import '../features/supplies/supplies_page.dart';
import '../features/today/today_page.dart';
import '../services/auth_service.dart';
import '../services/household_people_service.dart';
import '../services/location_status_service.dart';
import '../services/shared_task_service.dart';
import '../services/trusted_people_service.dart';
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
  WorkView _requestedWorkView = WorkView.tasks;
  int _workViewRequest = 0;
  late final PageController _pageController;
  late final LocationStatusService _locationService;
  late final TrustedPeopleService _trustedPeopleService;
  late final HouseholdPeopleService _householdPeopleService;
  late final SharedTaskService _sharedTaskService;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _locationService = LocationStatusService(
      firebaseReady: widget.firebaseReady,
    );
    _trustedPeopleService = TrustedPeopleService(
      firebaseReady: widget.firebaseReady,
    );
    _householdPeopleService = HouseholdPeopleService(
      firebaseReady: widget.firebaseReady,
    );
    _sharedTaskService = SharedTaskService(
      firebaseReady: widget.firebaseReady,
    );
    unawaited(widget.controller.pruneExpiredTasks());
    unawaited(_resumeLocationSharing());
  }

  Future<void> _resumeLocationSharing() async {
    try {
      await _locationService.loadCachedStatus();
      await _locationService.resumeContinuousSharingIfEnabled();
    } catch (_) {
      // Resuming never prompts. The People page explains any permission issue.
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    unawaited(_locationService.dispose());
    super.dispose();
  }

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Homi user';
  }

  String _actorName(User? user) => user == null ? 'You' : _displayName(user);

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
                    await _locationService.stopContinuousSharing();
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

  void _openWork(WorkView view) {
    setState(() {
      _requestedWorkView = view;
      _workViewRequest += 1;
    });
    _selectPage(1);
  }

  List<Widget> _pages(User? user) {
    final actorName = _actorName(user);
    final actorUid = user?.uid;
    return [
      TodayPage(
        homeName: widget.controller.homeName,
        quickItems: widget.controller.quickItems,
        tasks: widget.controller.tasks,
        routines: widget.controller.routines,
        supplies: widget.controller.supplies,
        homeThings: widget.controller.homeThings,
        onRemoveQuickItem: widget.controller.removeQuickItem,
        onToggleRoutine: (id) => widget.controller.toggleRoutine(
          id,
          actorName: actorName,
          actorUid: actorUid,
        ),
        onOpenRoutines: () => _openWork(WorkView.tasks),
        onOpenHome: () => _selectPage(2),
        onOpenSupplies: () => _selectPage(3),
        onQuickAddTask: () => _openWork(WorkView.tasks),
        onQuickAddRoutine: () => _openWork(WorkView.routines),
        onQuickAddSupply: () => _selectPage(3),
        onQuickAddHome: () => _selectPage(2),
      ),
      RoutinesPage(
        items: widget.controller.routines,
        tasks: widget.controller.tasks,
        actorName: actorName,
        actorUid: actorUid,
        trustedPeopleService: _householdPeopleService,
        sharedTaskService: _sharedTaskService,
        requestedView: _requestedWorkView,
        viewRequest: _workViewRequest,
        onAdd: (data) => widget.controller.addRoutine(
          title: data.title,
          category: data.category,
          repeat: data.repeat,
          estimatedMinutes: data.estimatedMinutes,
          dueHour: data.dueHour,
          dueMinute: data.dueMinute,
          repeatDays: data.repeatDays,
          dayOfMonth: data.dayOfMonth,
        ),
        onToggle: (id) => widget.controller.toggleRoutine(
          id,
          actorName: actorName,
          actorUid: actorUid,
        ),
        onRemove: widget.controller.removeRoutine,
        onAddTask: (HouseholdTaskInput input) => widget.controller.addTask(
          title: input.title,
          createdByName: actorName,
          createdByUid: actorUid,
          notes: input.notes,
          assigneeName: input.assigneeName,
          assigneeUid: input.assigneeUid,
          dueAt: input.dueAt,
        ),
        onToggleTask: (id) => widget.controller.toggleTask(
          id,
          actorName: actorName,
          actorUid: actorUid,
        ),
        onRemoveTask: widget.controller.removeTask,
      ),
      HomePage(
        homeName: widget.controller.homeName,
        homeType: widget.controller.homeType,
        things: widget.controller.homeThings,
        events: widget.controller.homeEvents,
        readings: widget.controller.utilityReadings,
        actorName: actorName,
        onAddThing: (input) => widget.controller.addHomeThing(
          name: input.name,
          category: input.category,
          location: input.location,
          brandModel: input.brandModel,
          nextServiceDate: input.nextServiceDate,
          warrantyUntil: input.warrantyUntil,
          notes: input.notes,
        ),
        onRemoveThing: widget.controller.removeHomeThing,
        onAddEvent: (input) => widget.controller.addHomeEvent(
          type: input.type,
          title: input.title,
          date: input.date,
          completedByName: input.completedByName,
          thingId: input.thingId,
          notes: input.notes,
        ),
        onRemoveEvent: widget.controller.removeHomeEvent,
        onAddReading: (input) => widget.controller.addUtilityReading(
          type: input.type,
          value: input.value,
          recordedAt: input.recordedAt,
          recordedByName: input.recordedByName,
          unit: input.unit,
          notes: input.notes,
        ),
        onRemoveReading: widget.controller.removeUtilityReading,
      ),
      SuppliesPage(
        items: widget.controller.supplies,
        onAdd: (name, category, status, expiryDate, iconKey) =>
            widget.controller.addSupply(
          name,
          category,
          status,
          expiryDate,
          iconKey: iconKey,
        ),
        onUpdateStatus: widget.controller.updateSupplyStatus,
        onRemove: widget.controller.removeSupply,
      ),
      PeoplePage(
        locationService: _locationService,
        trustedPeopleService: _trustedPeopleService,
        firebaseReady: widget.firebaseReady,
        onSignIn: widget.onOpenAuth,
      ),
    ];
  }

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
                  children: _pages(user),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
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
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAccountTap,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: _AccountAvatar(user: user, size: 42),
              ),
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
