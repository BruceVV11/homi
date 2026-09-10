import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/household_task.dart';
import '../features/home/home_page.dart';
import '../features/people/people_hub_page.dart';
import '../features/profile/account_hub_page.dart';
import '../features/routines/routines_page.dart';
import '../features/supplies/supplies_page.dart';
import '../features/today/today_page.dart';
import '../services/account_data_service.dart';
import '../services/arrival_check_in_service.dart';
import '../services/auth_service.dart';
import '../services/developer_notification_service.dart';
import '../services/household_people_service.dart';
import '../services/location_status_service.dart';
import '../services/notification_service.dart';
import '../services/shared_task_service.dart';
import '../services/trusted_people_service.dart';
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
  static const _initialNotificationPromptKey =
      'homi.notifications.initialPermissionPromptShown';

  int _index = 0;
  WorkView _requestedWorkView = WorkView.tasks;
  int _workViewRequest = 0;
  late final PageController _pageController;
  late final LocationStatusService _locationService;
  late final ArrivalCheckInService _arrivalCheckInService;
  late final TrustedPeopleService _trustedPeopleService;
  late final HouseholdPeopleService _householdPeopleService;
  late final SharedTaskService _sharedTaskService;
  late final AccountDataService _accountDataService;
  late final HomiNotificationService _notificationService;
  late final DeveloperNotificationService _developerNotificationService;
  StreamSubscription<String>? _notificationRouteSubscription;
  Timer? _notificationScheduleDebounce;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _locationService = LocationStatusService(
      firebaseReady: widget.firebaseReady,
    );
    _arrivalCheckInService = ArrivalCheckInService(
      firebaseReady: widget.firebaseReady,
      locationService: _locationService,
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
    _accountDataService = AccountDataService(
      firebaseReady: widget.firebaseReady,
    );
    _notificationService = HomiNotificationService(
      firebaseReady: widget.firebaseReady,
    );
    _developerNotificationService = DeveloperNotificationService(
      firebaseReady: widget.firebaseReady,
    );
    widget.controller.addListener(_queueNotificationReconcile);
    unawaited(widget.controller.pruneExpiredTasks());
    unawaited(_initializeLocationFeatures());
    unawaited(_initializeNotifications());
  }

  Future<void> _initializeLocationFeatures() async {
    try {
      await _locationService.loadCachedStatus();
      await _arrivalCheckInService.initialize();
      await _locationService.resumeContinuousSharingIfEnabled();
    } catch (_) {
      // Resuming never prompts. The People safety/location screens explain
      // permission or service issues when the user opens them.
    }
  }

  Future<void> _initializeNotifications() async {
    _notificationRouteSubscription =
        _notificationService.routes.listen(_handleNotificationRoute);
    try {
      await _notificationService.initialize();
      await _requestInitialNotificationPermissionIfNeeded();
      await _reconcileNotifications();
      final pending = _notificationService.takePendingRoute();
      if (pending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _handleNotificationRoute(pending);
        });
      }
    } catch (_) {
      // Notification setup is additive. A notification problem must not stop
      // the household app from opening.
    }
  }

  Future<void> _requestInitialNotificationPermissionIfNeeded() async {
    if (!_notificationService.preferences.enabled ||
        _notificationService.osPermissionGranted) {
      return;
    }
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_initialNotificationPromptKey) == true) return;

    // Mark before opening Android's permission UI so a denied/dismissed prompt
    // is not repeatedly shown every time Homi opens. The user can always retry
    // from Homi & account -> Notifications.
    await preferences.setBool(_initialNotificationPromptKey, true);
    await _notificationService.requestPermissionAndEnable();
  }

  void _queueNotificationReconcile() {
    _notificationScheduleDebounce?.cancel();
    _notificationScheduleDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_reconcileNotifications()),
    );
  }

  Future<void> _reconcileNotifications() {
    return _notificationService.reconcileLocalSchedules(
      tasks: widget.controller.tasks,
      routines: widget.controller.routines,
      supplies: widget.controller.supplies,
      homeThings: widget.controller.homeThings,
    );
  }

  void _handleNotificationRoute(String route) {
    if (!mounted) return;
    switch (route) {
      case 'tasks':
        _openWork(WorkView.tasks);
      case 'routines':
        _openWork(WorkView.routines);
      case 'home':
        _selectPage(2);
      case 'supplies':
        _selectPage(3);
      case 'people':
        _selectPage(4);
      case 'account':
        unawaited(_openAccount());
      default:
        _selectPage(0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_queueNotificationReconcile);
    _notificationScheduleDebounce?.cancel();
    unawaited(_notificationRouteSubscription?.cancel());
    _pageController.dispose();
    _arrivalCheckInService.dispose();
    unawaited(_notificationService.disposeService());
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
    final uidBefore = widget.firebaseReady
        ? FirebaseAuth.instance.currentUser?.uid
        : null;
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AccountHubPage(
          authService: widget.authService,
          accountDataService: _accountDataService,
          controller: widget.controller,
          locationService: _locationService,
          notificationService: _notificationService,
          developerNotificationService: _developerNotificationService,
          onSignIn: widget.onOpenAuth,
        ),
      ),
    );
    if (!mounted) return;
    if (deleted == true && uidBefore != null) {
      await _arrivalCheckInService.clearStoredForUid(uidBefore);
    }
    await _notificationService.refreshDeviceRegistration();
    await _reconcileNotifications();
    if (!mounted) return;
    if (deleted == true && _index != 0) {
      _selectPage(0);
    } else {
      setState(() {});
    }
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
        onOpenRoutines: () => _openWork(WorkView.routines),
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
        actorPhotoUrl: user?.photoURL,
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
        onAdd: (
          name,
          category,
          status,
          expiryDate,
          iconKey,
          quantity,
          unit,
        ) =>
            widget.controller.addSupply(
          name,
          category,
          status,
          expiryDate,
          iconKey: iconKey,
          quantity: quantity,
          unit: unit,
        ),
        onUpdateStatus: widget.controller.updateSupplyStatus,
        onUpdateQuantity: widget.controller.updateSupplyQuantity,
        onRemove: widget.controller.removeSupply,
      ),
      PeopleHubPage(
        locationService: _locationService,
        trustedPeopleService: _trustedPeopleService,
        checkInService: _arrivalCheckInService,
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
            message: user == null ? 'Homi & account' : 'Account',
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
