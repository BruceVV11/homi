import 'package:flutter/material.dart';

import '../domain/emergency_region.dart';
import '../services/emergency_region_service.dart';
import '../theme/homi_theme.dart';
import 'emergency_region_picker.dart';

typedef EmergencyContactBuilder = Widget Function(
  BuildContext context,
  EmergencyContact contact,
);

IconData emergencyIconFor(EmergencyServiceKind kind) => switch (kind) {
      EmergencyServiceKind.emergency => Icons.emergency_outlined,
      EmergencyServiceKind.police => Icons.local_police_outlined,
      EmergencyServiceKind.ambulance => Icons.medical_services_outlined,
      EmergencyServiceKind.fire => Icons.local_fire_department_outlined,
    };

String emergencyContactDetail(EmergencyContact contact) {
  final note = contact.note?.trim();
  return note == null || note.isEmpty
      ? contact.number
      : '${contact.number} · $note';
}

/// Shared Safety-page section that keeps emergency numbers offline and bound to
/// the user's selected region without duplicating Homi's card design.
class HomiEmergencyCallSection extends StatelessWidget {
  const HomiEmergencyCallSection({
    required this.contactBuilder,
    super.key,
  });

  final EmergencyContactBuilder contactBuilder;

  @override
  Widget build(BuildContext context) {
    final service = EmergencyRegionService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final region = service.current;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Emergency calls',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showEmergencyRegionPicker(context),
                  icon: const Icon(Icons.public_rounded, size: 17),
                  label: Text(region == null ? 'Choose region' : 'Change'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              region == null
                  ? 'Choose your emergency region before using Homi’s call shortcuts.'
                  : '${region.countryName} emergency numbers are stored on this phone. Homi opens the phone app but does not place a call automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (region == null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showEmergencyRegionPicker(context),
                  icon: const Icon(Icons.public_rounded),
                  label: const Text('Choose emergency region'),
                ),
              )
            else
              ...region.contacts.map(
                (contact) => contactBuilder(context, contact),
              ),
            if (region != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: HomiColors.muted,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Emergency services and availability can vary by network and location. Homi is a call shortcut, not an emergency-response service.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
