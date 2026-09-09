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
  final Future<void> Function(
    String title,
    String category,
    String frequency,
    int estimatedMinutes,
  ) onAdd;
  final Future<void> Function(String id) onToggle;
  final Future<void> Function(String id) onRemove;

  static const _examples = <_RoutineTemplate>[
    _RoutineTemplate(
      icon: Icons.pets_rounded,
      title: 'Feed the pets',
      category: 'Pets',
      frequency: 'Daily',
      estimatedMinutes: 5,
    ),
    _RoutineTemplate(
      icon: Icons.delete_outline_rounded,
      title: 'Take the bins out',
      category: 'Chores',
      frequency: 'Weekly',
      estimatedMinutes: 10,
    ),
    _RoutineTemplate(
      icon: Icons.bed_outlined,
      title: 'Change bed linen',
      category: 'Chores',
      frequency: 'Weekly',
      estimatedMinutes: 15,
    ),
    _RoutineTemplate(
      icon: Icons.local_florist_outlined,
      title: 'Water indoor plants',
      category: 'Plants & garden',
      frequency: 'Weekly',
      estimatedMinutes: 10,
    ),
  ];

  Future<void> _addRoutine(
    BuildContext context, {
    _RoutineTemplate? template,
  }) async {
    final draft = await showModalBottomSheet<_RoutineDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RoutineEditorSheet(template: template),
    );
    if (draft != null) {
      await onAdd(
        draft.title,
        draft.category,
        draft.frequency,
        draft.estimatedMinutes,
      );
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
              Text(
                'Remove routine?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '“${item.title}” will be removed from your routines on this phone.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep routine'),
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
      subtitle: 'Set the repeatable jobs Homi should remember for you.',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                items.isEmpty
                    ? 'Start with one job you regularly need to remember.'
                    : '$openCount ${openCount == 1 ? 'routine is' : 'routines are'} ready to do.',
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
        const SizedBox(height: 14),
        Text('Ideas to try', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Tap an example to use it as a starting point.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        ..._examples.map(
          (template) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoutineExampleTile(
              template: template,
              onTap: () => _addRoutine(context, template: template),
            ),
          ),
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
                      decoration:
                          item.completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category} · ${item.frequency} · about ${item.estimatedMinutes} min',
                    style: Theme.of(context).textTheme.bodyMedium,
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
            const Icon(
              Icons.repeat_rounded,
              size: 34,
              color: HomiColors.coral,
            ),
            const SizedBox(height: 10),
            const Text(
              'No routines yet',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Add a repeatable job and Homi can bring it into your overview and Quick Reset suggestions.',
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

class _RoutineExampleTile extends StatelessWidget {
  const _RoutineExampleTile({
    required this.template,
    required this.onTap,
  });

  final _RoutineTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
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
                child: Icon(template.icon, color: HomiColors.coral),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.title,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${template.frequency} · about ${template.estimatedMinutes} min',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add_rounded, color: HomiColors.coral),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineTemplate {
  const _RoutineTemplate({
    required this.icon,
    required this.title,
    required this.category,
    required this.frequency,
    required this.estimatedMinutes,
  });

  final IconData icon;
  final String title;
  final String category;
  final String frequency;
  final int estimatedMinutes;
}

class _RoutineDraft {
  const _RoutineDraft(
    this.title,
    this.category,
    this.frequency,
    this.estimatedMinutes,
  );

  final String title;
  final String category;
  final String frequency;
  final int estimatedMinutes;
}

class _RoutineEditorSheet extends StatefulWidget {
  const _RoutineEditorSheet({this.template});

  final _RoutineTemplate? template;

  @override
  State<_RoutineEditorSheet> createState() => _RoutineEditorSheetState();
}

class _RoutineEditorSheetState extends State<_RoutineEditorSheet> {
  late final TextEditingController _titleController;
  late String _category;
  late String _frequency;
  late int _estimatedMinutes;
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

  static const _durations = <int>[5, 10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _category = template?.category ?? 'Chores';
    _frequency = template?.frequency ?? 'Daily';
    _estimatedMinutes = template?.estimatedMinutes ?? 10;
  }

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
    Navigator.pop(
      context,
      _RoutineDraft(title, _category, _frequency, _estimatedMinutes),
    );
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
            Text(
              'Add a routine',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Tell Homi what repeats and roughly how long it usually takes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: widget.template == null,
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
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
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
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _estimatedMinutes,
              decoration: const InputDecoration(labelText: 'Usually takes'),
              items: _durations
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _estimatedMinutes = value);
                }
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
