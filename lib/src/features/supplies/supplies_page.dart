import 'package:flutter/material.dart';

import '../../domain/supply_item.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
import '../../widgets/homi_page.dart';

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({
    required this.items,
    required this.onAdd,
    required this.onUpdateStatus,
    required this.onRemove,
    super.key,
  });

  final List<SupplyItem> items;
  final Future<void> Function(
    String name,
    String category,
    SupplyStatus status,
    DateTime? expiryDate,
  ) onAdd;
  final Future<void> Function(String id, SupplyStatus status) onUpdateStatus;
  final Future<void> Function(String id) onRemove;

  static const _editableStatuses = <SupplyStatus>[
    SupplyStatus.okay,
    SupplyStatus.runningLow,
    SupplyStatus.needToBuy,
  ];

  static const _quickStarts = <_SupplyTemplate>[
    _SupplyTemplate('Milk', 'Fridge', Icons.local_drink_outlined),
    _SupplyTemplate('Bread', 'Pantry', Icons.breakfast_dining_outlined),
    _SupplyTemplate('Eggs', 'Fridge', Icons.egg_outlined),
    _SupplyTemplate('Dog food', 'Pantry', Icons.pets_outlined),
    _SupplyTemplate('Toilet paper', 'Household', Icons.bathroom_outlined),
    _SupplyTemplate('Dishwashing liquid', 'Household', Icons.cleaning_services_outlined),
  ];

  Future<void> _addSupply(
    BuildContext context, {
    _SupplyTemplate? template,
  }) async {
    final draft = await showModalBottomSheet<_SupplyDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SupplyEditorSheet(template: template),
    );
    if (draft != null) {
      await onAdd(draft.name, draft.category, draft.status, draft.expiryDate);
    }
  }

  Future<void> _showOptions(BuildContext context, SupplyItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                'Update the stock status',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              HomiChoiceGroup<SupplyStatus>(
                values: _editableStatuses,
                selected: item.status,
                labelFor: (value) => value.label,
                onSelected: (value) async {
                  await onUpdateStatus(item.id, value);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    final confirmed = await showHomiConfirmSheet(
                      context,
                      title: 'Remove supply?',
                      message:
                          '“${item.name}” will be removed from your supplies on this phone.',
                      confirmLabel: 'Remove item',
                      cancelLabel: 'Keep item',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                    );
                    if (confirmed) await onRemove(item.id);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove item'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final useSoon = items
        .where((item) => item.effectiveStatus(now) == SupplyStatus.eatSoon)
        .length;
    final runningLow = items
        .where((item) => item.effectiveStatus(now) == SupplyStatus.runningLow)
        .length;
    final needToBuy = items
        .where((item) => item.effectiveStatus(now) == SupplyStatus.needToBuy)
        .length;

    return HomiPage(
      title: 'Supplies',
      subtitle: 'Track expiry dates and the things you are running low on.',
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Use soon', count: useSoon)),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(label: 'Running low', count: runningLow),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(label: 'Need to buy', count: needToBuy),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _addSupply(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add a supply'),
          ),
        ),
        const SizedBox(height: 18),
        Text('Quick adds', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Common household items, ready to adjust before you save them.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickStarts.map((template) {
            return GestureDetector(
              onTap: () => _addSupply(context, template: template),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HomiColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(template.icon, size: 18, color: HomiColors.coral),
                    const SizedBox(width: 7),
                    Text(
                      template.name,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.add_rounded, size: 16),
                  ],
                ),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 18),
        if (items.isEmpty)
          _EmptySupplyCard(onAdd: () => _addSupply(context))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SupplyCard(
                item: item,
                now: now,
                onOptions: () => _showOptions(context, item),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SupplyCard extends StatelessWidget {
  const _SupplyCard({
    required this.item,
    required this.now,
    required this.onOptions,
  });

  final SupplyItem item;
  final DateTime now;
  final VoidCallback onOptions;

  String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final displayStatus = item.effectiveStatus(now);
    final displayLabel = item.displayStatusLabel(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: HomiColors.coral,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.expiryDate == null
                        ? item.category
                        : '${item.category} · expires ${_dateLabel(item.expiryDate!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  _StatusLine(status: displayStatus, label: displayLabel),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Supply options',
              onPressed: onOptions,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.label});

  final SupplyStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SupplyStatus.okay => const Color(0xFF6F8B65),
      SupplyStatus.runningLow => const Color(0xFFC57643),
      SupplyStatus.needToBuy => HomiColors.coral,
      SupplyStatus.eatSoon => const Color(0xFFD28B43),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EmptySupplyCard extends StatelessWidget {
  const _EmptySupplyCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 34,
              color: HomiColors.coral,
            ),
            const SizedBox(height: 10),
            const Text(
              'Nothing tracked yet',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              'Add fridge, pantry and household basics so Homi can flag what is running low or nearing its expiry date.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add first item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplyTemplate {
  const _SupplyTemplate(this.name, this.category, this.icon);

  final String name;
  final String category;
  final IconData icon;
}

class _SupplyDraft {
  const _SupplyDraft(this.name, this.category, this.status, this.expiryDate);

  final String name;
  final String category;
  final SupplyStatus status;
  final DateTime? expiryDate;
}

class _SupplyEditorSheet extends StatefulWidget {
  const _SupplyEditorSheet({this.template});

  final _SupplyTemplate? template;

  @override
  State<_SupplyEditorSheet> createState() => _SupplyEditorSheetState();
}

class _SupplyEditorSheetState extends State<_SupplyEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _dayController;
  late final TextEditingController _monthController;
  late final TextEditingController _yearController;
  late String _category;
  SupplyStatus _status = SupplyStatus.okay;
  bool _hasExpiry = false;
  String? _error;

  static const _categories = <String>[
    'Pantry',
    'Fridge',
    'Freezer',
    'Medicine',
    'Household',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _category = widget.template?.category ?? 'Pantry';
    _dayController = TextEditingController(text: now.day.toString().padLeft(2, '0'));
    _monthController = TextEditingController(text: now.month.toString().padLeft(2, '0'));
    _yearController = TextEditingController(text: now.year.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  DateTime? _expiryFromFields() {
    if (!_hasExpiry) return null;
    final day = int.tryParse(_dayController.text.trim());
    final month = int.tryParse(_monthController.text.trim());
    final year = int.tryParse(_yearController.text.trim());
    if (day == null || month == null || year == null) return null;
    if (year < 2020 || month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final candidate = DateTime(year, month, day);
    if (candidate.year != year || candidate.month != month || candidate.day != day) {
      return null;
    }
    return candidate;
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the item a short name.');
      return;
    }
    final expiry = _expiryFromFields();
    if (_hasExpiry && expiry == null) {
      setState(() => _error = 'Enter a valid expiry date.');
      return;
    }
    Navigator.pop(
      context,
      _SupplyDraft(name, _category, _status, expiry),
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
              'Add a supply',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Keep the details simple. Homi only needs enough information to tell you when something needs attention.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: widget.template == null,
              decoration: InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. Dog food',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Where is it?'),
            const SizedBox(height: 9),
            HomiChoiceGroup<String>(
              values: _categories,
              selected: _category,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _category = value),
              compact: true,
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Stock status'),
            const SizedBox(height: 9),
            HomiChoiceGroup<SupplyStatus>(
              values: SuppliesPage._editableStatuses,
              selected: _status,
              labelFor: (value) => value.label,
              onSelected: (value) => setState(() => _status = value),
              compact: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: _FieldLabel('Expiry date')),
                TextButton(
                  onPressed: () => setState(() => _hasExpiry = !_hasExpiry),
                  child: Text(_hasExpiry ? 'Remove' : 'Add date'),
                ),
              ],
            ),
            if (_hasExpiry) ...[
              const SizedBox(height: 4),
              Text(
                'Enter the date as day, month and year.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dayController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(labelText: 'Day', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _monthController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(labelText: 'Month', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(labelText: 'Year', counterText: ''),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Add supply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
    );
  }
}
