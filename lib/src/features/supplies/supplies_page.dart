import 'package:flutter/material.dart';

import '../../domain/supply_item.dart';
import '../../theme/homi_theme.dart';
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

  Future<void> _addSupply(BuildContext context) async {
    final draft = await showModalBottomSheet<_SupplyDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _SupplyEditorSheet(),
    );
    if (draft != null) {
      await onAdd(draft.name, draft.category, draft.status, draft.expiryDate);
    }
  }

  Future<void> _confirmDelete(BuildContext context, SupplyItem item) async {
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
              Text('Remove item?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'This removes “${item.name}” from your supplies on this device.',
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
    final eatSoon = items.where((item) => item.status == SupplyStatus.eatSoon).length;
    final runningLow = items.where((item) => item.status == SupplyStatus.runningLow).length;
    final needToBuy = items.where((item) => item.status == SupplyStatus.needToBuy).length;

    return HomiPage(
      title: 'Supplies',
      subtitle: 'Keep an eye on what is expiring or running low.',
      children: [
        Row(
          children: [
            Expanded(child: _SummaryChip(label: 'Eat soon', count: eatSoon)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryChip(label: 'Running low', count: runningLow)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryChip(label: 'Need to buy', count: needToBuy)),
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
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptySupplyCard(onAdd: () => _addSupply(context))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SupplyCard(
                item: item,
                onStatus: (status) => onUpdateStatus(item.id, status),
                onDelete: () => _confirmDelete(context, item),
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.count});

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
          Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
    required this.onStatus,
    required this.onDelete,
  });

  final SupplyItem item;
  final ValueChanged<SupplyStatus> onStatus;
  final VoidCallback onDelete;

  String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.inventory_2_outlined, color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    item.expiryDate == null
                        ? item.category
                        : '${item.category} · expires ${_dateLabel(item.expiryDate!)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  _StatusPill(status: item.status),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Supply options',
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                  return;
                }
                final status = SupplyStatus.values.firstWhere((item) => item.name == value);
                onStatus(status);
              },
              itemBuilder: (context) => [
                ...SupplyStatus.values.map(
                  (status) => PopupMenuItem<String>(
                    value: status.name,
                    child: Text(status.label),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Remove item'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final SupplyStatus status;

  @override
  Widget build(BuildContext context) {
    final background = switch (status) {
      SupplyStatus.okay => HomiColors.sage.withValues(alpha: 0.28),
      SupplyStatus.runningLow => HomiColors.peach.withValues(alpha: 0.30),
      SupplyStatus.needToBuy => HomiColors.coral.withValues(alpha: 0.16),
      SupplyStatus.eatSoon => HomiColors.peach.withValues(alpha: 0.42),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
      ),
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
            const Icon(Icons.shopping_bag_outlined, size: 34, color: HomiColors.coral),
            const SizedBox(height: 10),
            const Text('Nothing tracked yet', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Add pantry, fridge, medicine or household items when they are useful to keep an eye on.',
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

class _SupplyDraft {
  const _SupplyDraft(this.name, this.category, this.status, this.expiryDate);

  final String name;
  final String category;
  final SupplyStatus status;
  final DateTime? expiryDate;
}

class _SupplyEditorSheet extends StatefulWidget {
  const _SupplyEditorSheet();

  @override
  State<_SupplyEditorSheet> createState() => _SupplyEditorSheetState();
}

class _SupplyEditorSheetState extends State<_SupplyEditorSheet> {
  final TextEditingController _nameController = TextEditingController();
  String _category = 'Pantry';
  SupplyStatus _status = SupplyStatus.okay;
  DateTime? _expiryDate;
  String? _error;

  static const _categories = <String>[
    'Pantry',
    'Fridge',
    'Freezer',
    'Medicine',
    'Household',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null && mounted) setState(() => _expiryDate = selected);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the item a short name.');
      return;
    }
    Navigator.pop(
      context,
      _SupplyDraft(name, _category, _status, _expiryDate),
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
            Text('Add a supply', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Track only the things that are useful to remember.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. Dog food',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Where is it?'),
              items: _categories
                  .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SupplyStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: SupplyStatus.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _status = value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  _expiryDate == null
                      ? 'Add expiry date (optional)'
                      : 'Expires ${_dateLabel(_expiryDate!)}',
                ),
              ),
            ),
            if (_expiryDate != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _expiryDate = null),
                  child: const Text('Remove expiry date'),
                ),
              ),
            const SizedBox(height: 8),
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
