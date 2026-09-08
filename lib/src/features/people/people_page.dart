import 'package:flutter/material.dart';

import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';

class PeoplePage extends StatelessWidget {
  const PeoplePage({super.key});

  @override
  Widget build(BuildContext context) {
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
                  Icon(Icons.location_on_outlined, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live sharing is always optional',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Invite someone you trust, then each person decides whether to share their location and for how long.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _PersonCard(
          name: 'Casey',
          status: 'At home · updated 2 min ago',
          battery: 78,
          isCharging: false,
        ),
        const SizedBox(height: 12),
        const _PersonCard(
          name: 'Mom',
          status: 'Location paused',
          battery: null,
          isCharging: false,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Invite someone'),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.shield_outlined),
            label: const Text('Location & privacy controls'),
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.status,
    required this.battery,
    required this.isCharging,
  });

  final String name;
  final String status;
  final int? battery;
  final bool isCharging;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: HomiColors.peach.withValues(alpha: 0.35),
              foregroundColor: HomiColors.slate,
              child: Text(name.characters.first, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(status, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            if (battery != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded, size: 19),
                  const SizedBox(width: 3),
                  Text('$battery%', style: const TextStyle(fontWeight: FontWeight.w800)),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
