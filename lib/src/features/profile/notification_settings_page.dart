import 'package:flutter/material.dart';

import '../../domain/notification_preferences.dart';
import '../../services/notification_service.dart';
import '../../theme/homi_theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    required this.notificationService,
    super.key,
  });

  final HomiNotificationService notificationService;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _message;

  HomiNotificationPreferences get _preferences =>
      widget.notificationService.preferences;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.notificationService.addListener(_refresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.notificationService.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.notificationService.refreshPermissionState();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _enable() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final granted = await widget.notificationService.requestPermissionAndEnable();
      if (!mounted) return;
      setState(() {
        _message = granted
            ? null
            : 'Android did not grant notification permission. You can enable Homi notifications later from Android settings.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setMaster(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.notificationService.setEnabled(value);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(HomiNotificationPreferences value) async {
    await widget.notificationService.updatePreferences(value);
  }

  Future<void> _retryPushDelivery() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ready = await widget.notificationService.refreshDeviceRegistration();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = ready
          ? 'Remote notification delivery is ready on this device.'
          : widget.notificationService.pushRegistrationError ??
              'Homi could not register this device for remote notifications yet.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    final active = preferences.enabled &&
        widget.notificationService.osPermissionGranted;

    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: active
                    ? HomiColors.sage.withValues(alpha: 0.20)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: HomiColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: HomiColors.peach.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      active
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none_rounded,
                      color: HomiColors.coral,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active
                              ? 'Notifications are on'
                              : 'Choose when Homi may notify you',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Homi keeps notifications focused on useful household attention, responsibilities, trusted people and important service notices.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (!active)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _enable,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(_busy ? 'Please wait…' : 'Enable notifications'),
                ),
              )
            else
              _PreferenceCard(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications on this device',
                subtitle:
                    'Turn this off without changing Homi on your other devices.',
                value: preferences.enabled,
                onChanged: _busy ? null : _setMaster,
              ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HomiColors.peach.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(_message!),
              ),
            ],
            if (active) ...[
              const SizedBox(height: 12),
              _PushDeliveryStatusCard(
                ready: widget.notificationService.pushRegistrationReady,
                busy: widget.notificationService.pushRegistrationInFlight,
                error: widget.notificationService.pushRegistrationError,
                onRetry: _busy ? null : _retryPushDelivery,
              ),
            ],
            const SizedBox(height: 22),
            Text('What can notify me?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (!active)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Text(
                  'Turn notifications on before choosing which categories may notify you.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            _PreferenceCard(
              icon: Icons.home_outlined,
              title: 'Household attention',
              subtitle:
                  'Out-of-stock supplies, expiry warnings and saved maintenance dates.',
              value: preferences.householdAttention,
              enabled: active,
              onChanged: (value) =>
                  _save(_preferences.copyWith(householdAttention: value)),
            ),
            _PreferenceCard(
              icon: Icons.task_alt_outlined,
              title: 'Tasks & routines',
              subtitle:
                  'Due one-off tasks and recurring responsibilities that have a due time.',
              value: preferences.tasksAndRoutines,
              enabled: active,
              onChanged: (value) =>
                  _save(_preferences.copyWith(tasksAndRoutines: value)),
            ),
            _PreferenceCard(
              icon: Icons.favorite_outline_rounded,
              title: 'People',
              subtitle:
                  'Connection activity and small check-ins such as “thinking about you”.',
              value: preferences.people,
              enabled: active,
              onChanged: (value) =>
                  _save(_preferences.copyWith(people: value)),
            ),
            _PreferenceCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Homi updates',
              subtitle:
                  'Useful product announcements. Homi does not use this category for routine household reminders.',
              value: preferences.homiUpdates,
              enabled: active,
              onChanged: (value) =>
                  _save(_preferences.copyWith(homiUpdates: value)),
            ),
            _PreferenceCard(
              icon: Icons.shield_outlined,
              title: 'Service & security',
              subtitle:
                  'Important Homi maintenance, availability and account/security notices.',
              value: preferences.serviceNotices,
              enabled: active,
              onChanged: (value) =>
                  _save(_preferences.copyWith(serviceNotices: value)),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HomiColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Designed not to nag',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Homi schedules only the next useful due reminders, groups new critical supply attention where practical, and uses 09:00 for expiry and maintenance reminders instead of waking you overnight. Android may deliver scheduled notifications a little later when the phone is conserving power.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final canToggle = enabled && onChanged != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: canToggle ? 1 : 0.42,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canToggle ? () => onChanged!(!value) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: HomiColors.coral, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                  Switch(
                    value: value,
                    onChanged: canToggle ? onChanged : null,
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

class _PushDeliveryStatusCard extends StatelessWidget {
  const _PushDeliveryStatusCard({
    required this.ready,
    required this.busy,
    required this.error,
    required this.onRetry,
  });

  final bool ready;
  final bool busy;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final title = busy
        ? 'Connecting remote notifications…'
        : ready
            ? 'Remote notifications ready'
            : 'Remote notifications need attention';
    final message = busy
        ? 'Homi is registering this phone securely for connection, Household and account notifications.'
        : ready
            ? 'This phone is registered to receive Homi push notifications.'
            : error ??
                'Homi has permission to notify you, but this phone has not completed remote notification registration yet.';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ready
            ? HomiColors.sage.withValues(alpha: 0.14)
            : HomiColors.peach.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(
              ready
                  ? Icons.check_circle_outline_rounded
                  : Icons.notifications_off_outlined,
              color: ready ? const Color(0xFF6F8B65) : HomiColors.coral,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodyMedium),
                if (!ready && !busy && onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry notification delivery'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
