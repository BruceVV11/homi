import 'package:flutter/material.dart';

import '../../widgets/homi_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.homeName, required this.homeType, super.key});

  final String homeName;
  final String homeType;

  @override
  Widget build(BuildContext context) {
    return HomiPage(
      title: homeName,
      subtitle: '$homeType · everything that keeps your place running.',
      children: const [
        _HomeTile(icon: Icons.kitchen_outlined, title: 'Things', subtitle: 'Appliances, warranties, manuals and receipts'),
        SizedBox(height: 12),
        _HomeTile(icon: Icons.build_outlined, title: 'Maintenance', subtitle: 'Recurring care and service reminders'),
        SizedBox(height: 12),
        _HomeTile(icon: Icons.history_rounded, title: 'Repair history', subtitle: 'Incidents, quotes, repairs and resolved work'),
        SizedBox(height: 12),
        _HomeTile(icon: Icons.folder_outlined, title: 'Documents', subtitle: 'Home records backed by your own Google Drive'),
        SizedBox(height: 12),
        _HomeTile(icon: Icons.water_drop_outlined, title: 'Utilities', subtitle: 'Water and electricity readings and trends'),
      ],
    );
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
