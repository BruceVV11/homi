import 'package:flutter/material.dart';

import '../../theme/homi_theme.dart';
import '../../widgets/homi_brand.dart';
import '../../widgets/homi_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.homeName,
    required this.signedIn,
    required this.onAccountTap,
    super.key,
  });

  final String homeName;
  final bool signedIn;
  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    return HomiPage(
      title: '$greeting!',
      subtitle: '$homeName is ready when you are.',
      trailing: IconButton.filledTonal(
        onPressed: onAccountTap,
        tooltip: signedIn ? 'Account' : 'Sign in',
        icon: Icon(signedIn ? Icons.person_rounded : Icons.person_outline_rounded),
      ),
      children: [
        const HomiLogo(width: 150),
        const SizedBox(height: 24),
        const _SectionLabel(label: 'Today'),
        const SizedBox(height: 10),
        const _AttentionCard(icon: Icons.pets_rounded, title: 'Milo was fed', detail: '07:42 · completed this morning'),
        const SizedBox(height: 10),
        const _AttentionCard(icon: Icons.kitchen_outlined, title: 'Milk expires in 3 days', detail: 'Use soon'),
        const SizedBox(height: 10),
        const _AttentionCard(icon: Icons.bolt_outlined, title: 'Electricity reading due this week', detail: 'Last reading was 29 days ago'),
        const SizedBox(height: 28),
        const _SectionLabel(label: 'When you have time'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _TimeCard(minutes: 10, detail: '3 quick tasks', onTap: () {})),
            const SizedBox(width: 12),
            Expanded(child: _TimeCard(minutes: 30, detail: '5 tasks', onTap: () {})),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.add_rounded), label: const Text('Add something')),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label, style: Theme.of(context).textTheme.titleLarge);
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: HomiColors.peach.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.minutes, required this.detail, required this.onTap});
  final int minutes;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minutes minutes', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerRight, child: Icon(Icons.arrow_forward_rounded)),
            ],
          ),
        ),
      ),
    );
  }
}
