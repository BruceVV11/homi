import 'package:flutter/material.dart';

import '../../widgets/homi_page.dart';

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomiPage(
      title: 'Supplies',
      subtitle: 'Keep an eye on what is expiring or running low.',
      children: [
        _SupplyTile(icon: Icons.schedule_rounded, title: 'Eat soon', subtitle: 'Items approaching their expiry date', onTap: () {}),
        const SizedBox(height: 12),
        _SupplyTile(icon: Icons.inventory_2_outlined, title: 'Keep an eye on', subtitle: 'Pantry, freezer, medicine and household supplies', onTap: () {}),
        const SizedBox(height: 12),
        _SupplyTile(icon: Icons.shopping_bag_outlined, title: 'Need to buy', subtitle: 'A lightweight shared list built from low-stock items', onTap: () {}),
      ],
    );
  }
}

class _SupplyTile extends StatelessWidget {
  const _SupplyTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
