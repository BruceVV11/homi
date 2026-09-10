import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/arrival_check_in.dart';
import '../../services/arrival_check_in_service.dart';
import '../../services/google_places_service.dart';
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
  final HomiGooglePlacesService _places = HomiGooglePlacesService();
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
      _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((_) {
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
      final error = widget.checkInService.lastError;
      if (error != null && error.trim().isNotEmpty) _message = error;
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
            'Trusted people could not refresh. Check your connection and try again.');
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
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _chooseGooglePlace(ArrivalPlaceKind kind) async {
    final selected = await showModalBottomSheet<HomiResolvedPlace>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GooglePlacePickerSheet(
        kind: kind,
        service: _places,
        initialAddress: widget.checkInService.config.place(kind)?.address,
      ),
    );
    if (selected == null || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.checkInService.saveGooglePlaceAs(kind, selected);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _hasReadyPlace() => widget.checkInService.config.configuredPlaces
      .any((place) => place.recipientUids.isNotEmpty);

  Future<void> _toggleCheckIns(bool value) async {
    if (_busy || widget.checkInService.busy) return;
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
      if (mounted) setState(() => _message = null);
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
              'Arrival check-ins need Location set to “Allow all the time” so Homi can notice an arrival while you are using another app. Android keeps the Homi location notification visible while this is active.',
          confirmLabel: 'Open settings',
          cancelLabel: 'Not now',
          icon: Icons.location_on_outlined,
        );
        if (open) {
          await widget.locationService.openAppSettings();
          if (!mounted) return;
          try {
            await widget.checkInService.setEnabled(true);
            if (mounted) setState(() => _message = null);
          } catch (retryError) {
            if (mounted) setState(() => _message = _friendly(retryError));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPlaceSharing(
    ArrivalPlaceKind kind,
    bool value,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await widget.checkInService.setShareAddressWithRecipients(kind, value);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
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
    if (selected == null) return;
    try {
      await widget.checkInService.setRadius(kind, selected);
      if (mounted) setState(() => _message = null);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    }
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
                                size: 42,
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
    if (result == null) return;
    try {
      await widget.checkInService.setRecipients(kind, result);
      if (mounted) setState(() => _message = null);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    }
  }

  Future<void> _removePlace(ArrivalPlaceKind kind) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove ${kind.label}?',
      message:
          'Homi will stop checking for arrivals at this saved place and remove any exact place share for it. Other live-location settings are not changed.',
      confirmLabel: 'Remove place',
      cancelLabel: 'Keep place',
      icon: Icons.location_off_outlined,
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.checkInService.removePlace(kind);
      if (mounted) setState(() => _message = null);
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    }
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
                title: 'You choose Home and Work',
                text:
                    'Search Google Maps for the correct place or use Set from here while you are physically there.',
              ),
              const _HelpPoint(
                icon: Icons.people_outline_rounded,
                title: 'You choose who gets the arrival',
                text:
                    'Each place has its own trusted people. A normal Homi connection does not automatically receive check-ins.',
              ),
              const _HelpPoint(
                icon: Icons.where_to_vote_outlined,
                title: 'Only a real arrival sends',
                text:
                    'Homi establishes whether you are inside or outside first. It sends only after you leave and later arrive again.',
              ),
              const _HelpPoint(
                icon: Icons.visibility_outlined,
                title: 'Background monitoring stays visible',
                text:
                    'Android keeps a Homi location notification visible while arrival monitoring is active. There is no hidden tracking mode.',
              ),
              const _HelpPoint(
                icon: Icons.lock_outline_rounded,
                title: 'Exact place sharing is separate',
                text:
                    'Arrival messages never include your address. Showing Home or Work in another person’s map details requires its own switch and an active location share to that person.',
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
    final busy = _busy || widget.checkInService.busy;

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
              'Tap a service to open your phone app with the South African emergency number ready. Homi does not place the call automatically.',
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
              _CheckInToggleCard(
                value: config.enabled,
                enabled: !busy,
                onChanged: _toggleCheckIns,
              ),
              if (_message != null) ...[
                const SizedBox(height: 10),
                _InlineMessage(text: _message!),
              ],
              const SizedBox(height: 22),
              Text('Saved places', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 5),
              Text(
                'Search Google Maps for the exact address or set the place from where your phone is now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              _PlaceCard(
                kind: ArrivalPlaceKind.home,
                place: config.home,
                connections: _connections,
                currentUid: _user!.uid,
                busy: busy,
                onSetHere: () => _saveCurrentLocation(ArrivalPlaceKind.home),
                onChooseAddress: () => _chooseGooglePlace(ArrivalPlaceKind.home),
                onRecipients: () => _chooseRecipients(ArrivalPlaceKind.home),
                onRadius: () => _chooseRadius(ArrivalPlaceKind.home),
                onSharePlace: (value) =>
                    _setPlaceSharing(ArrivalPlaceKind.home, value),
                onRemove: () => _removePlace(ArrivalPlaceKind.home),
              ),
              _PlaceCard(
                kind: ArrivalPlaceKind.work,
                place: config.work,
                connections: _connections,
                currentUid: _user!.uid,
                busy: busy,
                onSetHere: () => _saveCurrentLocation(ArrivalPlaceKind.work),
                onChooseAddress: () => _chooseGooglePlace(ArrivalPlaceKind.work),
                onRecipients: () => _chooseRecipients(ArrivalPlaceKind.work),
                onRadius: () => _chooseRadius(ArrivalPlaceKind.work),
                onSharePlace: (value) =>
                    _setPlaceSharing(ArrivalPlaceKind.work, value),
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
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.info_outline_rounded, size: 17),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _CheckInToggleCard extends StatelessWidget {
  const _CheckInToggleCard({
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
              child: Icon(
                value
                    ? Icons.where_to_vote_rounded
                    : Icons.where_to_vote_outlined,
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
                    'When on, Homi watches the Home and Work areas you saved in the background and sends arrivals only to the people you chose. Turning it off keeps your saved places.',
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
    required this.onChooseAddress,
    required this.onRecipients,
    required this.onRadius,
    required this.onSharePlace,
    required this.onRemove,
  });

  final ArrivalPlaceKind kind;
  final ArrivalCheckInPlace? place;
  final List<TrustedConnection> connections;
  final String currentUid;
  final bool busy;
  final VoidCallback onSetHere;
  final VoidCallback onChooseAddress;
  final VoidCallback onRecipients;
  final VoidCallback onRadius;
  final ValueChanged<bool> onSharePlace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final saved = place != null;
    final recipients = saved
        ? connections
            .where((connection) =>
                place!.recipientUids.contains(connection.otherUid(currentUid)))
            .toList(growable: false)
        : const <TrustedConnection>[];

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
                  '${place!.radiusMeters.round()} m arrival area',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Text('Arrival check-in people',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 9),
                if (recipients.isEmpty)
                  Text(
                    'No people selected yet.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: recipients
                        .map((connection) => _RecipientBadge(
                              name: connection.otherName(currentUid),
                              photoUrl: connection.otherPhotoUrl(currentUid),
                            ))
                        .toList(growable: false),
                  ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HomiColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.home_work_outlined,
                          size: 20, color: HomiColors.coral),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Show this place to selected people',
                                style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(
                              'Lets them see this exact ${kind.label} in your map details only while you are also sharing your location with them.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: place!.shareAddressWithRecipients,
                        onChanged: busy || recipients.isEmpty
                            ? null
                            : onSharePlace,
                      ),
                    ],
                  ),
                ),
                if (place!.lastNotifiedAt != null) ...[
                  const SizedBox(height: 9),
                  Text(
                    'Last arrival sent ${_timeLabel(place!.lastNotifiedAt!)}',
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
                    onPressed: busy ? null : onChooseAddress,
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: Text(saved ? 'Change address' : 'Find address'),
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

class _RecipientBadge extends StatelessWidget {
  const _RecipientBadge({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 66,
      child: Column(
        children: [
          _PersonAvatar(name: name, photoUrl: photoUrl, size: 48),
          const SizedBox(height: 5),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _GooglePlacePickerSheet extends StatefulWidget {
  const _GooglePlacePickerSheet({
    required this.kind,
    required this.service,
    this.initialAddress,
  });

  final ArrivalPlaceKind kind;
  final HomiGooglePlacesService service;
  final String? initialAddress;

  @override
  State<_GooglePlacePickerSheet> createState() =>
      _GooglePlacePickerSheetState();
}

class _GooglePlacePickerSheetState extends State<_GooglePlacePickerSheet> {
  late final TextEditingController _controller;
  Timer? _debounce;
  List<HomiPlaceSuggestion> _suggestions = const <HomiPlaceSuggestion>[];
  String? _error;
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    widget.service.startNewSession();
    _controller = TextEditingController(text: widget.initialAddress ?? '');
    if (_controller.text.trim().length >= 3 && widget.service.configured) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scheduleSearch(_controller.text);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      setState(() {
        _suggestions = const <HomiPlaceSuggestion>[];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (!widget.service.configured) return;
    _lastQuery = query;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.service.search(query);
      if (!mounted || query != _lastQuery) return;
      setState(() => _suggestions = results);
    } catch (error) {
      if (!mounted || query != _lastQuery) return;
      setState(() {
        _suggestions = const <HomiPlaceSuggestion>[];
        _error = _friendly(error);
      });
    } finally {
      if (mounted && query == _lastQuery) setState(() => _loading = false);
    }
  }

  Future<void> _select(HomiPlaceSuggestion suggestion) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolved = await widget.service.resolve(suggestion);
      if (mounted) Navigator.pop(context, resolved);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _friendly(error);
          _loading = false;
        });
      }
    }
  }

  String _friendly(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Find ${widget.kind.label}',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Start typing an address or place in South Africa, then choose the correct Google Maps result.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.streetAddress,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: '${widget.kind.label} address',
                  hintText: 'Start typing an address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: _scheduleSearch,
              ),
              if (!widget.service.configured) ...[
                const SizedBox(height: 12),
                const _InlineMessage(
                  text:
                      'Google address search is unavailable right now. You can close this and use Set from here instead.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                _InlineMessage(text: _error!),
              ],
              const SizedBox(height: 8),
              if (widget.service.configured)
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final suggestion = _suggestions[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.place_outlined,
                            color: HomiColors.coral),
                        title: Text(suggestion.primaryText),
                        subtitle: suggestion.secondaryText.trim().isEmpty
                            ? null
                            : Text(suggestion.secondaryText),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _loading ? null : () => _select(suggestion),
                      );
                    },
                  ),
                ),
              if (widget.service.configured) ...[
                const SizedBox(height: 10),
                Center(
                  child: Image(
                    image: FlutterGooglePlacesSdk.ASSET_POWERED_BY_GOOGLE_ON_WHITE,
                    height: 18,
                  ),
                ),
              ],
            ],
          ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiColors.border),
      ),
      child: Text(text),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final url = photoUrl?.trim();
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomiColors.sage.withValues(alpha: 0.28),
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: Text(initial,
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(initial,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
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
