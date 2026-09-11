import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/arrival_check_in.dart';
import '../../domain/emergency_region.dart';
import '../../services/emergency_region_service.dart';
import '../../services/homi_cloud_actions.dart';
import '../../services/shared_place_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/emergency_call_section.dart';
import '../../widgets/emergency_region_picker.dart';

class HomiMapPerson {
  const HomiMapPerson({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.position,
    required this.markerIcon,
    required this.batteryPercent,
    required this.isCharging,
    required this.updatedAt,
    required this.accuracyMeters,
    required this.isSelf,
  });

  final String id;
  final String name;
  final String? photoUrl;
  final LatLng position;
  final BitmapDescriptor markerIcon;
  final int batteryPercent;
  final bool isCharging;
  final DateTime? updatedAt;
  final double accuracyMeters;
  final bool isSelf;
}

class PeopleMapPage extends StatefulWidget {
  const PeopleMapPage({
    required this.people,
    required this.onShowDetails,
    this.initialPersonId,
    super.key,
  });

  final List<HomiMapPerson> people;
  final String? initialPersonId;
  final Future<void> Function(HomiMapPerson person) onShowDetails;

  @override
  State<PeopleMapPage> createState() => _PeopleMapPageState();
}

class _PeopleMapPageState extends State<PeopleMapPage> {
  GoogleMapController? _controller;
  String? _selectedId;
  String? _sendingHeartTo;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialPersonId ??
        (widget.people.isEmpty ? null : widget.people.first.id);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  HomiMapPerson? get _selected {
    final id = _selectedId;
    if (id == null) return null;
    for (final person in widget.people) {
      if (person.id == id) return person;
    }
    return null;
  }

  Future<void> _focus(HomiMapPerson person) async {
    if (mounted) setState(() => _selectedId = person.id);
    await _controller?.animateCamera(
      CameraUpdate.newLatLngZoom(person.position, 16),
    );
  }

  Future<void> _call(String number) async {
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This device could not open the phone app.')),
      );
    }
  }

  Future<void> _showEmergencyNumbers() async {
    var region = EmergencyRegionService.instance.current;
    if (region == null) {
      region = await showEmergencyRegionPicker(context);
      if (!mounted || region == null) return;
    }

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
                  Expanded(
                    child: Text(
                      'Emergency calls',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      await showEmergencyRegionPicker(context);
                    },
                    icon: const Icon(Icons.public_rounded, size: 17),
                    label: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${region.countryName} · Homi opens your phone app with the number ready. It does not place the call or send your location automatically.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              ...region.contacts.map(
                (contact) => _EmergencyNumberRow(
                  icon: emergencyIconFor(contact.kind),
                  title: contact.label,
                  number: contact.number,
                  detail: contact.note,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _call(contact.number);
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Emergency services and availability can vary by network and location. Homi is a call shortcut, not an emergency-response service.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendHeart(HomiMapPerson person) async {
    if (person.isSelf || _sendingHeartTo != null || !_firebaseReady) return;
    setState(() => _sendingHeartTo = person.id);
    try {
      await HomiCloudActions(firebaseReady: true).call(
        'sendHeart',
        <String, dynamic>{'recipientUid': person.id},
      );
      if (!mounted) return;
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
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: HomiColors.coral,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Heart sent to ${person.name}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${person.name} will see that you are thinking about them. Nothing else about your connection or location changes.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } on HomiCloudActionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Homi could not send that heart right now.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingHeartTo = null);
    }
  }

  Future<void> _showPersonDetails(HomiMapPerson person) async {
    String? ownerUid;
    if (person.isSelf) {
      if (_firebaseReady) {
        ownerUid = FirebaseAuth.instance.currentUser?.uid;
      }
    } else {
      ownerUid = person.id;
    }

    Map<ArrivalPlaceKind, HomiSharedPlace> places =
        const <ArrivalPlaceKind, HomiSharedPlace>{};
    if (ownerUid != null && ownerUid.isNotEmpty) {
      try {
        places = await HomiSharedPlaceService(firebaseReady: _firebaseReady)
            .placesFor(ownerUid);
      } catch (_) {
        // Keep the person's latest-location details usable even if saved-place
        // lookup is temporarily unavailable.
      }
    }
    if (!mounted) return;

    final action = await showModalBottomSheet<_PersonDetailAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _PersonDetailsSheet(
        person: person,
        places: places,
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PersonDetailAction.latest:
        await widget.onShowDetails(person);
      case _PersonDetailAction.home:
        final home = places[ArrivalPlaceKind.home];
        if (home != null) await _openSavedPlace(home);
      case _PersonDetailAction.work:
        final work = places[ArrivalPlaceKind.work];
        if (work != null) await _openSavedPlace(work);
    }
  }

  Future<void> _openSavedPlace(HomiSharedPlace place) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': '${place.latitude},${place.longitude}',
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final fallback = widget.people.isEmpty
        ? const LatLng(0, 0)
        : (selected ?? widget.people.first).position;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: HomiColors.cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: fallback,
                      zoom: widget.people.isEmpty ? 1.5 : 15,
                    ),
                    markers: widget.people
                        .map(
                          (person) => Marker(
                            markerId: MarkerId(person.id),
                            position: person.position,
                            icon: person.markerIcon,
                            onTap: () => _focus(person),
                          ),
                        )
                        .toSet(),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: true,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    onMapCreated: (controller) {
                      _controller = controller;
                      final person = _selected;
                      if (person != null) {
                        controller.moveCamera(
                          CameraUpdate.newLatLngZoom(person.position, 15),
                        );
                      }
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _MapCircleButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  blurRadius: 14,
                                  offset: Offset(0, 5),
                                  color: Color(0x18000000),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 18,
                                  color: HomiColors.coral,
                                ),
                                SizedBox(width: 6),
                                Text('People map',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListenableBuilder(
                            listenable: EmergencyRegionService.instance,
                            builder: (context, _) {
                              final primary = EmergencyRegionService
                                  .instance.current?.primaryContact;
                              return _EmergencyMapBar(
                                sosNumber: primary?.number,
                                onSos: primary == null
                                    ? null
                                    : () => _call(primary.number),
                                onMore: _showEmergencyNumbers,
                              );
                            },
                          ),
                          if (widget.people.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 54,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                itemCount: widget.people.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 8),
                                itemBuilder: (context, index) {
                                  final person = widget.people[index];
                                  final active = person.id == _selectedId;
                                  return _MapPersonChip(
                                    person: person,
                                    active: active,
                                    onTap: () => _focus(person),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (selected != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 18,
                                    offset: Offset(0, 6),
                                    color: Color(0x20000000),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  _Avatar(
                                    name: selected.name,
                                    photoUrl: selected.photoUrl,
                                    size: 46,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selected.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${selected.isSelf ? 'You' : 'Shared location'} · ${selected.batteryPercent}% battery',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (!selected.isSelf)
                                    _HeartButton(
                                      busy: _sendingHeartTo == selected.id,
                                      onTap: () => _sendHeart(selected),
                                    ),
                                  const SizedBox(width: 6),
                                  FilledButton(
                                    onPressed: () => _showPersonDetails(selected),
                                    child: const Text('Details'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _PersonDetailAction { latest, home, work }

class _PersonDetailsSheet extends StatelessWidget {
  const _PersonDetailsSheet({required this.person, required this.places});

  final HomiMapPerson person;
  final Map<ArrivalPlaceKind, HomiSharedPlace> places;

  @override
  Widget build(BuildContext context) {
    final home = places[ArrivalPlaceKind.home];
    final work = places[ArrivalPlaceKind.work];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Avatar(name: person.name, photoUrl: person.photoUrl, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${person.isSelf ? 'Your location' : 'Shared location'} · ${person.batteryPercent}% battery',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailActionCard(
              icon: Icons.my_location_rounded,
              title: 'Latest location',
              detail: person.updatedAt == null
                  ? 'Open location details'
                  : 'Updated ${_timeLabel(person.updatedAt!)}',
              onTap: () =>
                  Navigator.pop(context, _PersonDetailAction.latest),
            ),
            const SizedBox(height: 16),
            Text('Saved places', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 5),
            Text(
              person.isSelf
                  ? 'Your saved Home and Work from arrival check-ins.'
                  : 'A precise place appears only when this person chose to show it to you and is also sharing their location with you.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            _SavedPlaceCard(
              kind: ArrivalPlaceKind.home,
              place: home,
              self: person.isSelf,
              onTap: home == null
                  ? null
                  : () => Navigator.pop(context, _PersonDetailAction.home),
            ),
            _SavedPlaceCard(
              kind: ArrivalPlaceKind.work,
              place: work,
              self: person.isSelf,
              onTap: work == null
                  ? null
                  : () => Navigator.pop(context, _PersonDetailAction.work),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day}/${local.month} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _SavedPlaceCard extends StatelessWidget {
  const _SavedPlaceCard({
    required this.kind,
    required this.place,
    required this.self,
    required this.onTap,
  });

  final ArrivalPlaceKind kind;
  final HomiSharedPlace? place;
  final bool self;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    kind == ArrivalPlaceKind.home
                        ? Icons.home_rounded
                        : Icons.work_outline_rounded,
                    color: HomiColors.coral,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(kind.label,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        place?.address ??
                            (self ? 'Not set yet' : 'Not shared with you'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (place != null)
                  const Icon(Icons.open_in_new_rounded,
                      size: 19, color: HomiColors.coral),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailActionCard extends StatelessWidget {
  const _DetailActionCard({
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: HomiColors.coral),
              const SizedBox(width: 11),
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
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyMapBar extends StatelessWidget {
  const _EmergencyMapBar({
    required this.sosNumber,
    required this.onSos,
    required this.onMore,
  });

  final String? sosNumber;
  final VoidCallback? onSos;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final number = sosNumber;
    if (number == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onMore,
          icon: const Icon(Icons.emergency_rounded),
          label: const Text('Emergency numbers'),
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onSos,
            icon: const Icon(Icons.emergency_rounded),
            label: Text('SOS · $number'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: onMore,
            icon: const Icon(Icons.call_outlined),
            label: const Text('Emergency numbers'),
          ),
        ),
      ],
    );
  }
}

class _EmergencyNumberRow extends StatelessWidget {
  const _EmergencyNumberRow({
    required this.icon,
    required this.title,
    required this.number,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String number;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: HomiColors.coral),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(detail == null ? number : '$number · $detail'),
          trailing: const Icon(Icons.call_rounded, color: HomiColors.coral),
        ),
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Send a heart',
      child: Material(
        color: HomiColors.peach.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: busy ? null : onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.favorite_rounded, color: HomiColors.coral),
          ),
        ),
      ),
    );
  }
}

class _MapPersonChip extends StatelessWidget {
  const _MapPersonChip({
    required this.person,
    required this.active,
    required this.onTap,
  });

  final HomiMapPerson person;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 11, 5),
        decoration: BoxDecoration(
          color: active ? HomiColors.coral : Colors.white,
          borderRadius: BorderRadius.circular(27),
          border: Border.all(
            color: active ? HomiColors.coral : HomiColors.border,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 10,
              offset: Offset(0, 3),
              color: Color(0x12000000),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Avatar(name: person.name, photoUrl: person.photoUrl, size: 38),
            const SizedBox(width: 8),
            Text(
              person.isSelf ? 'Me' : person.name,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: active ? Colors.white : HomiColors.slate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: HomiColors.slate),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
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
        color: HomiColors.cream,
        border: Border.all(
          color: HomiColors.coral.withValues(alpha: 0.32),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w900,
                  color: HomiColors.slate,
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
                    color: HomiColors.slate,
                  ),
                ),
              ),
            ),
    );
  }
}
