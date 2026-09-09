import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/home_event.dart';
import '../../domain/home_inputs.dart';
import '../../domain/home_thing.dart';
import '../../domain/utility_reading.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
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
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) await onRemoveReading(item.id);
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
        const SizedBox(height: 22),
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
            message: 'Completed maintenance and repairs will build a useful history here.',
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
    for (final reading in readings) {
      if (reading.type == type) return reading;
    }
    return null;
  }

  String? _thingName(String? id) {
    if (id == null) return null;
    for (final item in things) {
      if (item.id == id) return item.name;
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: HomiColors.coral),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add_rounded, size: 17),
          label: Text(action),
        ),
      ],
    );
  }
}

class _ThingCard extends StatelessWidget {
  const _ThingCard({required this.item, required this.now, required this.onRemove});

  final HomeThing item;
  final DateTime now;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final due = item.serviceDue(now);
    final soon = item.serviceSoon(now);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
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
              child: const Icon(Icons.home_repair_service_outlined, color: HomiColors.coral),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    [item.category, item.location, item.brandModel]
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .join(' · '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (item.nextServiceDate != null) ...[
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.build_circle_outlined,
                          size: 16,
                          color: due || soon ? HomiColors.coral : HomiColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            due
                                ? 'Service is due'
                                : soon
                                    ? 'Service due ${DateFormat('d MMM yyyy').format(item.nextServiceDate!)}'
                                    : 'Next service ${DateFormat('d MMM yyyy').format(item.nextServiceDate!)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: due || soon ? HomiColors.coral : HomiColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Item options',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
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
        padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
        child: Row(
          children: [
            Icon(
              item.type == HomeEventType.repair
                  ? Icons.handyman_outlined
                  : Icons.build_outlined,
              color: HomiColors.coral,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    '${item.type.label}${thingName == null ? '' : ' · $thingName'} · ${DateFormat('d MMM yyyy').format(item.date)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Logged by ${item.completedByName}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove history entry',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
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
            const SizedBox(height: 4),
            Text(
              reading == null
                  ? 'No reading yet'
                  : '${reading!.value.toStringAsFixed(1)} ${reading!.unit}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.type.label} · ${item.value.toStringAsFixed(1)} ${item.unit} · ${DateFormat('d MMM').format(item.recordedAt)}',
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
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  String _category = 'Appliance';
  String _location = 'Kitchen';
  bool _hasServiceDate = false;
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
  void initState() {
    super.initState();
    final now = DateTime.now().add(const Duration(days: 30));
    _day.text = now.day.toString().padLeft(2, '0');
    _month.text = now.month.toString().padLeft(2, '0');
    _year.text = now.year.toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _brandModel.dispose();
    _notes.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  DateTime? _serviceDate() {
    if (!_hasServiceDate) return null;
    final day = int.tryParse(_day.text.trim());
    final month = int.tryParse(_month.text.trim());
    final year = int.tryParse(_year.text.trim());
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    if (value.day != day || value.month != month || value.year != year) return null;
    return value;
  }

  void _submit() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the item a name.');
      return;
    }
    final serviceDate = _serviceDate();
    if (_hasServiceDate && serviceDate == null) {
      setState(() => _error = 'Enter a valid service date.');
      return;
    }
    Navigator.pop(
      context,
      HomeThingInput(
        name: _name.text.trim(),
        category: _category,
        location: _location,
        brandModel: _brandModel.text,
        nextServiceDate: serviceDate,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a home item', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Save the details you are most likely to need later.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: InputDecoration(labelText: 'Item', hintText: 'e.g. Geyser', errorText: _error),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(controller: _brandModel, decoration: const InputDecoration(labelText: 'Brand / model (optional)')),
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
            Row(
              children: [
                const Expanded(child: _FieldLabel('Next service date')),
                TextButton(
                  onPressed: () => setState(() => _hasServiceDate = !_hasServiceDate),
                  child: Text(_hasServiceDate ? 'Remove' : 'Add date'),
                ),
              ],
            ),
            if (_hasServiceDate) ...[
              const SizedBox(height: 8),
              _DateFields(day: _day, month: _month, year: _year),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Add item'))),
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
  final _day = TextEditingController();
  final _month = TextEditingController();
  final _year = TextEditingController();
  HomeEventType _type = HomeEventType.maintenance;
  String _thingId = '__home__';
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day.text = now.day.toString().padLeft(2, '0');
    _month.text = now.month.toString().padLeft(2, '0');
    _year.text = now.year.toString();
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _day.dispose();
    _month.dispose();
    _year.dispose();
    super.dispose();
  }

  DateTime? _date() {
    final day = int.tryParse(_day.text.trim());
    final month = int.tryParse(_month.text.trim());
    final year = int.tryParse(_year.text.trim());
    if (day == null || month == null || year == null) return null;
    final value = DateTime(year, month, day);
    if (value.day != day || value.month != month || value.year != year) return null;
    return value;
  }

  void _submit() {
    final date = _date();
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give this entry a short title.');
      return;
    }
    if (date == null) {
      setState(() => _error = 'Enter a valid date.');
      return;
    }
    Navigator.pop(
      context,
      HomeEventInput(
        type: _type,
        title: _title.text.trim(),
        date: date,
        completedByName: widget.actorName,
        thingId: _thingId == '__home__' ? null : _thingId,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final thingValues = <String>['__home__', ...widget.things.map((item) => item.id)];
    String labelForThing(String id) {
      if (id == '__home__') return 'General home';
      for (final item in widget.things) {
        if (item.id == id) return item.name;
      }
      return 'Home item';
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Log maintenance or repair', style: Theme.of(context).textTheme.headlineSmall),
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
            const _FieldLabel('Date'),
            const SizedBox(height: 8),
            _DateFields(day: _day, month: _month, year: _year),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Save to history'))),
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
  final _unit = TextEditingController(text: 'kWh');
  final _notes = TextEditingController();
  UtilityType _type = UtilityType.electricity;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    _unit.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setType(UtilityType value) {
    setState(() {
      _type = value;
      _unit.text = value.defaultUnit;
    });
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
        unit: _unit.text,
        recordedAt: DateTime.now(),
        recordedByName: widget.actorName,
        notes: _notes.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add a meter reading', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            HomiChoiceGroup<UtilityType>(
              values: UtilityType.values,
              selected: _type,
              labelFor: (value) => value.label,
              onSelected: _setType,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _value,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Reading', errorText: _error),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: const Text('Save reading'))),
          ],
        ),
      ),
    );
  }
}

class _DateFields extends StatelessWidget {
  const _DateFields({required this.day, required this.month, required this.year});

  final TextEditingController day;
  final TextEditingController month;
  final TextEditingController year;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: day,
            keyboardType: TextInputType.number,
            maxLength: 2,
            decoration: const InputDecoration(labelText: 'Day', counterText: ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: month,
            keyboardType: TextInputType.number,
            maxLength: 2,
            decoration: const InputDecoration(labelText: 'Month', counterText: ''),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            controller: year,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: const InputDecoration(labelText: 'Year', counterText: ''),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900));
  }
}
