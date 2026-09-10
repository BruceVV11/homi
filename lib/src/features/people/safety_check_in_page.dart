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
      final place = await widget.checkInService.saveCurrentLocationAs(kind);
      if (!mounted) return;
      setState(() => _message =
          '${kind.label} set to ${place.address ?? 'your current location'}.');
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enterAddress(ArrivalPlaceKind kind) async {
    final existing = widget.checkInService.config.place(kind);
    final address = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddressEntrySheet(
        kind: kind,
        initialAddress: existing?.address,
      ),
    );
    if (address == null || address.trim().isEmpty || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final place = await widget.checkInService.saveAddressAs(kind, address);
      if (!mounted) return;
      setState(() => _message =
          '${kind.label} set to ${place.address ?? address.trim()}.');
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _hasReadyPlace() => widget.checkInService.config.configuredPlaces
      .any((place) => place.recipientUids.isNotEmpty);

  Future<void> _toggleCheckIns(bool value) async {
    if (_busy) return;
    if (value && !_hasReadyPlace()) {
      setState(() => _message =
          'Set Home or Work and choose at least one trusted person before turning arrival check-ins on.');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.checkInService.setEnabled(value);
      if (!mounted) return;
      setState(() => _message = value
          ? 'Arrival check-ins are on.'
          : 'Arrival check-ins are off. Your saved places stay on this phone.');
    } catch (error) {
      if (!mounted) return;
      final message = _friendly(error);
      setState(() => _message = message);
      final needsSettings = message.contains('Allow all the time') ||
          message.contains('Android Settings');
      if (value && needsSettings) {
        final open = await showHomiConfirmSheet(
          context,
          title: 'Allow background location',
          message:
              'Arrival check-ins need Location set to “Allow all the time” so Homi can notice an arrival while you are using another app.',
          confirmLabel: 'Open settings',
          cancelLabel: 'Not now',
          icon: Icons.location_on_outlined,
        );
        if (open) {
          await widget.locationService.openAppSettings();
          if (!mounted) return;
          try {
            await widget.checkInService.setEnabled(true);
            if (mounted) {
              setState(() => _message = 'Arrival check-ins are on.');
            }
          } catch (retryError) {
            if (mounted) setState(() => _message = _friendly(retryError));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseRadius(ArrivalPlaceKind kind) async {
    final place = widget.checkInService.config.place(kind);
    if (place == null) return;
    const choices = <double>[150, 250, 500];
    var selectedRadius = choices.contains(place.radiusMeters)
        ? place.radiusMeters
        : 250.0;
    final selected = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
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
                  'Choose how close your phone needs to be before Homi treats you as having arrived.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                HomiChoiceGroup<double>(
                  values: choices,
                  selected: selectedRadius,
                  labelFor: (value) => '${value.round()} m',
                  onSelected: (value) =>
                      setSheetState(() => selectedRadius = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, selectedRadius),
                    child: const Text('Save radius'),
                  ),
                ),
              ],
            ),
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

  void _showHowItWorks() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How arrival check-ins work',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              const _HelpPoint(
                icon: Icons.home_work_outlined,
                title: 'You choose the places',
                text:
                    'Set Home or Work by entering an address or by using your current location while you are there.',
              ),
              const _HelpPoint(
                icon: Icons.people_outline_rounded,
                title: 'You choose who is notified',
                text:
                    'Each saved place has its own trusted recipients. Connecting with someone does not automatically add them.',
              ),
              const _HelpPoint(
                icon: Icons.where_to_vote_outlined,
                title: 'Only a real arrival sends',
                text:
                    'Homi first establishes whether you are inside or outside the saved area. It sends only after you leave and later arrive again.',
              ),
              const _HelpPoint(
                icon: Icons.visibility_outlined,
                title: 'Background use stays visible',
                text:
                    'Android keeps a Homi location notification visible while arrival monitoring is active. There is no hidden tracking mode.',
              ),
              const _HelpPoint(
                icon: Icons.lock_outline_rounded,
                title: 'Saved addresses stay on this phone',
                text:
                    'The arrival notification sends only Home or Work and the selected trusted recipients. It does not send your saved address or coordinates.',
              ),
              const SizedBox(height: 4),
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
    final config = widget.checkInService.config;
    final signedIn = _user != null;
    final active = config.enabled;

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          children: [
            Text('Emergency calls', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              'Tapping a service opens your phone app with the South African emergency number ready. Homi does not place the call automatically.',
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
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Arrival check-ins',
              actionLabel: 'How it works',
              onAction: _showHowItWorks,
            ),
            const SizedBox(height: 5),
            Text(
              'Let selected trusted people know when you arrive at Home or Work.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (!signedIn)
              _SignedOutCard(onSignIn: widget.onSignIn)
            else ...[
              _CheckInHero(active: active),
              const SizedBox(height: 14),
              if (!active)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy || widget.checkInService.busy
                        ? null
                        : () => _toggleCheckIns(true),
                    icon: const Icon(Icons.where_to_vote_outlined),
                    label: Text(
                      _busy || widget.checkInService.busy
                          ? 'Please wait…'
                          : 'Enable arrival check-ins',
                    ),
                  ),
                )
              else
                _CheckInPreferenceCard(
                  value: true,
                  enabled: !_busy && !widget.checkInService.busy,
                  onChanged: _toggleCheckIns,
                ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                _InlineMessage(text: _message!),
              ],
              const SizedBox(height: 22),
              Text('Saved places', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                'Use a real address or set the place from where your phone is now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              _PlaceCard(
                kind: ArrivalPlaceKind.home,
                place: config.home,
                connections: _connections,
                currentUid: _user!.uid,
                busy: _busy,
                onSetHere: () => _saveCurrentLocation(ArrivalPlaceKind.home),
                onEnterAddress: () => _enterAddress(ArrivalPlaceKind.home),
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
                onEnterAddress: () => _enterAddress(ArrivalPlaceKind.work),
                onRecipients: () => _chooseRecipients(ArrivalPlaceKind.work),
                onRadius: () => _chooseRadius(ArrivalPlaceKind.work),
                onRemove: () => _removePlace(ArrivalPlaceKind.work),
              ),
            ],
            if (!signedIn && _message != null) ...[
              const SizedBox(height: 12),
              _InlineMessage(text: _message!),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _CheckInHero extends StatelessWidget {
  const _CheckInHero({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: active ? HomiColors.sage.withValues(alpha: 0.20) : Colors.white,
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
              active ? Icons.where_to_vote_rounded : Icons.location_on_outlined,
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
                      ? 'Arrival check-ins are on'
                      : 'Choose when Homi may check you in',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                Text(
                  'Homi watches only the Home and Work places you configure and notifies only the trusted people you choose.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInPreferenceCard extends StatelessWidget {
  const _CheckInPreferenceCard({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              child: const Icon(
                Icons.where_to_vote_outlined,
                color: HomiColors.coral,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Arrival check-ins on this device',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    'Turn this off without deleting your saved Home or Work places.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: enabled ? onChanged : null),
          ],
        ),
      ),
    );
  }
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

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sign in for arrival check-ins',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              'Emergency call shortcuts stay available without an account. Arrival check-ins use your trusted Homi connections.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
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
    required this.onEnterAddress,
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
  final VoidCallback onEnterAddress;
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
                    TextButton(
                      onPressed: busy ? null : onRemove,
                      child: const Text('Remove'),
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                saved
                    ? (place!.address ??
                        '${place!.latitude.toStringAsFixed(5)}, ${place!.longitude.toStringAsFixed(5)}')
                    : 'No address saved yet.',
                style: TextStyle(
                  fontWeight: saved ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
              if (saved) ...[
                const SizedBox(height: 5),
                Text(
                  '${place!.radiusMeters.round()} m arrival area · ${recipientNames.isEmpty ? 'no people selected' : recipientNames.length == 1 ? 'notifies ${recipientNames.first}' : 'notifies ${recipientNames.length} people'}',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                    onPressed: busy ? null : onEnterAddress,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(saved ? 'Change address' : 'Enter address'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onSetHere,
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text('Set from here'),
                  ),
                  if (saved) ...[
                    OutlinedButton.icon(
                      onPressed: busy ? null : onRecipients,
                      icon: const Icon(Icons.people_outline_rounded, size: 18),
                      label: const Text('People'),
                    ),
                    OutlinedButton.icon(
                      onPressed: busy ? null : onRadius,
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

class _AddressEntrySheet extends StatefulWidget {
  const _AddressEntrySheet({required this.kind, this.initialAddress});

  final ArrivalPlaceKind kind;
  final String? initialAddress;

  @override
  State<_AddressEntrySheet> createState() => _AddressEntrySheetState();
}

class _AddressEntrySheetState extends State<_AddressEntrySheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAddress ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.length < 4) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set ${widget.kind.label} address',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Enter a street address, suburb and city, or a recognised place name. Homi resolves it to a map location before saving it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: '${widget.kind.label} address',
                hintText: '12 Long Street, Cape Town',
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find and use this address'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Text(text),
    );
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

class _HelpPoint extends StatelessWidget {
  const _HelpPoint({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HomiColors.peach.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: HomiColors.coral),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}