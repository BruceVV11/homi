import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/arrival_check_in_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
import '../../widgets/homi_page.dart';
import 'people_map_page.dart';
import 'safety_check_in_page.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({
    required this.locationService,
    required this.trustedPeopleService,
    required this.checkInService,
    required this.firebaseReady,
    required this.onSignIn,
    super.key,
  });

  final LocationStatusService locationService;
  final TrustedPeopleService trustedPeopleService;
  final ArrivalCheckInService checkInService;
  final bool firebaseReady;
  final VoidCallback onSignIn;

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage>
    with AutomaticKeepAliveClientMixin<PeoplePage> {
  final Geocoding _geocoding = Geocoding();
  final Map<String, BitmapDescriptor> _markerIcons = <String, BitmapDescriptor>{};
  final Map<String, TrustedPersonLocation?> _locations =
      <String, TrustedPersonLocation?>{};
  final Map<String, bool> _theyShareToMe = <String, bool>{};
  final Map<String, StreamSubscription<bool>> _shareSubscriptions =
      <String, StreamSubscription<bool>>{};
  final Map<String, StreamSubscription<TrustedPersonLocation?>>
      _locationSubscriptions =
      <String, StreamSubscription<TrustedPersonLocation?>>{};

  StreamSubscription<LocationStatusSnapshot>? _selfSubscription;
  StreamSubscription<List<TrustedConnection>>? _connectionSubscription;
  StreamSubscription<Map<String, TrustedPersonPreference>>?
      _preferenceSubscription;
  GoogleMapController? _mapController;
  LocationStatusSnapshot? _selfSnapshot;
  List<TrustedConnection> _connections = const <TrustedConnection>[];
  Map<String, TrustedPersonPreference> _preferences =
      const <String, TrustedPersonPreference>{};
  HomiIdentity? _identity;
  String? _error;
  String? _focusedPersonId;
  bool _busy = false;
  bool _syncBusy = false;
  bool _liveSharingActive = false;

  @override
  bool get wantKeepAlive => true;

  User? get _user =>
      widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;

  String get _selfName {
    final user = _user;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'You';
  }

  @override
  void initState() {
    super.initState();
    _selfSnapshot = widget.locationService.latest;
    _liveSharingActive = widget.locationService.isStreaming;
    _focusedPersonId = _selfSnapshot == null ? null : 'self';
    _selfSubscription = widget.locationService.updates.listen((snapshot) {
      if (!mounted) return;
      setState(() => _selfSnapshot = snapshot);
      if (_focusedPersonId == null || _focusedPersonId == 'self') {
        unawaited(_moveMapTo(snapshot.latitude, snapshot.longitude));
      }
    });
    widget.checkInService.addListener(_refreshCheckInStatus);
    unawaited(_initialise());
  }

  void _refreshCheckInStatus() {
    if (mounted) setState(() {});
  }

  Future<void> _initialise() async {
    final cached = await widget.locationService.loadCachedStatus();
    if (mounted && cached != null) {
      final current = _selfSnapshot;
      if (current == null || cached.updatedAt.isAfter(current.updatedAt)) {
        setState(() => _selfSnapshot = cached);
      }
      _focusedPersonId ??= 'self';
    }
    await _ensureMarker('self', _selfName, _user?.photoURL);

    try {
      final refreshed = await widget.locationService.refreshIfAlreadyAllowed();
      if (mounted && refreshed != null) {
        setState(() => _selfSnapshot = refreshed);
      }
    } catch (_) {
      // Keep the last known location visible while a passive refresh retries.
    }

    try {
      final resumed =
          await widget.locationService.resumeContinuousSharingIfEnabled();
      if (mounted) {
        setState(() => _liveSharingActive =
            resumed || widget.locationService.isStreaming);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _liveSharingActive = widget.locationService.isStreaming);
      }
    }

    if (_user != null) {
      await _bindTrustedPeople(ensureIdentity: true);
    }
  }

  @override
  void dispose() {
    widget.checkInService.removeListener(_refreshCheckInStatus);
    _selfSubscription?.cancel();
    _cancelTrustedCore();
    for (final subscription in _shareSubscriptions.values) {
      subscription.cancel();
    }
    for (final subscription in _locationSubscriptions.values) {
      subscription.cancel();
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _cancelTrustedCore() {
    _connectionSubscription?.cancel();
    _preferenceSubscription?.cancel();
    _connectionSubscription = null;
    _preferenceSubscription = null;
  }

  Future<void> _bindTrustedPeople({bool ensureIdentity = false}) async {
    if (_user == null) return;
    _cancelTrustedCore();
    if (mounted) {
      setState(() {
        _syncBusy = true;
        _error = null;
      });
    }

    if (ensureIdentity) {
      try {
        final identity = await widget.trustedPeopleService.ensureIdentity();
        if (mounted) setState(() => _identity = identity);
      } catch (error) {
        if (mounted) setState(() => _error = _friendly(error));
      }
    }

    _connectionSubscription = widget.trustedPeopleService
        .watchConnections()
        .listen(_syncConnections, onError: (Object error) {
      if (!mounted) return;
      setState(() {
        _syncBusy = false;
        _error = _friendly(error);
      });
    });
    _preferenceSubscription = widget.trustedPeopleService
        .watchPreferences()
        .listen((value) {
      if (!mounted) return;
      setState(() {
        _preferences = value;
        _syncBusy = false;
      });
    }, onError: (Object error) {
      if (!mounted) return;
      setState(() {
        _syncBusy = false;
        _error = _friendly(error);
      });
    });
  }

  Future<void> _retryTrustedPeople() =>
      _bindTrustedPeople(ensureIdentity: _identity == null);

  void _syncConnections(List<TrustedConnection> connections) {
    final currentUid = _user?.uid;
    if (currentUid == null) return;
    final activeOtherUids = connections
        .where((item) => item.accepted)
        .map((item) => item.otherUid(currentUid))
        .toSet();

    for (final uid in _shareSubscriptions.keys.toList()) {
      if (!activeOtherUids.contains(uid)) {
        _shareSubscriptions.remove(uid)?.cancel();
        _locationSubscriptions.remove(uid)?.cancel();
        _locations.remove(uid);
        _theyShareToMe.remove(uid);
      }
    }

    for (final connection in connections.where((item) => item.accepted)) {
      final otherUid = connection.otherUid(currentUid);
      unawaited(
        _ensureMarker(
          otherUid,
          connection.otherName(currentUid),
          connection.otherPhotoUrl(currentUid),
        ),
      );
      _shareSubscriptions.putIfAbsent(
        otherUid,
        () => widget.trustedPeopleService
            .watchTheirShareToMe(otherUid)
            .listen((active) {
          if (!mounted) return;
          setState(() {
            _theyShareToMe[otherUid] = active;
            if (!active) _locations.remove(otherUid);
          });
          if (active) _listenToLocation(otherUid);
          if (!active) _locationSubscriptions.remove(otherUid)?.cancel();
        }, onError: (_) {
          if (mounted) setState(() => _theyShareToMe[otherUid] = false);
        }),
      );
    }

    if (mounted) {
      setState(() {
        _connections = connections;
        _syncBusy = false;
        _error = null;
      });
    }
  }

  void _listenToLocation(String uid) {
    if (_locationSubscriptions.containsKey(uid)) return;
    _locationSubscriptions[uid] = widget.trustedPeopleService
        .watchLocation(uid)
        .listen((location) {
      if (!mounted) return;
      setState(() => _locations[uid] = location);
    }, onError: (_) {
      // Keep the last successfully received location rather than replacing it
      // with an empty state during a transient refresh failure.
    });
  }

  Future<void> _enableForegroundLocation() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.locationService.captureCurrentStatus();
      if (mounted) {
        setState(() {
          _selfSnapshot = snapshot;
          _focusedPersonId = 'self';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _turnOnLiveSharing() async {
    if (_user == null) {
      widget.onSignIn();
      return;
    }
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.locationService.startContinuousSharing();
      if (mounted) setState(() => _liveSharingActive = true);
    } catch (error) {
      if (!mounted) return;
      final message = _friendly(error);
      setState(() => _error = message);
      final needsSettings = message.contains('Allow all the time') ||
          message.contains('Android Settings');
      if (needsSettings) {
        final open = await showHomiConfirmSheet(
          context,
          title: 'Background location needs permission',
          message:
              'Android only allows Homi to keep updating while the app is in the background when Location is set to “Allow all the time”. Homi keeps a visible notification while live sharing is active.',
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

  Future<void> _turnOffLiveSharing() async {
    await widget.locationService.stopContinuousSharing();
    if (mounted) setState(() => _liveSharingActive = false);
  }

  Future<void> _connectWithCode() async {
    if (_user == null) {
      widget.onSignIn();
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ConnectPersonSheet(
        service: widget.trustedPeopleService,
      ),
    );
    if (sent == true && mounted) {
      setState(() => _error = null);
    }
  }

  Future<void> _editPreference(TrustedConnection connection) async {
    final currentUid = _user?.uid;
    if (currentUid == null) return;
    final otherUid = connection.otherUid(currentUid);
    final current =
        _preferences[otherUid] ?? TrustedPersonPreference.fallback;
    final result = await showModalBottomSheet<TrustedPersonPreference>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RelationshipSheet(
        name: connection.otherName(currentUid),
        initial: current,
      ),
    );
    if (result == null) return;
    try {
      await widget.trustedPeopleService.setPreference(
        otherUid: otherUid,
        relationship: result.relationship,
        scope: result.scope,
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    }
  }

  Future<void> _openSafety() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SafetyCheckInPage(
          checkInService: widget.checkInService,
          locationService: widget.locationService,
          trustedPeopleService: widget.trustedPeopleService,
          firebaseReady: widget.firebaseReady,
          onSignIn: widget.onSignIn,
        ),
      ),
    );
  }

  void _showLocationFaq() {
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
              Text(
                'How Homi location works',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const _FaqPoint(
                icon: Icons.touch_app_outlined,
                title: 'You decide when sharing starts',
                text:
                    'Connecting with someone and sharing your location are separate choices. A connection never starts tracking by itself.',
              ),
              const _FaqPoint(
                icon: Icons.people_outline_rounded,
                title: 'Friends can stay location-only',
                text:
                    'You can label a person as a friend and keep the connection location-only. That does not give them access to Home, supplies, routines or other household records.',
              ),
              const _FaqPoint(
                icon: Icons.notifications_active_outlined,
                title: 'Background sharing stays visible',
                text:
                    'When live sharing is on, Android keeps a Homi location notification visible. This allows updates to continue while you use other apps.',
              ),
              const _FaqPoint(
                icon: Icons.battery_saver_outlined,
                title: 'Designed to be light on battery',
                text:
                    'Homi uses medium accuracy, a movement threshold and spaced updates rather than requesting maximum-accuracy GPS continuously.',
              ),
              const _FaqPoint(
                icon: Icons.history_toggle_off_rounded,
                title: 'Latest status, not a default travel history',
                text:
                    'Homi stores the latest shared location and battery status by default. A movement history is not kept automatically.',
              ),
              const _FaqPoint(
                icon: Icons.stop_circle_outlined,
                title: 'Easy to stop',
                text:
                    'You can stop live updates or stop sharing with one person independently at any time.',
              ),
              const SizedBox(height: 6),
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

  Future<void> _showLocationDetails({
    required String name,
    required String? photoUrl,
    required double latitude,
    required double longitude,
    required int batteryPercent,
    required bool isCharging,
    required DateTime? updatedAt,
    required double accuracyMeters,
  }) async {
    String address = 'Address unavailable';
    try {
      final placemarks = await _geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = <String?>[
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
        ]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .toSet()
            .join(', ');
        if (address.isEmpty) address = 'Address unavailable';
      }
    } catch (_) {
      // Coordinates remain available if reverse geocoding is unavailable.
    }
    if (!mounted) return;

    final coordinates =
        '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _LocationDetailsSheet(
        name: name,
        photoUrl: photoUrl,
        address: address,
        coordinates: coordinates,
        latitude: latitude,
        longitude: longitude,
        batteryPercent: batteryPercent,
        isCharging: isCharging,
        updatedAt: updatedAt,
        accuracyMeters: accuracyMeters,
      ),
    );
  }

  Future<void> _showMapPerson(HomiMapPerson person) => _showLocationDetails(
        name: person.name,
        photoUrl: person.photoUrl,
        latitude: person.position.latitude,
        longitude: person.position.longitude,
        batteryPercent: person.batteryPercent,
        isCharging: person.isCharging,
        updatedAt: person.updatedAt,
        accuracyMeters: person.accuracyMeters,
      );

  Future<void> _ensureMarker(
    String id,
    String name,
    String? photoUrl,
  ) async {
    if (_markerIcons.containsKey(id)) return;
    final marker = await _buildAvatarMarker(name, photoUrl);
    if (!mounted) return;
    setState(() => _markerIcons[id] = marker);
  }

  Future<BitmapDescriptor> _buildAvatarMarker(
    String name,
    String? photoUrl,
  ) async {
    const pixelSize = 120;
    const logicalSize = 54.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(pixelSize / 2, pixelSize / 2);
    const outerRadius = pixelSize / 2.0;
    const innerRadius = 49.0;

    canvas.drawCircle(center, outerRadius, Paint()..color = HomiColors.coral);
    canvas.drawCircle(center, innerRadius, Paint()..color = Colors.white);

    ui.Image? photo;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      try {
        final data = await NetworkAssetBundle(Uri.parse(photoUrl)).load(photoUrl);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(),
          targetWidth: 96,
          targetHeight: 96,
        );
        final frame = await codec.getNextFrame();
        photo = frame.image;
      } catch (_) {
        photo = null;
      }
    }

    if (photo != null) {
      final clipPath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: 47));
      canvas.save();
      canvas.clipPath(clipPath);
      paintImage(
        canvas: canvas,
        rect: Rect.fromCircle(center: center, radius: 47),
        image: photo,
        fit: BoxFit.cover,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, 47, Paint()..color = HomiColors.cream);
      final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
      final painter = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w900,
            color: HomiColors.slate,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          center.dx - painter.width / 2,
          center.dy - painter.height / 2,
        ),
      );
    }

    final image = await recorder.endRecording().toImage(pixelSize, pixelSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: logicalSize,
      height: logicalSize,
    );
  }

  List<HomiMapPerson> _mapPeople() {
    final people = <HomiMapPerson>[];
    final self = _selfSnapshot;
    final selfIcon = _markerIcons['self'];
    if (self != null && selfIcon != null) {
      people.add(
        HomiMapPerson(
          id: 'self',
          name: _selfName,
          photoUrl: _user?.photoURL,
          position: LatLng(self.latitude, self.longitude),
          markerIcon: selfIcon,
          batteryPercent: self.batteryPercent,
          isCharging: self.isCharging,
          updatedAt: self.updatedAt,
          accuracyMeters: self.accuracyMeters,
          isSelf: true,
        ),
      );
    }

    final currentUid = _user?.uid;
    if (currentUid == null) return people;
    for (final connection in _connections.where((item) => item.accepted)) {
      final uid = connection.otherUid(currentUid);
      if (_theyShareToMe[uid] != true) continue;
      final location = _locations[uid];
      final icon = _markerIcons[uid];
      if (location == null || icon == null) continue;
      people.add(
        HomiMapPerson(
          id: uid,
          name: connection.otherName(currentUid),
          photoUrl: connection.otherPhotoUrl(currentUid),
          position: LatLng(location.latitude, location.longitude),
          markerIcon: icon,
          batteryPercent: location.batteryPercent,
          isCharging: location.isCharging,
          updatedAt: location.updatedAt,
          accuracyMeters: location.accuracyMeters,
          isSelf: false,
        ),
      );
    }
    return people;
  }

  Set<Marker> _buildMarkers() {
    return _mapPeople()
        .map(
          (person) => Marker(
            markerId: MarkerId(person.id),
            position: person.position,
            icon: person.markerIcon,
            onTap: () async {
              await _focusPerson(person);
              if (mounted) await _showMapPerson(person);
            },
          ),
        )
        .toSet();
  }

  Future<void> _focusPerson(HomiMapPerson person) async {
    if (mounted) setState(() => _focusedPersonId = person.id);
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(person.position, 15.5),
    );
  }

  Future<void> _moveMapTo(double latitude, double longitude) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newLatLng(LatLng(latitude, longitude)),
    );
  }

  Future<void> _openFullMap() async {
    final people = _mapPeople();
    if (people.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PeopleMapPage(
          people: people,
          initialPersonId: _focusedPersonId,
          onShowDetails: _showMapPerson,
        ),
      ),
    );
  }

  Widget _trustedCard(
    TrustedConnection connection,
    String currentUid,
  ) {
    final otherUid = connection.otherUid(currentUid);
    final preference =
        _preferences[otherUid] ?? TrustedPersonPreference.fallback;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _TrustedPersonCard(
        connection: connection,
        currentUid: currentUid,
        preference: preference,
        location: _locations[otherUid],
        theyShareToMe: _theyShareToMe[otherUid] == true,
        shareStream: widget.trustedPeopleService.watchMyShareTo(otherUid),
        onSetMyShare: (active) =>
            widget.trustedPeopleService.setMyLocationShare(otherUid, active),
        onEditRelationship: () => _editPreference(connection),
        onShowLocation: _locations[otherUid] == null
            ? null
            : () {
                final location = _locations[otherUid]!;
                return _showLocationDetails(
                  name: connection.otherName(currentUid),
                  photoUrl: connection.otherPhotoUrl(currentUid),
                  latitude: location.latitude,
                  longitude: location.longitude,
                  batteryPercent: location.batteryPercent,
                  isCharging: location.isCharging,
                  updatedAt: location.updatedAt,
                  accuracyMeters: location.accuracyMeters,
                );
              },
        onFocusLocation: _locations[otherUid] == null
            ? null
            : () {
                final target = _mapPeople()
                    .where((person) => person.id == otherUid)
                    .firstOrNull;
                if (target != null) _focusPerson(target);
              },
        onRemove: () async {
          final confirmed = await showHomiConfirmSheet(
            context,
            title: 'Remove ${connection.otherName(currentUid)}?',
            message:
                'The trusted connection will end. Your location share to this person will also be switched off.',
            confirmLabel: 'Remove connection',
            cancelLabel: 'Keep connected',
            icon: Icons.person_remove_alt_1_outlined,
            destructive: true,
          );
          if (confirmed) {
            await widget.trustedPeopleService
                .declineOrRemoveConnection(connection);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = _user;
    final currentUid = user?.uid;
    final incoming = currentUid == null
        ? const <TrustedConnection>[]
        : _connections
            .where((item) => item.isIncomingFor(currentUid))
            .toList(growable: false);
    final outgoing = currentUid == null
        ? const <TrustedConnection>[]
        : _connections
            .where((item) => item.pending && item.initiatorUid == currentUid)
            .toList(growable: false);
    final accepted = _connections.where((item) => item.accepted).toList();
    final household = <TrustedConnection>[];
    final trusted = <TrustedConnection>[];
    if (currentUid != null) {
      for (final connection in accepted) {
        final otherUid = connection.otherUid(currentUid);
        final preference =
            _preferences[otherUid] ?? TrustedPersonPreference.fallback;
        if (preference.household) {
          household.add(connection);
        } else {
          trusted.add(connection);
        }
      }
      household.sort((a, b) =>
          a.otherName(currentUid).compareTo(b.otherName(currentUid)));
      trusted.sort((a, b) =>
          a.otherName(currentUid).compareTo(b.otherName(currentUid)));
    }
    final initialTarget = _selfSnapshot == null
        ? const LatLng(0, 0)
        : LatLng(_selfSnapshot!.latitude, _selfSnapshot!.longitude);
    final mapPeople = _mapPeople();

    return HomiPage(
      title: 'People',
      subtitle: 'Stay connected with the people you choose.',
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 285,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: _selfSnapshot == null ? 1.5 : 14,
                  ),
                  markers: _buildMarkers(),
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    final focused = mapPeople
                        .where((person) => person.id == _focusedPersonId)
                        .firstOrNull;
                    final target = focused ??
                        (mapPeople.isEmpty ? null : mapPeople.first);
                    if (target != null) {
                      controller.moveCamera(
                        CameraUpdate.newLatLngZoom(target.position, 14),
                      );
                    }
                  },
                ),
              ),
            ),
            if (mapPeople.isNotEmpty)
              Positioned(
                right: 10,
                top: 10,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _openFullMap,
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_full_rounded,
                              size: 17, color: HomiColors.coral),
                          SizedBox(width: 6),
                          Text('Open map',
                              style: TextStyle(fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (mapPeople.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: mapPeople.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final person = mapPeople[index];
                final selected = person.id == _focusedPersonId;
                return GestureDetector(
                  onTap: () => _focusPerson(person),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
                    decoration: BoxDecoration(
                      color: selected ? HomiColors.coral : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected ? HomiColors.coral : HomiColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PersonAvatar(
                          name: person.name,
                          photoUrl: person.photoUrl,
                          size: 36,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          person.isSelf ? 'Me' : person.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color:
                                selected ? Colors.white : HomiColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 12),
        _LocationStatusCard(
          snapshot: _selfSnapshot,
          liveSharing: _liveSharingActive,
          busy: _busy,
          signedIn: user != null,
          onEnableLocation: _enableForegroundLocation,
          onTurnOnLive: _turnOnLiveSharing,
          onTurnOffLive: _turnOffLiveSharing,
          onDetails: _selfSnapshot == null
              ? null
              : () => _showLocationDetails(
                    name: _selfName,
                    photoUrl: user?.photoURL,
                    latitude: _selfSnapshot!.latitude,
                    longitude: _selfSnapshot!.longitude,
                    batteryPercent: _selfSnapshot!.batteryPercent,
                    isCharging: _selfSnapshot!.isCharging,
                    updatedAt: _selfSnapshot!.updatedAt,
                    accuracyMeters: _selfSnapshot!.accuracyMeters,
                  ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _PeopleNotice(
            message: _error!,
            retrying: _syncBusy,
            onRetry: _retryTrustedPeople,
          ),
        ],
        const SizedBox(height: 4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _showLocationFaq,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 19,
                  color: HomiColors.muted,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Location sharing is opt-in. Household members and location-only friends stay separate.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: HomiColors.muted,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Connections',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: _connectWithCode,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Connect'),
            ),
          ],
        ),
        if (user == null) ...[
          const SizedBox(height: 8),
          _EmptyPeopleCard(
            icon: Icons.people_outline_rounded,
            title: 'Sign in to connect with people',
            message:
                'Your own location can stay on this phone without an account. Trusted connections and private sharing use your Homi account.',
            action: 'Sign in',
            onTap: widget.onSignIn,
          ),
        ] else ...[
          const SizedBox(height: 8),
          if (_identity != null)
            _HomiCodeCard(
              identity: _identity!,
              onCopy: () => Clipboard.setData(
                ClipboardData(text: _identity!.code),
              ),
            ),
          if (incoming.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Connection requests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...incoming.map(
              (connection) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IncomingConnectionCard(
                  connection: connection,
                  currentUid: currentUid!,
                  onAccept: () => widget.trustedPeopleService
                      .acceptConnection(connection),
                  onDecline: () => widget.trustedPeopleService
                      .declineOrRemoveConnection(connection),
                ),
              ),
            ),
          ],
          if (outgoing.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...outgoing.map(
              (connection) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _PendingConnectionCard(
                  name: connection.otherName(currentUid!),
                  photoUrl: connection.otherPhotoUrl(currentUid),
                  onCancel: () => widget.trustedPeopleService
                      .declineOrRemoveConnection(connection),
                ),
              ),
            ),
          ],
          if (accepted.isEmpty && incoming.isEmpty && outgoing.isEmpty) ...[
            const SizedBox(height: 12),
            _EmptyPeopleCard(
              icon: Icons.people_outline_rounded,
              title: 'No trusted people connected',
              message:
                  'Use a Homi code to connect. After both people accept, each person decides separately whether to share location.',
              action: 'Connect with a code',
              onTap: _connectWithCode,
            ),
          ] else ...[
            if (household.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PeopleGroupHeader(
                title: 'Household',
                count: household.length,
                subtitle:
                    'People included in your household context and task assignment.',
              ),
              const SizedBox(height: 8),
              ...household.map((connection) =>
                  _trustedCard(connection, currentUid!)),
            ],
            if (trusted.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PeopleGroupHeader(
                title: 'Friends & trusted people',
                count: trusted.length,
                subtitle:
                    'Connected people kept separate from household tasks and home data.',
              ),
              const SizedBox(height: 8),
              ...trusted.map((connection) =>
                  _trustedCard(connection, currentUid!)),
            ],
          ],
        ],
        const SizedBox(height: 22),
        _SafetyEntryCard(
          checkInsEnabled: widget.checkInService.config.enabled,
          onTap: _openSafety,
        ),
      ],
    );
  }

  String _friendly(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'Trusted people could not refresh securely. Your live location can keep running while you retry the private sync.';
        case 'unavailable':
          return 'Trusted people is temporarily unavailable. Homi is keeping the last information it received.';
      }
    }
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
    if (message.contains('PERMISSION_DENIED') ||
        message.contains('permission-denied')) {
      return 'Trusted people could not refresh securely. Your last known information is still available.';
    }
    return message;
  }
}

class _ConnectPersonSheet extends StatefulWidget {
  const _ConnectPersonSheet({required this.service});

  final TrustedPeopleService service;

  @override
  State<_ConnectPersonSheet> createState() => _ConnectPersonSheetState();
}

class _ConnectPersonSheetState extends State<_ConnectPersonSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.connectWithCode(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      var message = error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('StateError: ', '')
          .replaceFirst('Exception: ', '');
      if (error is FirebaseException && error.code == 'permission-denied') {
        message = 'Homi could not send that connection request right now.';
      }
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            Text(
              'Connect with someone',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Enter their 6-character Homi code. Connecting does not turn location sharing on and does not share your Home records.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Homi code',
                hintText: 'ABC123',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(_busy ? 'Sending…' : 'Send connection request'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelationshipSheet extends StatefulWidget {
  const _RelationshipSheet({
    required this.name,
    required this.initial,
  });

  final String name;
  final TrustedPersonPreference initial;

  @override
  State<_RelationshipSheet> createState() => _RelationshipSheetState();
}

class _RelationshipSheetState extends State<_RelationshipSheet> {
  static const _relationships = <String>[
    'Partner',
    'Wife',
    'Husband',
    'Mother',
    'Father',
    'Parent',
    'Son',
    'Daughter',
    'Child',
    'Sibling',
    'Roommate',
    'Friend',
    'Family',
    'Caregiver',
    'Trusted person',
  ];

  late String _relationship;
  late String _scope;

  @override
  void initState() {
    super.initState();
    _relationship = _relationships.contains(widget.initial.relationship)
        ? widget.initial.relationship
        : 'Trusted person';
    _scope = widget.initial.scope == 'household' ? 'household' : 'friend';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How do you know ${widget.name}?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'This label is for your Homi. It helps keep household collaboration separate from location-only friends.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            Text('Relationship', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<String>(
              values: _relationships,
              selected: _relationship,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _relationship = value),
              compact: true,
            ),
            const SizedBox(height: 20),
            Text('Connection type',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<String>(
              values: const <String>['household', 'friend'],
              selected: _scope,
              labelFor: (value) => value == 'household'
                  ? 'Household'
                  : 'Friend · location only',
              onSelected: (value) => setState(() => _scope = value),
            ),
            const SizedBox(height: 10),
            Text(
              _scope == 'household'
                  ? 'Household people can be offered household-only collaboration such as assigned tasks. Location sharing is still a separate choice.'
                  : 'Location-only friends never receive access to your Home, supplies, routines or household records.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TrustedPersonPreference(
                    relationship: _relationship,
                    scope: _scope,
                  ),
                ),
                child: const Text('Save relationship'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDetailsSheet extends StatefulWidget {
  const _LocationDetailsSheet({
    required this.name,
    required this.photoUrl,
    required this.address,
    required this.coordinates,
    required this.latitude,
    required this.longitude,
    required this.batteryPercent,
    required this.isCharging,
    required this.updatedAt,
    required this.accuracyMeters,
  });

  final String name;
  final String? photoUrl;
  final String address;
  final String coordinates;
  final double latitude;
  final double longitude;
  final int batteryPercent;
  final bool isCharging;
  final DateTime? updatedAt;
  final double accuracyMeters;

  @override
  State<_LocationDetailsSheet> createState() => _LocationDetailsSheetState();
}

class _LocationDetailsSheetState extends State<_LocationDetailsSheet> {
  String? _copied;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _copied = label);
  }

  Future<void> _openMaps() async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '${widget.latitude},${widget.longitude}',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PersonAvatar(
                  name: widget.name,
                  photoUrl: widget.photoUrl,
                  size: 54,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.updatedAt == null
                            ? 'Latest shared location'
                            : 'Updated ${DateFormat('d MMM · HH:mm').format(widget.updatedAt!)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  widget.isCharging
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_std_rounded,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.batteryPercent}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailBlock(
              icon: Icons.location_on_outlined,
              title: widget.address,
              subtitle: 'Accuracy about ${widget.accuracyMeters.round()} m',
              copyTooltip: 'Copy address',
              onCopy: () => _copy(widget.address, 'Address copied'),
            ),
            const SizedBox(height: 10),
            _DetailBlock(
              icon: Icons.pin_drop_outlined,
              title: widget.coordinates,
              subtitle: 'Coordinates',
              copyTooltip: 'Copy coordinates',
              onCopy: () => _copy(widget.coordinates, 'Coordinates copied'),
            ),
            if (_copied != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 17,
                    color: Color(0xFF6F8B65),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _copied!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF6F8B65),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(
                      '${widget.address}\n${widget.coordinates}',
                      'Full location copied',
                    ),
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy all'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _openMaps,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationStatusCard extends StatelessWidget {
  const _LocationStatusCard({
    required this.snapshot,
    required this.liveSharing,
    required this.busy,
    required this.signedIn,
    required this.onEnableLocation,
    required this.onTurnOnLive,
    required this.onTurnOffLive,
    required this.onDetails,
  });

  final LocationStatusSnapshot? snapshot;
  final bool liveSharing;
  final bool busy;
  final bool signedIn;
  final VoidCallback onEnableLocation;
  final VoidCallback onTurnOnLive;
  final VoidCallback onTurnOffLive;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: liveSharing
                        ? HomiColors.sage.withValues(alpha: 0.30)
                        : HomiColors.peach.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    liveSharing
                        ? Icons.location_searching_rounded
                        : Icons.location_on_outlined,
                    color: liveSharing
                        ? const Color(0xFF6F8B65)
                        : HomiColors.coral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveSharing ? 'Live location is on' : 'Your location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        snapshot == null
                            ? 'Location has not been enabled yet'
                            : 'Updated ${DateFormat('d MMM · HH:mm').format(snapshot!.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (snapshot != null) ...[
                  Icon(
                    snapshot!.isCharging
                        ? Icons.battery_charging_full_rounded
                        : Icons.battery_std_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${snapshot!.batteryPercent}%',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (snapshot == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onEnableLocation,
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(busy ? 'Checking…' : 'Enable my location'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onDetails,
                      child: const Text('Location details'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: liveSharing
                        ? FilledButton(
                            onPressed: onTurnOffLive,
                            child: const Text('Stop live updates'),
                          )
                        : FilledButton(
                            onPressed: busy ? null : onTurnOnLive,
                            child: Text(
                              signedIn ? 'Live updates' : 'Sign in for live',
                            ),
                          ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HomiCodeCard extends StatelessWidget {
  const _HomiCodeCard({required this.identity, required this.onCopy});

  final HomiIdentity identity;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: HomiColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Homi code',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  identity.code,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy Homi code',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }
}

class _IncomingConnectionCard extends StatelessWidget {
  const _IncomingConnectionCard({
    required this.connection,
    required this.currentUid,
    required this.onAccept,
    required this.onDecline,
  });

  final TrustedConnection connection;
  final String currentUid;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final name = connection.otherName(currentUid);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _PersonAvatar(
                  name: name,
                  photoUrl: connection.otherPhotoUrl(currentUid),
                  size: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name wants to connect',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingConnectionCard extends StatelessWidget {
  const _PendingConnectionCard({
    required this.name,
    required this.photoUrl,
    required this.onCancel,
  });

  final String name;
  final String? photoUrl;
  final Future<void> Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _PersonAvatar(name: name, photoUrl: photoUrl, size: 42),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: const Text('Connection request sent'),
        trailing: TextButton(onPressed: onCancel, child: const Text('Cancel')),
      ),
    );
  }
}

class _TrustedPersonCard extends StatelessWidget {
  const _TrustedPersonCard({
    required this.connection,
    required this.currentUid,
    required this.preference,
    required this.location,
    required this.theyShareToMe,
    required this.shareStream,
    required this.onSetMyShare,
    required this.onEditRelationship,
    required this.onShowLocation,
    required this.onFocusLocation,
    required this.onRemove,
  });

  final TrustedConnection connection;
  final String currentUid;
  final TrustedPersonPreference preference;
  final TrustedPersonLocation? location;
  final bool theyShareToMe;
  final Stream<bool> shareStream;
  final Future<void> Function(bool active) onSetMyShare;
  final VoidCallback onEditRelationship;
  final Future<void> Function()? onShowLocation;
  final VoidCallback? onFocusLocation;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final name = connection.otherName(currentUid);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: onFocusLocation,
                  child: _PersonAvatar(
                    name: name,
                    photoUrl: connection.otherPhotoUrl(currentUid),
                    size: 46,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onFocusLocation,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${preference.relationship} · ${preference.household ? 'Household' : 'Location only'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: HomiColors.coral,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        !theyShareToMe
                            ? 'Not sharing location with you'
                            : location == null
                                ? 'Location shared · waiting for an update'
                                : 'Updated ${location!.updatedAt == null ? 'recently' : DateFormat('HH:mm').format(location!.updatedAt!)} · ${location!.batteryPercent}% battery',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onEditRelationship,
                  icon: const Icon(Icons.tune_rounded, size: 17),
                  label: const Text('Edit'),
                ),
                IconButton(
                  tooltip: 'Remove connection',
                  onPressed: onRemove,
                  icon: const Icon(Icons.more_vert_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (onShowLocation != null) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShowLocation,
                      icon: const Icon(Icons.location_on_outlined),
                      label: const Text('View location'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: StreamBuilder<bool>(
                    stream: shareStream,
                    initialData: false,
                    builder: (context, snapshot) {
                      final sharing = snapshot.data == true;
                      return FilledButton(
                        onPressed: () => onSetMyShare(!sharing),
                        child: Text(
                          sharing ? 'Stop my share' : 'Share mine',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PeopleGroupHeader extends StatelessWidget {
  const _PeopleGroupHeader({
    required this.title,
    required this.count,
    required this.subtitle,
  });

  final String title;
  final int count;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: HomiColors.sage.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$count',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _SafetyEntryCard extends StatelessWidget {
  const _SafetyEntryCard({
    required this.checkInsEnabled,
    required this.onTap,
  });

  final bool checkInsEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: HomiColors.peach.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: HomiColors.coral,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Safety & check-ins',
                        style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(
                      checkInsEnabled
                          ? 'Emergency call shortcuts · arrival check-ins on'
                          : 'Emergency call shortcuts · Home & Work check-ins',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomiColors.peach.withValues(alpha: 0.28),
        border:
            Border.all(color: HomiColors.coral.withValues(alpha: 0.28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: size * 0.38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.copyTooltip,
    required this.onCopy,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String copyTooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HomiColors.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          IconButton(
            tooltip: copyTooltip,
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

class _PeopleNotice extends StatelessWidget {
  const _PeopleNotice({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  final String message;
  final bool retrying;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 19, color: HomiColors.coral),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: retrying ? null : onRetry,
            child: Text(retrying ? 'Retrying…' : 'Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyPeopleCard extends StatelessWidget {
  const _EmptyPeopleCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 32, color: HomiColors.coral),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _FaqPoint extends StatelessWidget {
  const _FaqPoint({
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