import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../domain/home_thing.dart';
import '../domain/household_task.dart';
import '../domain/notification_preferences.dart';
import '../domain/routine_item.dart';
import '../domain/supply_item.dart';

@pragma('vm:entry-point')
Future<void> homiFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class HomiNotificationService extends ChangeNotifier {
  HomiNotificationService({required this.firebaseReady});

  static const _preferencesKey = 'homi.notifications.preferences';
  static const _deviceIdKey = 'homi.notifications.deviceId';
  static const _scheduledIdsKey = 'homi.notifications.scheduledIds';
  static const _alertedKeysKey = 'homi.notifications.alertedKeys';
  static const _updatesTopic = 'homi_updates';
  static const _serviceTopic = 'homi_service';
  static const _securityTopic = 'homi_security';

  static const _attentionChannel = AndroidNotificationChannel(
    'homi_attention',
    'Household attention',
    description: 'Important supply, expiry and home maintenance reminders.',
    importance: Importance.high,
  );
  static const _taskChannel = AndroidNotificationChannel(
    'homi_tasks',
    'Tasks and routines',
    description: 'Due tasks and recurring household routines.',
    importance: Importance.high,
  );
  static const _peopleChannel = AndroidNotificationChannel(
    'homi_people',
    'People',
    description: 'Trusted-person connections and small check-in messages.',
    importance: Importance.high,
  );
  static const _updatesChannel = AndroidNotificationChannel(
    'homi_updates',
    'Homi updates',
    description: 'Useful product news and feature information from Homi.',
    importance: Importance.defaultImportance,
  );
  static const _serviceChannel = AndroidNotificationChannel(
    'homi_service',
    'Service notices',
    description: 'Important Homi service, maintenance and security notices.',
    importance: Importance.high,
  );

  final bool firebaseReady;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  final Uuid _uuid = const Uuid();
  final StreamController<String> _routeController =
      StreamController<String>.broadcast();

  SharedPreferences? _prefs;
  HomiNotificationPreferences _preferences =
      const HomiNotificationPreferences();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _deviceId;
  String? _pendingRoute;
  bool _initialized = false;
  bool _osPermissionGranted = false;

  HomiNotificationPreferences get preferences => _preferences;
  bool get osPermissionGranted => _osPermissionGranted;
  bool get initialized => _initialized;
  Stream<String> get routes => _routeController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _deviceId = _prefs?.getString(_deviceIdKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _uuid.v4();
      await _prefs?.setString(_deviceIdKey, _deviceId!);
    }

    final rawPreferences = _prefs?.getString(_preferencesKey);
    if (rawPreferences != null && rawPreferences.isNotEmpty) {
      try {
        _preferences = HomiNotificationPreferences.decode(rawPreferences);
      } catch (_) {
        _preferences = const HomiNotificationPreferences();
      }
    }

    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // UTC remains a safe fallback and the next app launch retries the lookup.
    }

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('homi_notification'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _emitRoute(payload);
      },
    );

    final localLaunch = await _local.getNotificationAppLaunchDetails();
    final localPayload = localLaunch?.notificationResponse?.payload;
    if (localLaunch?.didNotificationLaunchApp == true &&
        localPayload != null &&
        localPayload.isNotEmpty) {
      _pendingRoute = localPayload;
    }

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_attentionChannel);
    await android?.createNotificationChannel(_taskChannel);
    await android?.createNotificationChannel(_peopleChannel);
    await android?.createNotificationChannel(_updatesChannel);
    await android?.createNotificationChannel(_serviceChannel);

    if (firebaseReady) {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      _osPermissionGranted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _routeFromMessage(message),
      );
      _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (_) async {
          await _syncDeveloperTopics();
          await refreshDeviceRegistration();
        },
      );
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) unawaited(refreshDeviceRegistration());
      });

      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _routeFromMessage(initial, holdIfNeeded: true);
      await _syncDeveloperTopics();
      await refreshDeviceRegistration();
    }

    _initialized = true;
    notifyListeners();
  }

  Future<bool> requestPermissionAndEnable() async {
    if (!firebaseReady) return false;

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _osPermissionGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (_osPermissionGranted) {
      _preferences = _preferences.copyWith(enabled: true);
      await _savePreferences();
      await _syncDeveloperTopics();
      await refreshDeviceRegistration();
    }
    notifyListeners();
    return _osPermissionGranted;
  }

  Future<void> setEnabled(bool value) async {
    if (value && !_osPermissionGranted) {
      await requestPermissionAndEnable();
      return;
    }
    _preferences = _preferences.copyWith(enabled: value);
    await _savePreferences();
    await _syncDeveloperTopics();
    if (value) {
      await refreshDeviceRegistration();
    } else {
      await removeDevicePushRegistration();
      await _cancelScheduledNotifications();
    }
    notifyListeners();
  }

  Future<void> updatePreferences(HomiNotificationPreferences value) async {
    _preferences = value;
    await _savePreferences();
    await _syncDeveloperTopics();
    if (_preferences.enabled) await refreshDeviceRegistration();
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    await _prefs?.setString(_preferencesKey, _preferences.encode());
  }

  Future<void> _syncDeveloperTopics() async {
    if (!firebaseReady) return;
    final messaging = FirebaseMessaging.instance;
    final allow = _preferences.enabled && _osPermissionGranted;
    try {
      if (allow && _preferences.homiUpdates) {
        await messaging.subscribeToTopic(_updatesTopic);
      } else {
        await messaging.unsubscribeFromTopic(_updatesTopic);
      }

      if (allow && _preferences.serviceNotices) {
        await messaging.subscribeToTopic(_serviceTopic);
        await messaging.subscribeToTopic(_securityTopic);
      } else {
        await messaging.unsubscribeFromTopic(_serviceTopic);
        await messaging.unsubscribeFromTopic(_securityTopic);
      }
    } catch (_) {
      // Topic sync retries on the next token refresh, settings save or launch.
    }
  }

  Future<void> refreshDeviceRegistration() async {
    if (!firebaseReady || !_preferences.enabled || !_osPermissionGranted) return;
    final user = FirebaseAuth.instance.currentUser;
    final deviceId = _deviceId;
    if (user == null || deviceId == null) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'pushToken': token,
      'platform': defaultTargetPlatform.name,
      'notificationsEnabled': true,
      'householdAttention': _preferences.householdAttention,
      'tasksAndRoutines': _preferences.tasksAndRoutines,
      'peopleNotifications': _preferences.people,
      'homiUpdates': _preferences.homiUpdates,
      'serviceNotices': _preferences.serviceNotices,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeDevicePushRegistration() async {
    if (!firebaseReady) return;
    final user = FirebaseAuth.instance.currentUser;
    final deviceId = _deviceId;
    if (user == null || deviceId == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'pushToken': FieldValue.delete(),
      'notificationsEnabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reconcileLocalSchedules({
    required List<HouseholdTask> tasks,
    required List<RoutineItem> routines,
    required List<SupplyItem> supplies,
    required List<HomeThing> homeThings,
  }) async {
    if (!_initialized || !_preferences.enabled || !_osPermissionGranted) return;

    await _cancelScheduledNotifications();
    final now = DateTime.now();
    final scheduledIds = <int>[];
    final plans = <_LocalNotificationPlan>[];

    if (_preferences.tasksAndRoutines) {
      for (final task in tasks) {
        final due = task.dueAt;
        if (task.completed || due == null || !due.isAfter(now)) continue;
        plans.add(
          _LocalNotificationPlan(
            key: 'task:${task.id}:${due.toIso8601String()}',
            when: due,
            title: 'Task due',
            body: task.assigneeName == null
                ? task.title
                : '${task.title} · ${task.assigneeName}',
            channel: _taskChannel,
            route: 'tasks',
          ),
        );
      }
      for (final routine in routines) {
        final due = routine.nextDueAt;
        if (due == null || !due.isAfter(now)) continue;
        plans.add(
          _LocalNotificationPlan(
            key: 'routine:${routine.id}:${due.toIso8601String()}',
            when: due,
            title: 'Routine due',
            body: routine.title,
            channel: _taskChannel,
            route: 'routines',
          ),
        );
      }
    }

    if (_preferences.householdAttention) {
      for (final supply in supplies) {
        final expiry = supply.expiryDate;
        if (expiry == null) continue;
        final expiryMorning = DateTime(expiry.year, expiry.month, expiry.day, 9);
        final warning = expiryMorning.subtract(const Duration(days: 3));
        if (warning.isAfter(now)) {
          plans.add(
            _LocalNotificationPlan(
              key:
                  'supply-expiry-warning:${supply.id}:${expiry.toIso8601String()}',
              when: warning,
              title: '${supply.name} expires soon',
              body: 'Use it soon or update the supply if your stock changed.',
              channel: _attentionChannel,
              route: 'supplies',
            ),
          );
        }
        if (expiryMorning.isAfter(now)) {
          plans.add(
            _LocalNotificationPlan(
              key: 'supply-expiry:${supply.id}:${expiry.toIso8601String()}',
              when: expiryMorning,
              title: '${supply.name} reaches its expiry date today',
              body:
                  'Open Supplies to check whether it still belongs in your stock.',
              channel: _attentionChannel,
              route: 'supplies',
            ),
          );
        }
      }

      for (final thing in homeThings) {
        final serviceDate = thing.nextServiceDate;
        if (serviceDate == null) continue;
        final dueMorning = DateTime(
          serviceDate.year,
          serviceDate.month,
          serviceDate.day,
          9,
        );
        final warning = dueMorning.subtract(const Duration(days: 7));
        if (warning.isAfter(now)) {
          plans.add(
            _LocalNotificationPlan(
              key:
                  'maintenance-warning:${thing.id}:${serviceDate.toIso8601String()}',
              when: warning,
              title: '${thing.name} needs attention soon',
              body: 'Its saved service date is one week away.',
              channel: _attentionChannel,
              route: 'home',
            ),
          );
        }
        if (dueMorning.isAfter(now)) {
          plans.add(
            _LocalNotificationPlan(
              key:
                  'maintenance-due:${thing.id}:${serviceDate.toIso8601String()}',
              when: dueMorning,
              title: '${thing.name} service is due',
              body: 'Open Home to review the saved maintenance details.',
              channel: _attentionChannel,
              route: 'home',
            ),
          );
        }
      }

      await _showNewCriticalSupplyAlert(supplies, now);
    }

    plans.sort((a, b) => a.when.compareTo(b.when));
    for (final plan in plans.take(60)) {
      final id = _notificationId(plan.key);
      final scheduled = tz.TZDateTime.from(plan.when, tz.local);
      await _local.zonedSchedule(
        id: id,
        title: plan.title,
        body: plan.body,
        scheduledDate: scheduled,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            plan.channel.id,
            plan.channel.name,
            channelDescription: plan.channel.description,
            icon: 'homi_notification',
            importance: plan.channel.importance,
            priority: plan.channel.importance == Importance.high
                ? Priority.high
                : Priority.defaultPriority,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: plan.route,
      );
      scheduledIds.add(id);
    }
    await _prefs?.setStringList(
      _scheduledIdsKey,
      scheduledIds.map((value) => '$value').toList(growable: false),
    );
  }

  Future<void> _showNewCriticalSupplyAlert(
    List<SupplyItem> supplies,
    DateTime now,
  ) async {
    final existing = (_prefs?.getStringList(_alertedKeysKey) ?? const <String>[])
        .toSet();
    final currentKeys = <String>{};
    final newlyCritical = <SupplyItem>[];

    for (final supply in supplies) {
      if (supply.effectiveStatus(now) != SupplyStatus.needToBuy) continue;
      final key = 'supply-out:${supply.id}';
      currentKeys.add(key);
      if (!existing.contains(key)) newlyCritical.add(supply);
    }

    if (newlyCritical.isNotEmpty) {
      final names = newlyCritical.take(3).map((item) => item.name).join(', ');
      final remaining = newlyCritical.length - 3;
      await _local.show(
        id: _notificationId(
          'critical-supply:${DateTime.now().millisecondsSinceEpoch}',
        ),
        title: newlyCritical.length == 1
            ? '${newlyCritical.first.name} needs attention'
            : '${newlyCritical.length} supplies need attention',
        body: remaining > 0 ? '$names and $remaining more.' : names,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'homi_attention',
            'Household attention',
            channelDescription:
                'Important supply, expiry and home maintenance reminders.',
            icon: 'homi_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: 'supplies',
      );
    }

    await _prefs?.setStringList(_alertedKeysKey, currentKeys.toList());
  }

  Future<void> _cancelScheduledNotifications() async {
    final ids = _prefs?.getStringList(_scheduledIdsKey) ?? const <String>[];
    for (final raw in ids) {
      final id = int.tryParse(raw);
      if (id != null) await _local.cancel(id: id);
    }
    await _prefs?.remove(_scheduledIdsKey);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final category = message.data['category'] ?? 'update';
    if (!_preferences.allowsCategory(category)) return;
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    final channel = _channelForCategory(category);
    await _local.show(
      id: _notificationId(
        message.messageId ??
            'remote:${DateTime.now().microsecondsSinceEpoch}:${title ?? ''}',
      ),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'homi_notification',
          importance: channel.importance,
          priority: channel.importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
        ),
      ),
      payload: message.data['route'] ?? 'overview',
    );
  }

  AndroidNotificationChannel _channelForCategory(String category) {
    return switch (category) {
      'household' || 'supply' || 'maintenance' => _attentionChannel,
      'task' || 'routine' => _taskChannel,
      'people' || 'heart' || 'connection' => _peopleChannel,
      'service' || 'security' => _serviceChannel,
      _ => _updatesChannel,
    };
  }

  void _routeFromMessage(RemoteMessage message, {bool holdIfNeeded = false}) {
    final route = message.data['route'];
    if (route == null || route.isEmpty) return;
    if (holdIfNeeded) {
      _pendingRoute = route;
      return;
    }
    _emitRoute(route);
  }

  void _emitRoute(String route) {
    if (_routeController.hasListener) {
      _routeController.add(route);
    } else {
      _pendingRoute = route;
    }
  }

  String? takePendingRoute() {
    final value = _pendingRoute;
    _pendingRoute = null;
    return value;
  }

  int _notificationId(String value) {
    var hash = 0x811C9DC5;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash == 0 ? 1 : hash;
  }

  Future<void> disposeService() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _routeController.close();
  }
}

class _LocalNotificationPlan {
  const _LocalNotificationPlan({
    required this.key,
    required this.when,
    required this.title,
    required this.body,
    required this.channel,
    required this.route,
  });

  final String key;
  final DateTime when;
  final String title;
  final String body;
  final AndroidNotificationChannel channel;
  final String route;
}
