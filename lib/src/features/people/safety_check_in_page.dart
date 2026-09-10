import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/arrival_check_in.dart';
import '../../services/arrival_check_in_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';

class SafetyCheckInPage extends StatefulWidget {
  const SafetyCheckInPage({
    required this.checkInService,
    required this.locationService,
    required this.trustedPeopleService,
    required this.firebaseReady,
    required this.onSignIn,
    super.key,
  });

  final ArrivalCheckInService checkInService;
  final LocationStatusService locationService;
  final TrustedPeopleService trustedPeopleService;
  final bool firebaseReady;
  final VoidCallback onSignIn;

  @override
  State<SafetyCheckInPage> createState() => _SafetyCheckInPageState();
}

class _SafetyCheckInPageState extends State<SafetyCheckInPage> {
  StreamSubscription<List<TrustedConnection>>? _connectionSubscription;
  StreamSubscription<User?>? _authSubscription;
  List<TrustedConnection> _connections = const <TrustedConnection>[];
  String? _message;
  bool _busy = false;

  User? get _user =>
      widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;

  @override
  void initState() {
    super.initState();
    widget.checkInService.addListener(_refresh);
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        _bindConnections();
        if (mounted) setState(() {});
      });
    }
    _bindConnections();
  }

  @override
  void dispose() {
    widget.checkInService.removeListener(_refresh);
    _connectionSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _message ??= widget.checkInService.lastError;
    });
  }

  void _bindConnections() {
    _connectionSubscription?.cancel();
    if (_user == null) {
      if (mounted) setState(() => _connections = const <TrustedConnection>[]);
      return;
    }
    _connectionSubscription = widget.trustedPeopleService
        .watchConnections()
        .listen((value) {
      if (!mounted) return;
      setState(() {
        _connections = value.where((item) => item.accepted).toList(growable: false);
      });
    }, onError: (_) {
      if (mounted) {
        setState(() => _message =
            'Trusted people could not refresh. Homi will try again automatically.');
      }
    });
  }

  Future<void> _call(String number) async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      setState(() => _message = 'This device could not open the phone app.');
    }
  }

  Future<void> _saveCurrentLocation(ArrivalPlaceKind kind) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.checkInService.saveCurrentLocationAs(kind);
      if (!mounted) return;
      setState(() => _message =
          '${kind.label} saved from your current location. Choose who should receive this check-in.');
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleCheckIns(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.checkInService.setEnabled(value);
      if (mounted) {
        setState(() => _message = value
            ? 'Arrival check-ins are on.'
            : 'Arrival check-ins are off. Your saved places stay on this phone.');
      }
    } catch (error) {
      if (!mounted) return;
      final message = _friendly(error);
      setState(() => _message = message);
      if (message.contains('Allow all the time') ||
          message.contains('Android Settings')) {
        final open = await showHomiConfirmSheet(
          context,
          title: 'Background location is needed',
          message:
              'Arrival check-ins need Android location access set to “Allow all the time” so Homi can notice an arrival while you are using another app. Android keeps the Homi live-location notification visible while this is active.',
          confirmLabel: 'Open settings',
          cancelLabel: 'Not now',
          icon: Icons.location_on_outlined,
        );
        if (open) await widget.locationService.openAppSettings();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseRadius(ArrivalPlaceKind kind) async {
    final place = widget.checkInService.config.place(kind);
    if (place == null) return;
    const choices = <double>[150, 250, 500];
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Arrival radius',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Homi sends the check-in after your phone moves from outside this area to inside it.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              HomiChoiceGroup<double>(
                values: choices,
                selected: choices.contains(place.radiusMeters)
                    ? place.radiusMeters
                    : 250,
                labelFor: (radius) => '${radius.round()} m',
                onSelected: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) await widget.checkInService.setRadius(kind, selected);
  }

  Future<void> _chooseRecipients(ArrivalPlaceKind kind) async {
    final place = widget.checkInService.config.place(kind);
    final user = _user;
    if (place == null || user == null) return;

    final selected = place.recipientUids.toSet();
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Who should know?',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 5),
                      Text(
                        'Choose trusted people who should receive your ${kind.label.toLowerCase()} arrival check-in.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: _connections.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Connect with a trusted person first, then return here to choose them.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: _connections.map((connection) {
                            final uid = connection.otherUid(user.uid);
                            return CheckboxListTile(
                              value: selected.contains(uid),
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    if (selected.length < 10) selected.add(uid);
                                  } else {
                                    selected.remove(uid);
                                  }
                                });
                              },
                              secondary: _PersonAvatar(
                                name: connection.otherName(user.uid),
                                photoUrl: connection.otherPhotoUrl(user.uid),
                              ),
                              title: Text(connection.otherName(user.uid)),
                              subtitle: const Text('Trusted Homi connection'),
                            );
                          }).toList(growable: false),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, selected),
                      child: const Text('Save people'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null) {
      await widget.checkInService.setRecipients(kind, result);
    }
  }

  Future<void> _removePlace(ArrivalPlaceKind kind) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove ${kind.label}?',
      message:
          'Homi will stop checking for arrivals at this saved place. Other location-sharing settings are not changed.',
      confirmLabel: 'Remove place',
      cancelLabel: 'Keep place',
      icon: Icons.location_off_outlined,
      destructive: true,
    );
    if (confirmed) await widget.checkInService.removePlace(kind);
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.checkInService.config;
    final signedIn = _user != null;

    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Safety & check-ins'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Text('Emergency calls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              'South African emergency numbers. Tapping a service opens your phone app with the number ready to call.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            _EmergencyCallCard(
              icon: Icons.emergency_outlined,
              title: 'Emergency',
              detail: '112 · from a mobile phone',
              onTap: () => _call('112'),
            ),
            _EmergencyCallCard(
              icon: Icons.local_police_outlined,
              title: 'Police emergency',
              detail: '10111',
              onTap: () => _call('10111'),
            ),
            _EmergencyCallCard(
              icon: Icons.medical_services_outlined,
              title: 'Ambulance emergency',
              detail: '10177',
              onTap: () => _call('10177'),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Homi does not dispatch emergency services and does not automatically send your location to responders. Calls are handled by your phone and network.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 26),
            Text('Arrival check-ins', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              'Let selected trusted people know when you arrive at the Home or Work location you save.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (!signedIn)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sign in for arrival check-ins',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text(
                        'Check-ins are sent only to trusted Homi connections you choose.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: widget.onSignIn,
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _MasterCheckInCard(
                enabled: config.enabled,
                busy: _busy || widget.checkInService.busy,
                onChanged: _toggleCheckIns,
              ),
              const SizedBox(height: 12),
              _PlaceCard(
                kind: ArrivalPlaceKind.home,
                place: config.home,
                connections: _connections,
                currentUid: _user!.uid,
                busy: _busy,
                onSetHere: () => _saveCurrentLocation(ArrivalPlaceKind.home),
                onRecipients: () => _chooseRecipients(ArrivalPlaceKind.home),
                onRadius: () => _chooseRadius(ArrivalPlaceKind.home),
                onRemove: () => _removePlace(ArrivalPlaceKind.home),
              ),
              _PlaceCard(
                kind: ArrivalPlaceKind.work,
                place: config.work,
                connections: _connections,
                currentUid: _user!.uid,
                busy: _busy,
                onSetHere: () => _saveCurrentLocation(ArrivalPlaceKind.work),
                onRecipients: () => _chooseRecipients(ArrivalPlaceKind.work),
                onRadius: () => _chooseRadius(ArrivalPlaceKind.work),
                onRemove: () => _removePlace(ArrivalPlaceKind.work),
              ),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: HomiColors.sage.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Home and Work coordinates stay on this phone. Homi sends only an arrival event and the place label to the selected trusted people. No route history is created by check-ins. Android keeps the Homi live-location notification visible while background check-ins are active.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HomiColors.peach.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(_message!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _friendly(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');
}

class _EmergencyCallCard extends StatelessWidget {
  const _EmergencyCallCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HomiColors.coral.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: HomiColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.call_rounded, color: HomiColors.coral),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterCheckInCard extends StatelessWidget {
  const _MasterCheckInCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HomiColors.sage.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.where_to_vote_outlined,
                  color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled ? 'Check-ins are on' : 'Check-ins are off',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Uses Homi live location to notice configured arrivals.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: busy ? null : onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.kind,
    required this.place,
    required this.connections,
    required this.currentUid,
    required this.busy,
    required this.onSetHere,
    required this.onRecipients,
    required this.onRadius,
    required this.onRemove,
  });

  final ArrivalPlaceKind kind;
  final ArrivalCheckInPlace? place;
  final List<TrustedConnection> connections;
  final String currentUid;
  final bool busy;
  final VoidCallback onSetHere;
  final VoidCallback onRecipients;
  final VoidCallback onRadius;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final saved = place != null;
    final recipientNames = saved
        ? connections
            .where((connection) =>
                place!.recipientUids.contains(connection.otherUid(currentUid)))
            .map((connection) => connection.otherName(currentUid))
            .toList(growable: false)
        : const <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    kind == ArrivalPlaceKind.home
                        ? Icons.home_rounded
                        : Icons.work_outline_rounded,
                    color: HomiColors.coral,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(kind.label,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  if (saved)
                    IconButton(
                      tooltip: 'Remove ${kind.label}',
                      onPressed: onRemove,
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                saved
                    ? '${place!.radiusMeters.round()} m arrival area'
                    : 'Set this place when you are physically there.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (saved) ...[
                const SizedBox(height: 5),
                Text(
                  recipientNames.isEmpty
                      ? 'No trusted people selected yet'
                      : recipientNames.length <= 2
                          ? 'Notifies ${recipientNames.join(' and ')}'
                          : 'Notifies ${recipientNames.length} trusted people',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: HomiColors.muted,
                  ),
                ),
                if (place!.lastNotifiedAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Last check-in sent ${_timeLabel(place!.lastNotifiedAt!)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: HomiColors.muted,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : onSetHere,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: Text(saved ? 'Update location' : 'Set from here'),
                  ),
                  if (saved) ...[
                    OutlinedButton.icon(
                      onPressed: onRecipients,
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      label: const Text('People'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onRadius,
                      icon: const Icon(Icons.radar_rounded, size: 18),
                      label: const Text('Radius'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final now = DateTime.now();
    final local = value.toLocal();
    if (now.year == local.year &&
        now.month == local.month &&
        now.day == local.day) {
      return 'today at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} at ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return CircleAvatar(
      radius: 20,
      backgroundColor: HomiColors.sage.withValues(alpha: 0.28),
      backgroundImage: url != null && url.isNotEmpty ? NetworkImage(url) : null,
      child: url == null || url.isEmpty
          ? Text(
              name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
              style: const TextStyle(
                color: HomiColors.slate,
                fontWeight: FontWeight.w900,
              ),
            )
          : null,
    );
  }
}
