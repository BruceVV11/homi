import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/location_status_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({required this.firebaseReady, super.key});

  final bool firebaseReady;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  late final LocationStatusService _locationService;
  LocationStatusSnapshot? _snapshot;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _locationService = LocationStatusService(firebaseReady: widget.firebaseReady);
  }

  Future<void> _capture() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await _locationService.captureCurrentStatus();
      if (mounted) setState(() => _snapshot = snapshot);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showLocationPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HomiColors.sage.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.shield_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Location stays in your control',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _PrivacyPoint(
                icon: Icons.touch_app_outlined,
                text: 'Sharing is always opt-in on the device being shared.',
              ),
              const _PrivacyPoint(
                icon: Icons.person_add_alt_1_outlined,
                text: 'Adding or inviting someone never starts tracking automatically.',
              ),
              const _PrivacyPoint(
                icon: Icons.location_searching_rounded,
                text: 'This build stores the latest location and battery snapshot, not a movement history.',
              ),
              const _PrivacyPoint(
                icon: Icons.stop_circle_outlined,
                text: 'Future continuous sharing must stay visible and easy to stop at any time.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;
    return HomiPage(
      title: 'People',
      subtitle: 'Stay connected with the people you choose.',
      children: [
        Text('This phone', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.location_on_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Current status',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            _snapshot == null
                                ? 'Not checked yet'
                                : 'Updated ${DateFormat.Hm().format(_snapshot!.updatedAt)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_snapshot != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _snapshot!.isCharging
                                ? Icons.battery_charging_full_rounded
                                : Icons.battery_std_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_snapshot!.batteryPercent}%',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_snapshot != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '${_snapshot!.latitude.toStringAsFixed(5)}, ${_snapshot!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Accuracy about ${_snapshot!.accuracyMeters.round()} m',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Synced privately to your Homi account.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _capture,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(_busy ? 'Checking…' : 'Check my location'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showLocationPrivacy(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 19, color: HomiColors.muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Location sharing is always opt-in. See how Homi handles it.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: HomiColors.muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('Trusted people', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: HomiColors.sage.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.people_outline_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('No trusted people yet', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        'Invites and mutual sharing controls will build on the secure location foundation already in place.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: HomiColors.coral),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
