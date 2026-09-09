import 'package:flutter/material.dart';

import '../../domain/routine_item.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({
    required this.items,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    super.key,
  });

  final List<RoutineItem> items;
  final Future<void> Function(String title, String category, String frequency) onAdd;
  final Future<void> Function(String id) onToggle;
  final Future<void> Function(String id) onRemove;

  Future<void> _addRoutine(BuildContext context) async {
    final draft = await showModalBottomSheet<_RoutineDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _RoutineEditorSheet(),
    );
    if (draft != null) {
      await onAdd(draft.title, draft.category, draft.frequency);
    }
  }

  Future<void> _confirmDelete(BuildContext context, RoutineItem item) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove routine?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'This removes “${item.title}” from this device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep it'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) await onRemove(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final openCount = items.where((item) => !item.completed).length;

    return HomiPage(
      title: 'Routines',
      subtitle: 'The repeatable things that make home life easier.',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                items.isEmpty
                    ? 'Start with one thing you do often.'
                    : '$openCount ${openCount == 1 ? 'routine' : 'routines'} waiting right now.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _addRoutine(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptyRoutineCard(onAdd: () => _addRoutine(context))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoutineCard(
                item: item,
                onToggle: () => onToggle(item.id),
                onDelete: () => _confirmDelete(context, item),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Text('Useful categories', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const _IdeaTile(
          icon: Icons.pets_rounded,
          title: 'Pets',
          subtitle: 'Feeds, walks, medication and care',
        ),
        const SizedBox(height: 10),
        const _IdeaTile(
          icon: Icons.cleaning_services_outlined,
          title: 'Chores',
          subtitle: 'Cleaning, bins, laundry and resets',
        ),
        const SizedBox(height: 10),
        const _IdeaTile(
          icon: Icons.local_florist_outlined,
          title: 'Plants & garden',
          subtitle: 'Watering and recurring care',
        ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final RoutineItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
        child: Row(
          children: [
            Checkbox(
              value: item.completed,
              activeColor: HomiColors.coral,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      decoration: item.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MiniPill(label: item.category),
                      _MiniPill(label: item.frequency),
                      if (item.completed)
                        const _MiniPill(label: 'Done', emphasized: true),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Routine options',
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Remove routine'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? HomiColors.sage.withValues(alpha: 0.28)
            : HomiColors.peach.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyRoutineCard extends StatelessWidget {
  const _EmptyRoutineCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.repeat_rounded, size: 34, color: HomiColors.coral),
            const SizedBox(height: 10),
            const Text('No routines yet', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Add something you want Homi to remember repeatedly.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first routine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _IdeaTile extends StatelessWidget {
  const _IdeaTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
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

class _RoutineDraft {
  const _RoutineDraft(this.title, this.category, this.frequency);

  final String title;
  final String category;
  final String frequency;
}

class _RoutineEditorSheet extends StatefulWidget {
  const _RoutineEditorSheet();

  @override
  State<_RoutineEditorSheet> createState() => _RoutineEditorSheetState();
}

class _RoutineEditorSheetState extends State<_RoutineEditorSheet> {
  final TextEditingController _titleController = TextEditingController();
  String _category = 'Chores';
  String _frequency = 'Daily';
  String? _error;

  static const _categories = <String>[
    'Chores',
    'Pets',
    'Plants & garden',
    'Pool & outdoor',
    'Home',
  ];

  static const _frequencies = <String>[
    'Daily',
    'Weekdays',
    'Weekly',
    'Monthly',
    'As needed',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the routine a short name.');
      return;
    }
    Navigator.pop(context, _RoutineDraft(title, _category, _frequency));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
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
            Text('Add a routine', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Keep it simple. You can mark it done whenever it is handled.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Routine',
                hintText: 'e.g. Feed Milo',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'How often?'),
              items: _frequencies
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Add routine'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
