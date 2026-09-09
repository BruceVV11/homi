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

  static const _editableStatuses = <SupplyStatus>[
    SupplyStatus.okay,
    SupplyStatus.runningLow,
    SupplyStatus.needToBuy,
  ];

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
              Text(
                'Remove item?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '“${item.name}” will be removed from your supplies on this phone.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep item'),
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
        const SizedBox(height: 16),
        if (items.isEmpty)
          _EmptySupplyCard(onAdd: () => _addSupply(context))
        else
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SupplyCard(
                item: item,
                now: now,
                onStatus: (status) => onUpdateStatus(item.id, status),
                onDelete: () => _confirmDelete(context, item),
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
    required this.onStatus,
    required this.onDelete,
  });

  final SupplyItem item;
  final DateTime now;
  final ValueChanged<SupplyStatus> onStatus;
  final VoidCallback onDelete;

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
            PopupMenuButton<String>(
              tooltip: 'Supply options',
              onSelected: (value) {
                if (value == 'delete') {
                  onDelete();
                  return;
                }
                final status = _editableStatuses.firstWhere(
                  (item) => item.name == value,
                );
                onStatus(status);
              },
              itemBuilder: (context) => [
                ..._editableStatuses.map(
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
              'Add pantry, fridge, medicine or household items that are useful to keep an eye on.',
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
            Text(
              'Add a supply',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Track the items that are useful to remember, including optional expiry dates.',
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
            DropdownButtonFormField<SupplyStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Stock status'),
              items: SuppliesPage._editableStatuses
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
