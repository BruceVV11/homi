import 'package:flutter/material.dart';

import '../../widgets/homi_page.dart';

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomiPage(
      title: 'Routines',
      subtitle: 'The repeatable things that make home life easier.',
      children: [
        _RoutineTile(icon: Icons.pets_rounded, title: 'Pets', subtitle: 'Feeds, walks, medication and care', onTap: () {}),
        const SizedBox(height: 12),
        _RoutineTile(icon: Icons.cleaning_services_outlined, title: 'Chores', subtitle: 'Recurring tasks and time-boxed suggestions', onTap: () {}),
        const SizedBox(height: 12),
        _RoutineTile(icon: Icons.local_florist_outlined, title: 'Plants & garden', subtitle: 'Optional watering and care routines', onTap: () {}),
        const SizedBox(height: 12),
        _RoutineTile(icon: Icons.pool_outlined, title: 'Pool & outdoor', subtitle: 'Optional recurring home-care routines', onTap: () {}),
      ],
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

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
