import 'package:flutter/material.dart';

import '../../domain/supply_icon_catalog.dart';
import '../../domain/supply_item.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
import '../../widgets/homi_date_time_controls.dart';
import '../../widgets/homi_page.dart';

class SuppliesPage extends StatelessWidget {
  const SuppliesPage({
    required this.items,
    required this.onAdd,
    required this.onUpdateStatus,
    required this.onUpdateQuantity,
    required this.onRemove,
    super.key,
  });

  final List<SupplyItem> items;
  final Future<void> Function(
    String name,
    String category,
    SupplyStatus status,
    DateTime? expiryDate,
    String iconKey,
    double? quantity,
    SupplyUnit? unit,
  ) onAdd;
  final Future<void> Function(String id, SupplyStatus status) onUpdateStatus;
  final Future<void> Function(
    String id, {
    required double? quantity,
    required SupplyUnit? unit,
  }) onUpdateQuantity;
  final Future<void> Function(String id) onRemove;

  static const _editableStatuses = <SupplyStatus>[
    SupplyStatus.okay,
    SupplyStatus.runningLow,
    SupplyStatus.needToBuy,
  ];

  static const _quickStarts = <_SupplyTemplate>[
    _SupplyTemplate('Milk', 'Fridge', 'milk', 1, SupplyUnit.bottle),
    _SupplyTemplate('Bread', 'Pantry', 'bread', 1, SupplyUnit.loaf),
    _SupplyTemplate('Eggs', 'Fridge', 'eggs', 12, SupplyUnit.egg),
    _SupplyTemplate('Dog food', 'Pantry', 'pet_food', 1, SupplyUnit.bag),
    _SupplyTemplate('Toilet paper', 'Household', 'toilet_paper', 1, SupplyUnit.pack),
    _SupplyTemplate('Dishwashing liquid', 'Household', 'dishwasher', 1, SupplyUnit.bottle),
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
      await onAdd(
        draft.name,
        draft.category,
        draft.status,
        draft.expiryDate,
        draft.iconKey,
        draft.quantity,
        draft.unit,
      );
    }
  }

  Future<void> _editAmount(BuildContext context, SupplyItem item) async {
    final update = await showModalBottomSheet<_SupplyAmountUpdate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SupplyAmountSheet(item: item),
    );
    if (update == null) return;
    await onUpdateQuantity(
      item.id,
      quantity: update.quantity,
      unit: update.unit,
    );
  }

  Future<void> _adjustAmount(SupplyItem item, double delta) async {
    if (!item.tracksQuantity) return;
    final next = (item.quantity! + delta).clamp(0, 999999).toDouble();
    await onUpdateQuantity(item.id, quantity: next, unit: item.unit);
  }

  Future<void> _showOptions(BuildContext context, SupplyItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text(
                'Keep this lightweight: change the amount after shopping, or update the stock status only when you need to.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await _editAmount(context, item);
                  },
                  icon: const Icon(Icons.pin_outlined),
                  label: Text(item.tracksQuantity ? 'Update amount' : 'Start tracking amount'),
                ),
              ),
              const SizedBox(height: 18),
              Text('Stock status', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 9),
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
                      message: '“${item.name}” will be removed from your supplies on this phone.',
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
      subtitle: 'Keep everyday stock simple enough to update while life is happening.',
      children: [
        Row(
          children: [
            Expanded(child: _SummaryCard(label: 'Use soon', count: useSoon)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(label: 'Running low', count: runningLow)),
            const SizedBox(width: 8),
            Expanded(child: _SummaryCard(label: 'Need to buy', count: needToBuy)),
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
          'Common household items start with a sensible amount and unit. Adjust it before saving if your pack is different.',
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
                    Icon(
                      SupplyIconCatalog.iconFor(template.iconKey),
                      size: 18,
                      color: HomiColors.coral,
                    ),
                    const SizedBox(width: 7),
                    Text(template.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
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
                onDecrease: item.tracksQuantity
                    ? () => _adjustAmount(item, -1)
                    : null,
                onIncrease: item.tracksQuantity
                    ? () => _adjustAmount(item, 1)
                    : null,
                onAmountTap: () => _editAmount(context, item),
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
          Text('$count',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
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
    required this.onAmountTap,
    required this.onOptions,
    this.onDecrease,
    this.onIncrease,
  });

  final SupplyItem item;
  final DateTime now;
  final VoidCallback onAmountTap;
  final VoidCallback onOptions;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final displayStatus = item.effectiveStatus(now);
    final displayLabel = item.displayStatusLabel(now);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                SupplyIconCatalog.iconFor(item.iconKey),
                color: HomiColors.coral,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    item.expiryDate == null
                        ? item.category
                        : '${item.category} · expires ${item.expiryDate!.day}/${item.expiryDate!.month}/${item.expiryDate!.year}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  if (item.tracksQuantity) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniAmountButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Use one',
                          onTap: onDecrease,
                        ),
                        GestureDetector(
                          onTap: onAmountTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              item.quantityLabel!,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                        _MiniAmountButton(
                          icon: Icons.add_rounded,
                          tooltip: 'Add one',
                          onTap: onIncrease,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
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

class _MiniAmountButton extends StatelessWidget {
  const _MiniAmountButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: HomiColors.peach.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HomiColors.border),
          ),
          child: Icon(icon, size: 17, color: HomiColors.slate),
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
              fontSize: 12, fontWeight: FontWeight.w900, color: color),
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
            const Icon(Icons.shopping_bag_outlined,
                size: 34, color: HomiColors.coral),
            const SizedBox(height: 10),
            const Text('Nothing tracked yet',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Add fridge, pantry and household basics. Amounts are optional, so Homi can stay quick instead of becoming admin.',
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
  const _SupplyTemplate(
    this.name,
    this.category,
    this.iconKey,
    this.quantity,
    this.unit,
  );

  final String name;
  final String category;
  final String iconKey;
  final double quantity;
  final SupplyUnit unit;
}

class _SupplyDraft {
  const _SupplyDraft(
    this.name,
    this.category,
    this.status,
    this.expiryDate,
    this.iconKey,
    this.quantity,
    this.unit,
  );

  final String name;
  final String category;
  final SupplyStatus status;
  final DateTime? expiryDate;
  final String iconKey;
  final double? quantity;
  final SupplyUnit? unit;
}

class _SupplyAmountUpdate {
  const _SupplyAmountUpdate(this.quantity, this.unit);
  final double? quantity;
  final SupplyUnit? unit;
}

class _SupplyEditorSheet extends StatefulWidget {
  const _SupplyEditorSheet({this.template});
  final _SupplyTemplate? template;

  @override
  State<_SupplyEditorSheet> createState() => _SupplyEditorSheetState();
}

class _SupplyEditorSheetState extends State<_SupplyEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late String _category;
  SupplyStatus _status = SupplyStatus.okay;
  DateTime? _expiryDate;
  late String _iconKey;
  late SupplyUnit _unit;
  bool _trackAmount = true;
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
    _nameController = TextEditingController(text: widget.template?.name ?? '');
    _category = widget.template?.category ?? 'Pantry';
    _iconKey = widget.template?.iconKey ?? SupplyIconCatalog.defaultKey;
    _unit = widget.template?.unit ?? SupplyUnit.item;
    _quantityController = TextEditingController(
      text: _formatNumber(widget.template?.quantity ?? 1),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'Expiry date',
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      allowClear: true,
    );
    if (!mounted) return;
    if (selected != null) setState(() => _expiryDate = selected);
  }

  Future<void> _pickIcon() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose an icon',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Pick the one that makes this item easiest to recognise.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: SupplyIconCatalog.all.length,
                  itemBuilder: (context, index) {
                    final option = SupplyIconCatalog.all[index];
                    final active = option.key == _iconKey;
                    return GestureDetector(
                      onTap: () => Navigator.pop(context, option.key),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: active
                              ? HomiColors.peach.withValues(alpha: 0.30)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color:
                                active ? HomiColors.coral : HomiColors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(option.icon,
                                color: HomiColors.coral, size: 26),
                            const SizedBox(height: 6),
                            Text(
                              option.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _iconKey = selected);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the item a short name.');
      return;
    }
    double? quantity;
    SupplyUnit? unit;
    if (_trackAmount) {
      quantity = double.tryParse(_quantityController.text.trim().replaceAll(',', '.'));
      if (quantity == null || quantity < 0) {
        setState(() => _error = 'Enter a valid amount, or switch amount tracking off.');
        return;
      }
      unit = _unit;
    }
    Navigator.pop(
      context,
      _SupplyDraft(
        name,
        _category,
        _status,
        _expiryDate,
        _iconKey,
        quantity,
        unit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final icon = SupplyIconCatalog.optionFor(_iconKey);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a supply',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Track only what helps. Amounts make things like bread, eggs, bags and individual items easy to update after shopping.',
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
            Text('Amount', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<bool>(
              values: const [true, false],
              selected: _trackAmount,
              labelFor: (value) => value ? 'Track amount' : 'Status only',
              onSelected: (value) => setState(() => _trackAmount = value),
              compact: true,
            ),
            if (_trackAmount) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _quantityController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'How much do you have?',
                  hintText: 'e.g. 2 or 12',
                ),
              ),
              const SizedBox(height: 12),
              HomiChoiceGroup<SupplyUnit>(
                values: SupplyUnit.values,
                selected: _unit,
                labelFor: (value) => value.label,
                onSelected: (value) => setState(() => _unit = value),
                compact: true,
              ),
            ],
            const SizedBox(height: 18),
            Text('Icon', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickIcon,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: HomiColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon.icon, color: HomiColors.coral),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(icon.label,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900)),
                          Text('Tap to change',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Where is it?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<String>(
              values: _categories,
              selected: _category,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _category = value),
              compact: true,
            ),
            const SizedBox(height: 18),
            Text('Stock status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<SupplyStatus>(
              values: SuppliesPage._editableStatuses,
              selected: _status,
              labelFor: (value) => value.label,
              onSelected: (value) => setState(() => _status = value),
            ),
            const SizedBox(height: 18),
            HomiDateField(
              label: 'Expiry date',
              value: _expiryDate,
              optional: true,
              onTap: _pickExpiry,
              onClear: _expiryDate == null
                  ? null
                  : () => setState(() => _expiryDate = null),
            ),
            const SizedBox(height: 18),
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

class _SupplyAmountSheet extends StatefulWidget {
  const _SupplyAmountSheet({required this.item});
  final SupplyItem item;

  @override
  State<_SupplyAmountSheet> createState() => _SupplyAmountSheetState();
}

class _SupplyAmountSheetState extends State<_SupplyAmountSheet> {
  late final TextEditingController _controller;
  late SupplyUnit _unit;
  bool _tracking = true;

  @override
  void initState() {
    super.initState();
    _tracking = widget.item.tracksQuantity;
    _unit = widget.item.unit ?? SupplyUnit.item;
    _controller = TextEditingController(
      text: _formatNumber(widget.item.quantity ?? 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _current =>
      double.tryParse(_controller.text.trim().replaceAll(',', '.')) ?? 0;

  void _add(double amount) {
    final next = (_current + amount).clamp(0, 999999).toDouble();
    setState(() => _controller.text = _formatNumber(next));
  }

  void _save() {
    if (!_tracking) {
      Navigator.pop(context, const _SupplyAmountUpdate(null, null));
      return;
    }
    final amount = _current;
    Navigator.pop(context, _SupplyAmountUpdate(amount, _unit));
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Update ${widget.item.name}',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Designed for the moment you unpack shopping: change the number, use a quick add, and you are done.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            HomiChoiceGroup<bool>(
              values: const [true, false],
              selected: _tracking,
              labelFor: (value) => value ? 'Track amount' : 'Status only',
              onSelected: (value) => setState(() => _tracking = value),
              compact: true,
            ),
            if (_tracking) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  _AmountAction(icon: Icons.remove_rounded, onTap: () => _add(-1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textAlign: TextAlign.center,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _AmountAction(icon: Icons.add_rounded, onTap: () => _add(1)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <double>[1, 2, 6, 12]
                    .map(
                      (value) => OutlinedButton(
                        onPressed: () => _add(value),
                        child: Text('+${_formatNumber(value)}'),
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 14),
              Text('Unit', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              HomiChoiceGroup<SupplyUnit>(
                values: SupplyUnit.values,
                selected: _unit,
                labelFor: (value) => value.label,
                onSelected: (value) => setState(() => _unit = value),
                compact: true,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save amount')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountAction extends StatelessWidget {
  const _AmountAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: HomiColors.peach.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: HomiColors.border),
        ),
        child: Icon(icon, color: HomiColors.coral),
      ),
    );
  }
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
