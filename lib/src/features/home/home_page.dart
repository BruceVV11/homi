import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/home_event.dart';
import '../../domain/home_inputs.dart';
import '../../domain/home_thing.dart';
import '../../domain/utility_reading.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
import '../../widgets/homi_date_time_controls.dart';
import '../../widgets/homi_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.homeName,
    required this.homeType,
    required this.things,
    required this.events,
    required this.readings,
    required this.actorName,
    required this.onAddThing,
    required this.onRemoveThing,
    required this.onAddEvent,
    required this.onRemoveEvent,
    required this.onAddReading,
    required this.onRemoveReading,
    super.key,
  });

  final String homeName;
  final String homeType;
  final List<HomeThing> things;
  final List<HomeEvent> events;
  final List<UtilityReading> readings;
  final String actorName;
  final Future<void> Function(HomeThingInput input) onAddThing;
  final Future<void> Function(String id) onRemoveThing;
  final Future<void> Function(HomeEventInput input) onAddEvent;
  final Future<void> Function(String id) onRemoveEvent;
  final Future<void> Function(UtilityReadingInput input) onAddReading;
  final Future<void> Function(String id) onRemoveReading;

  Future<void> _addThing(BuildContext context) async {
    final input = await showModalBottomSheet<HomeThingInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _ThingEditorSheet(),
    );
    if (input != null) await onAddThing(input);
  }

  Future<void> _addEvent(BuildContext context) async {
    final input = await showModalBottomSheet<HomeEventInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventEditorSheet(
        things: things,
        actorName: actorName,
      ),
    );
    if (input != null) await onAddEvent(input);
  }

  Future<void> _addReading(BuildContext context) async {
    final input = await showModalBottomSheet<UtilityReadingInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ReadingEditorSheet(actorName: actorName),
    );
    if (input != null) await onAddReading(input);
  }

  Future<void> _removeThing(BuildContext context, HomeThing item) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove ${item.name}?',
      message:
          'This removes the item and any maintenance or repair entries linked to it from this phone.',
      confirmLabel: 'Remove item',
      cancelLabel: 'Keep item',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) await onRemoveThing(item.id);
  }

  Future<void> _removeEvent(BuildContext context, HomeEvent item) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove this ${item.type.label.toLowerCase()} entry?',
      message: '“${item.title}” will be removed from your home history.',
      confirmLabel: 'Remove entry',
      cancelLabel: 'Keep entry',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) await onRemoveEvent(item.id);
  }

  Future<void> _removeReading(BuildContext context, UtilityReading item) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove reading?',
      message:
          '${item.type.label} ${item.value.toStringAsFixed(1)} ${item.unit} will be removed from this phone.',
      confirmLabel: 'Remove reading',
      cancelLabel: 'Keep reading',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) await onRemoveReading(item.id);
  }

  void _showHowHomeWorks(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How Home works',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Home is your practical record for the physical place you live in. Add only the details that will be useful later.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              const _InfoPoint(
                icon: Icons.kitchen_outlined,
                title: 'Things',
                text:
                    'Keep appliances, pumps, geysers, equipment and other useful-to-remember items together with service and warranty dates.',
              ),
              const _InfoPoint(
                icon: Icons.handyman_outlined,
                title: 'Maintenance & repairs',
                text:
                    'Record work after it happens so you can later see what was fixed, when it was done and who handled it.',
              ),
              const _InfoPoint(
                icon: Icons.bolt_outlined,
                title: 'Utilities',
                text:
                    'Save electricity and water meter readings over time. Homi keeps who recorded each reading and when.',
              ),
              const _InfoPoint(
                icon: Icons.lock_outline_rounded,
                title: 'Your Home is not your People list',
                text:
                    'A trusted friend or location connection does not automatically get access to this information. Household sharing will always be a separate, explicit permission.',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
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
    final serviceAttention = things
        .where((item) => item.serviceDue(now) || item.serviceSoon(now))
        .length;
    final latestElectricity = _latestReading(UtilityType.electricity);
    final latestWater = _latestReading(UtilityType.water);

    return HomiPage(
      title: homeName,
      subtitle: '$homeType · the practical details that keep your place running.',
      children: [
        Row(
          children: [
            Expanded(
              child: _HomeSummary(
                icon: Icons.kitchen_outlined,
                value: '${things.length}',
                label: things.length == 1 ? 'Thing' : 'Things',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HomeSummary(
                icon: Icons.build_outlined,
                value: '$serviceAttention',
                label: 'Service soon',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _HomeSummary(
                icon: Icons.history_rounded,
                value: '${events.length}',
                label: 'History',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showHowHomeWorks(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 19, color: HomiColors.muted),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Keep the useful history of your home here. See what belongs in Home.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: HomiColors.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SectionHeader(
          title: 'Things',
          action: 'Add item',
          onTap: () => _addThing(context),
        ),
        const SizedBox(height: 6),
        Text(
          'Appliances, equipment and other items worth remembering.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (things.isEmpty)
          _EmptyHomeCard(
            icon: Icons.kitchen_outlined,
            title: 'No home items yet',
            message:
                'Add an appliance, geyser, pool pump or anything else you may need to service, repair or look up later.',
            action: 'Add first item',
            onTap: () => _addThing(context),
          )
        else
          ...things.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ThingCard(
                item: item,
                now: now,
                onRemove: () => _removeThing(context, item),
              ),
            ),
          ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Maintenance & repairs',
          action: 'Log work',
          onTap: () => _addEvent(context),
        ),
        const SizedBox(height: 6),
        Text(
          'Keep a simple record of what was serviced or repaired, when it happened and who handled it.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          _EmptyHomeCard(
            icon: Icons.handyman_outlined,
            title: 'No maintenance history yet',
            message:
                'Completed maintenance and repairs will build a useful history here.',
            action: 'Log first entry',
            onTap: () => _addEvent(context),
          )
        else
          ...events.take(8).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EventCard(
                item: item,
                thingName: _thingName(item.thingId),
                onRemove: () => _removeEvent(context, item),
              ),
            ),
          ),
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Utilities',
          action: 'Add reading',
          onTap: () => _addReading(context),
        ),
        const SizedBox(height: 6),
        Text(
          'Build a simple history of meter readings without needing a spreadsheet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ReadingSummary(
                type: UtilityType.electricity,
                reading: latestElectricity,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReadingSummary(
                type: UtilityType.water,
                reading: latestWater,
              ),
            ),
          ],
        ),
        if (readings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...readings.take(6).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReadingRow(
                item: item,
                onRemove: () => _removeReading(context, item),
              ),
            ),
          ),
        ],
      ],
    );
  }

  UtilityReading? _latestReading(UtilityType type) {
    final matching = readings.where((item) => item.type == type).toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return matching.isEmpty ? null : matching.first;
  }

  String? _thingName(String? thingId) {
    if (thingId == null) return null;
    for (final item in things) {
      if (item.id == thingId) return item.name;
    }
    return null;
  }
}

class _HomeSummary extends StatelessWidget {
  const _HomeSummary({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: HomiColors.coral),
          const SizedBox(height: 5),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(action),
        ),
      ],
    );
  }
}

class _ThingCard extends StatelessWidget {
  const _ThingCard({
    required this.item,
    required this.now,
    required this.onRemove,
  });

  final HomeThing item;
  final DateTime now;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final due = item.serviceDue(now);
    final soon = item.serviceSoon(now);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 6, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.kitchen_outlined,
                  color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    [
                      item.location,
                      item.category,
                      if (item.brandModel?.trim().isNotEmpty == true)
                        item.brandModel!,
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (item.nextServiceDate != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      due
                          ? 'Service is due'
                          : 'Service ${DateFormat('d MMM yyyy').format(item.nextServiceDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: due || soon ? HomiColors.coral : HomiColors.muted,
                      ),
                    ),
                  ],
                  if (item.warrantyUntil != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Warranty until ${DateFormat('d MMM yyyy').format(item.warrantyUntil!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Item options',
              onPressed: onRemove,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.item,
    required this.thingName,
    required this.onRemove,
  });
  final HomeEvent item;
  final String? thingName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 13, 6, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              item.type == HomeEventType.repair
                  ? Icons.build_circle_outlined
                  : Icons.handyman_outlined,
              color: HomiColors.coral,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    '${item.type.label} · ${DateFormat('d MMM yyyy').format(item.date)}${thingName == null ? '' : ' · $thingName'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Recorded by ${item.completedByName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: HomiColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'History options',
              onPressed: onRemove,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingSummary extends StatelessWidget {
  const _ReadingSummary({required this.type, required this.reading});
  final UtilityType type;
  final UtilityReading? reading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            type == UtilityType.electricity
                ? Icons.bolt_outlined
                : Icons.water_drop_outlined,
            color: HomiColors.coral,
          ),
          const SizedBox(height: 8),
          Text(type.label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            reading == null
                ? 'No reading yet'
                : '${reading!.value.toStringAsFixed(1)} ${reading!.unit}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ReadingRow extends StatelessWidget {
  const _ReadingRow({required this.item, required this.onRemove});
  final UtilityReading item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 5, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.type.label} · ${item.value.toStringAsFixed(1)} ${item.unit} · ${DateFormat('d MMM · HH:mm').format(item.recordedAt)} · ${item.recordedByName}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Remove reading',
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeCard extends StatelessWidget {
  const _EmptyHomeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 32, color: HomiColors.coral),
            const SizedBox(height: 9),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _ThingEditorSheet extends StatefulWidget {
  const _ThingEditorSheet();

  @override
  State<_ThingEditorSheet> createState() => _ThingEditorSheetState();
}

class _ThingEditorSheetState extends State<_ThingEditorSheet> {
  final _name = TextEditingController();
  final _brandModel = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Appliance';
  String _location = 'Kitchen';
  DateTime? _serviceDate;
  DateTime? _warrantyDate;
  String? _error;

  static const _categories = <String>[
    'Appliance',
    'Heating & cooling',
    'Plumbing',
    'Electrical',
    'Outdoor',
    'Other',
  ];
  static const _locations = <String>[
    'Kitchen',
    'Living area',
    'Bedroom',
    'Bathroom',
    'Garage',
    'Outdoor',
    'Other',
  ];

  @override
  void dispose() {
    _name.dispose();
    _brandModel.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickServiceDate() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'Next service date',
      initialDate:
          _serviceDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _serviceDate = selected);
  }

  Future<void> _pickWarrantyDate() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'Warranty end date',
      initialDate:
          _warrantyDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 7300)),
    );
    if (selected != null && mounted) setState(() => _warrantyDate = selected);
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the item a name.');
      return;
    }
    Navigator.pop(
      context,
      HomeThingInput(
        name: _name.text.trim(),
        category: _category,
        location: _location,
        brandModel: _brandModel.text,
        nextServiceDate: _serviceDate,
        warrantyUntil: _warrantyDate,
        notes: _notes.text,
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a home item',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Save the details you are most likely to need later.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Item',
                hintText: 'e.g. Geyser',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _brandModel,
              decoration:
                  const InputDecoration(labelText: 'Brand / model (optional)'),
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Type'),
            const SizedBox(height: 9),
            HomiChoiceGroup<String>(
              values: _categories,
              selected: _category,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _category = value),
              compact: true,
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Where is it?'),
            const SizedBox(height: 9),
            HomiChoiceGroup<String>(
              values: _locations,
              selected: _location,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _location = value),
              compact: true,
            ),
            const SizedBox(height: 18),
            HomiDateField(
              label: 'Next service date',
              value: _serviceDate,
              optional: true,
              onTap: _pickServiceDate,
              onClear: _serviceDate == null
                  ? null
                  : () => setState(() => _serviceDate = null),
            ),
            const SizedBox(height: 14),
            HomiDateField(
              label: 'Warranty until',
              value: _warrantyDate,
              optional: true,
              onTap: _pickWarrantyDate,
              onClear: _warrantyDate == null
                  ? null
                  : () => setState(() => _warrantyDate = null),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Add item'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({required this.things, required this.actorName});
  final List<HomeThing> things;
  final String actorName;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  HomeEventType _type = HomeEventType.maintenance;
  String _thingId = '__home__';
  DateTime _date = DateTime.now();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'When was the work done?',
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  void _submit() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give this entry a short title.');
      return;
    }
    Navigator.pop(
      context,
      HomeEventInput(
        type: _type,
        title: _title.text.trim(),
        date: _date,
        completedByName: widget.actorName,
        thingId: _thingId == '__home__' ? null : _thingId,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thingValues = <String>[
      '__home__',
      ...widget.things.map((item) => item.id),
    ];
    String labelForThing(String id) {
      if (id == '__home__') return 'General home';
      for (final item in widget.things) {
        if (item.id == id) return item.name;
      }
      return 'Home item';
    }

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
            Text('Log maintenance or repair',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            HomiChoiceGroup<HomeEventType>(
              values: HomeEventType.values,
              selected: _type,
              labelFor: (value) => value.label,
              onSelected: (value) => setState(() => _type = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'What was done?',
                hintText: 'e.g. Replaced pool pump seal',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (thingValues.length > 1) ...[
              const SizedBox(height: 18),
              const _FieldLabel('Linked to'),
              const SizedBox(height: 9),
              HomiChoiceGroup<String>(
                values: thingValues,
                selected: _thingId,
                labelFor: labelForThing,
                onSelected: (value) => setState(() => _thingId = value),
                compact: true,
              ),
            ],
            const SizedBox(height: 18),
            HomiDateField(label: 'Date', value: _date, onTap: _pickDate),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save to history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadingEditorSheet extends StatefulWidget {
  const _ReadingEditorSheet({required this.actorName});
  final String actorName;

  @override
  State<_ReadingEditorSheet> createState() => _ReadingEditorSheetState();
}

class _ReadingEditorSheetState extends State<_ReadingEditorSheet> {
  final _value = TextEditingController();
  final _notes = TextEditingController();
  UtilityType _type = UtilityType.electricity;
  String _unit = UtilityType.electricity.defaultUnit;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setType(UtilityType value) {
    setState(() {
      _type = value;
      _unit = value.defaultUnit;
    });
  }

  Future<void> _pickDate() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'Reading date',
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showHomiTimePicker(
      context,
      title: 'Reading time',
      initialTime: _time,
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _submit() {
    final reading = double.tryParse(_value.text.trim().replaceAll(',', '.'));
    if (reading == null || reading < 0) {
      setState(() => _error = 'Enter a valid meter reading.');
      return;
    }
    Navigator.pop(
      context,
      UtilityReadingInput(
        type: _type,
        value: reading,
        unit: _unit,
        recordedAt: DateTime(
          _date.year,
          _date.month,
          _date.day,
          _time.hour,
          _time.minute,
        ),
        recordedByName: widget.actorName,
        notes: _notes.text,
      ),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a meter reading',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            HomiChoiceGroup<UtilityType>(
              values: UtilityType.values,
              selected: _type,
              labelFor: (value) => value.label,
              onSelected: _setType,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _value,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: 'Reading', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Unit'),
            const SizedBox(height: 8),
            HomiChoiceGroup<String>(
              values: _type.unitOptions,
              selected: _unit,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _unit = value),
              compact: true,
            ),
            const SizedBox(height: 14),
            HomiDateField(label: 'Date', value: _date, onTap: _pickDate),
            const SizedBox(height: 12),
            HomiTimeField(label: 'Time', value: _time, onTap: _pickTime),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Save reading'),
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

class _InfoPoint extends StatelessWidget {
  const _InfoPoint({
    required this.icon,
    required this.title,
    required this.text,
  });
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HomiColors.peach.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: HomiColors.coral),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(text, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
