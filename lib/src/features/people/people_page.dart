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
      if (mounted) setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;
    return HomiPage(
      title: 'People',
      subtitle: 'Stay connected with the people you choose.',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HomiColors.sage.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 27),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Location sharing stays in your control', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Homi will never start continuous sharing just because someone joins your household. Each person opts in on their own device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
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
                          const Text('Current status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          Text(
                            _snapshot == null ? 'Not checked yet' : 'Updated ${DateFormat.Hm().format(_snapshot!.updatedAt)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (_snapshot != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_snapshot!.isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded, size: 20),
                          const SizedBox(width: 3),
                          Text('${_snapshot!.batteryPercent}%', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                  Text('Accuracy about ${_snapshot!.accuracyMeters.round()} m', style: Theme.of(context).textTheme.bodyMedium),
                  if (user != null) ...[
                    const SizedBox(height: 8),
                    Text('Synced privately to your Homi account.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
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
        const SizedBox(height: 20),
        Text('Trusted people', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded, size: 34, color: HomiColors.muted),
                const SizedBox(height: 10),
                const Text('No trusted people yet', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  'Invites, mutual sharing controls and Places alerts are the next People pass. This first build establishes secure device location and battery snapshots.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
