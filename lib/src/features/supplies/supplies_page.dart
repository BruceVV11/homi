import 'package:flutter/material.dart';

import '../../widgets/homi_page.dart';

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomiPage(
      title: 'Supplies',
      subtitle: 'Keep an eye on what is expiring or running low.',
      children: [
        _SupplyTile(icon: Icons.schedule_rounded, title: 'Eat soon', subtitle: 'Items approaching their expiry date'),
        SizedBox(height: 12),
        _SupplyTile(icon: Icons.inventory_2_outlined, title: 'Keep an eye on', subtitle: 'Pantry, freezer, medicine and household supplies'),
        SizedBox(height: 12),
        _SupplyTile(icon: Icons.shopping_bag_outlined, title: 'Need to buy', subtitle: 'A lightweight shared list built from low-stock items'),
      ],
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({required this.icon, required this.title, required this.subtitle});
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
