import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/homi_theme.dart';

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

  Future<void> _sendHeart(HomiMapPerson person) async {
    if (person.isSelf || _sendingHeartTo != null) return;
    setState(() => _sendingHeartTo = person.id);
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'africa-south1')
          .httpsCallable('sendHeart');
      await callable.call(<String, dynamic>{'recipientUid': person.id});
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
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'resource-exhausted' =>
          'Give it a moment before sending another heart.',
        'permission-denied' =>
          'Hearts can only be sent to an accepted trusted person.',
        'unauthenticated' => 'Sign in to send a heart.',
        _ => 'Homi could not send that heart right now. Try again shortly.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
                                Text(
                                  'People map',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.people.isNotEmpty)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                      onPressed: () =>
                                          widget.onShowDetails(selected),
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
