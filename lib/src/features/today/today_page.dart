import 'package:flutter/material.dart';

import '../../theme/homi_theme.dart';
import '../../widgets/homi_brand.dart';
import '../../widgets/homi_page.dart';

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.homeName,
    required this.signedIn,
    required this.quickItems,
    required this.onAddQuickItem,
    required this.onRemoveQuickItem,
    required this.onAccountTap,
    super.key,
  });

  final String homeName;
  final bool signedIn;
  final List<String> quickItems;
  final Future<void> Function(String value) onAddQuickItem;
  final Future<void> Function(String value) onRemoveQuickItem;
  final VoidCallback onAccountTap;

  Future<void> _addSomething(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
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
              Text('Add something', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Capture a quick home reminder. We will expand this into smart categorisation in the next passes.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => Navigator.pop(context, value),
                decoration: const InputDecoration(hintText: 'e.g. Buy dog food'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('Add to Today'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (value != null && value.trim().isNotEmpty) await onAddQuickItem(value);
  }

  void _showTimePlan(BuildContext context, int minutes) {
    final tasks = minutes <= 10
        ? const [
            ('Wipe kitchen counters', '4 min'),
            ('Refill pet water', '2 min'),
            ('Empty recycling', '3 min'),
          ]
        : const [
            ('Clean bathroom', '12 min'),
            ('Change bed linen', '8 min'),
            ('Sweep living areas', '7 min'),
          ];

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minutes-minute reset', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text('A small set of useful jobs that fits inside the time you have.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              ...tasks.map((task) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, color: HomiColors.coral),
                        const SizedBox(width: 10),
                        Expanded(child: Text(task.$1, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text(task.$2, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

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
        if (quickItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...quickItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.push_pin_outlined, color: HomiColors.coral),
                        const SizedBox(width: 12),
                        Expanded(child: Text(item, style: const TextStyle(fontWeight: FontWeight.w800))),
                        IconButton(
                          tooltip: 'Done',
                          onPressed: () => onRemoveQuickItem(item),
                          icon: const Icon(Icons.check_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
        const SizedBox(height: 18),
        const _SectionLabel(label: 'When you have time'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _TimeCard(minutes: 10, detail: '3 quick tasks', onTap: () => _showTimePlan(context, 10))),
            const SizedBox(width: 12),
            Expanded(child: _TimeCard(minutes: 30, detail: '3 useful tasks', onTap: () => _showTimePlan(context, 30))),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _addSomething(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add something'),
          ),
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
