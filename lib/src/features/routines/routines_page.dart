import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/routine_create_data.dart';
import '../../domain/routine_item.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
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
  final Future<void> Function(RoutineCreateData data) onAdd;
  final Future<void> Function(String id) onToggle;
  final Future<void> Function(String id) onRemove;

  static const _examples = <_RoutineTemplate>[
    _RoutineTemplate(
      icon: Icons.pets_rounded,
      title: 'Feed the pets',
      category: 'Pets',
      repeat: RoutineRepeat.daily,
      estimatedMinutes: 5,
      dueHour: 7,
      dueMinute: 0,
    ),
    _RoutineTemplate(
      icon: Icons.delete_outline_rounded,
      title: 'Take the bins out',
      category: 'Chores',
      repeat: RoutineRepeat.weekly,
      estimatedMinutes: 10,
      repeatDays: <int>[1],
      dueHour: 18,
      dueMinute: 0,
    ),
    _RoutineTemplate(
      icon: Icons.bed_outlined,
      title: 'Change bed linen',
      category: 'Chores',
      repeat: RoutineRepeat.weekly,
      estimatedMinutes: 15,
      repeatDays: <int>[6],
      dueHour: 9,
      dueMinute: 0,
    ),
    _RoutineTemplate(
      icon: Icons.local_florist_outlined,
      title: 'Water indoor plants',
      category: 'Plants & garden',
      repeat: RoutineRepeat.weekly,
      estimatedMinutes: 10,
      repeatDays: <int>[7],
      dueHour: 9,
      dueMinute: 0,
    ),
  ];

  Future<void> _addRoutine(
    BuildContext context, {
    _RoutineTemplate? template,
  }) async {
    final draft = await showModalBottomSheet<RoutineCreateData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RoutineEditorSheet(template: template),
    );
    if (draft != null) await onAdd(draft);
  }

  Future<void> _showOptions(BuildContext context, RoutineItem item) async {
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
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 5),
              Text('Routine options', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
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
                      title: 'Remove routine?',
                      message:
                          '“${item.title}” and its completion history will be removed from this phone.',
                      confirmLabel: 'Remove routine',
                      cancelLabel: 'Keep routine',
                      icon: Icons.delete_outline_rounded,
                      destructive: true,
                    );
                    if (confirmed) await onRemove(item.id);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove routine'),
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
    final dueCount = items.where((item) => item.isDue(now)).length;
    final displayItems = List<RoutineItem>.of(items)
      ..sort((a, b) {
        final aDue = a.isDue(now);
        final bDue = b.isDue(now);
        if (aDue != bDue) return aDue ? -1 : 1;
        final aNext = a.nextDueAt ?? a.initialDueAt();
        final bNext = b.nextDueAt ?? b.initialDueAt();
        return aNext.compareTo(bNext);
      });

    return HomiPage(
      title: 'Routines',
      subtitle: 'Keep recurring home jobs visible, timed and easy to recognise.',
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                items.isEmpty
                    ? 'Start with one job you regularly need to remember.'
                    : dueCount == 0
                        ? 'Everything scheduled is up to date.'
                        : '$dueCount ${dueCount == 1 ? 'routine needs' : 'routines need'} attention.',
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
          ...displayItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RoutineCard(
                item: item,
                now: now,
                onToggle: () => onToggle(item.id),
                onOptions: () => _showOptions(context, item),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text('Common routines', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Tap one to start with a realistic schedule, then adjust it to suit your home.',
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
    required this.now,
    required this.onToggle,
    required this.onOptions,
  });

  final RoutineItem item;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final due = item.isDue(now);
    final last = item.lastCompletion;
    final completedForCurrentCycle = !due && last != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 13, 7, 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: completedForCurrentCycle
                      ? HomiColors.coral
                      : HomiColors.peach.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: completedForCurrentCycle
                        ? HomiColors.coral
                        : HomiColors.border,
                  ),
                ),
                child: Icon(
                  completedForCurrentCycle
                      ? Icons.check_rounded
                      : Icons.check_rounded,
                  color: completedForCurrentCycle
                      ? Colors.white
                      : HomiColors.muted,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (item.repeats) ...[
                        const Icon(
                          Icons.repeat_rounded,
                          size: 17,
                          color: HomiColors.coral,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.category} · ${_scheduleLabel(item)} · about ${item.estimatedMinutes} min',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      'Done ${DateFormat('d MMM · HH:mm').format(last.at)} by ${last.byName}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF6F8B65),
                      ),
                    ),
                  ],
                  if (item.repeats) ...[
                    const SizedBox(height: 4),
                    Text(
                      due
                          ? 'Due now'
                          : 'Next ${DateFormat('EEE d MMM · HH:mm').format(item.nextDueAt ?? item.initialDueAt())}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: due ? HomiColors.coral : HomiColors.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Routine options',
              onPressed: onOptions,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String _scheduleLabel(RoutineItem item) {
  if (!item.repeats) return 'As needed';
  final time =
      '${item.dueHour.toString().padLeft(2, '0')}:${item.dueMinute.toString().padLeft(2, '0')}';
  switch (item.repeat) {
    case RoutineRepeat.once:
      return 'As needed';
    case RoutineRepeat.daily:
      return 'Daily at $time';
    case RoutineRepeat.weekdays:
      return 'Weekdays at $time';
    case RoutineRepeat.weekly:
      final days = item.repeatDays.isEmpty
          ? <int>[item.createdAt.weekday]
          : item.repeatDays;
      return '${days.map(_shortDay).join(', ')} at $time';
    case RoutineRepeat.monthly:
      return 'Day ${item.dayOfMonth ?? item.createdAt.day} each month at $time';
  }
}

String _shortDay(int weekday) {
  const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final index = (weekday - 1).clamp(0, 6).toInt();
  return days[index];
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
              'Add the things that repeat around home. Homi can show when they are due, who last completed them and when they come around again.',
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
  const _RoutineExampleTile({required this.template, required this.onTap});

  final _RoutineTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
                    Text(template.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${_templateSchedule(template)} · about ${template.estimatedMinutes} min',
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

String _templateSchedule(_RoutineTemplate template) {
  final time =
      '${template.dueHour.toString().padLeft(2, '0')}:${template.dueMinute.toString().padLeft(2, '0')}';
  if (template.repeat == RoutineRepeat.daily) return 'Daily at $time';
  if (template.repeat == RoutineRepeat.weekly) {
    return '${template.repeatDays.map(_shortDay).join(', ')} at $time';
  }
  return template.repeat.label;
}

class _RoutineTemplate {
  const _RoutineTemplate({
    required this.icon,
    required this.title,
    required this.category,
    required this.repeat,
    required this.estimatedMinutes,
    required this.dueHour,
    required this.dueMinute,
    this.repeatDays = const <int>[],
    this.dayOfMonth,
  });

  final IconData icon;
  final String title;
  final String category;
  final RoutineRepeat repeat;
  final int estimatedMinutes;
  final int dueHour;
  final int dueMinute;
  final List<int> repeatDays;
  final int? dayOfMonth;
}

class _RoutineEditorSheet extends StatefulWidget {
  const _RoutineEditorSheet({this.template});

  final _RoutineTemplate? template;

  @override
  State<_RoutineEditorSheet> createState() => _RoutineEditorSheetState();
}

class _RoutineEditorSheetState extends State<_RoutineEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _dayOfMonthController;
  late String _category;
  late RoutineRepeat _repeat;
  late int _estimatedMinutes;
  late Set<int> _repeatDays;
  String? _error;

  static const _categories = <String>[
    'Chores',
    'Pets',
    'Plants & garden',
    'Pool & outdoor',
    'Cleaning',
    'Home',
  ];

  static const _repeatOptions = <RoutineRepeat>[
    RoutineRepeat.once,
    RoutineRepeat.daily,
    RoutineRepeat.weekdays,
    RoutineRepeat.weekly,
    RoutineRepeat.monthly,
  ];

  static const _durations = <int>[5, 10, 15, 20, 30, 45, 60];
  static const _weekdays = <int>[1, 2, 3, 4, 5, 6, 7];

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _category = template?.category ?? 'Chores';
    _repeat = template?.repeat ?? RoutineRepeat.daily;
    _estimatedMinutes = template?.estimatedMinutes ?? 10;
    _repeatDays = (template?.repeatDays ?? <int>[]).toSet();
    if (_repeat == RoutineRepeat.weekly && _repeatDays.isEmpty) {
      _repeatDays = <int>{DateTime.now().weekday};
    }
    _hourController = TextEditingController(
      text: (template?.dueHour ?? 9).toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: (template?.dueMinute ?? 0).toString().padLeft(2, '0'),
    );
    _dayOfMonthController = TextEditingController(
      text: (template?.dayOfMonth ?? DateTime.now().day).toString(),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _dayOfMonthController.dispose();
    super.dispose();
  }

  String _repeatLabel(RoutineRepeat value) {
    return value == RoutineRepeat.once ? 'As needed' : value.label;
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the routine a short name.');
      return;
    }

    var hour = 9;
    var minute = 0;
    if (_repeat != RoutineRepeat.once) {
      final parsedHour = int.tryParse(_hourController.text.trim());
      final parsedMinute = int.tryParse(_minuteController.text.trim());
      if (parsedHour == null || parsedHour < 0 || parsedHour > 23) {
        setState(() => _error = 'Enter an hour from 00 to 23.');
        return;
      }
      if (parsedMinute == null || parsedMinute < 0 || parsedMinute > 59) {
        setState(() => _error = 'Enter minutes from 00 to 59.');
        return;
      }
      if (_repeat == RoutineRepeat.weekly && _repeatDays.isEmpty) {
        setState(() => _error = 'Choose at least one day for a weekly routine.');
        return;
      }
      hour = parsedHour;
      minute = parsedMinute;
    }

    int? dayOfMonth;
    if (_repeat == RoutineRepeat.monthly) {
      dayOfMonth = int.tryParse(_dayOfMonthController.text.trim());
      if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
        setState(() => _error = 'Enter a day from 1 to 31.');
        return;
      }
    }

    final repeatDays = _repeat == RoutineRepeat.weekly
        ? (List<int>.of(_repeatDays)..sort())
        : const <int>[];

    Navigator.pop(
      context,
      RoutineCreateData(
        title: title,
        category: _category,
        repeat: _repeat,
        estimatedMinutes: _estimatedMinutes,
        dueHour: hour,
        dueMinute: minute,
        repeatDays: repeatDays,
        dayOfMonth: dayOfMonth,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a routine', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Set when it repeats and Homi will bring it back when it is due again.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: widget.template == null,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Routine',
                hintText: 'e.g. Feed the dogs',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Category'),
            const SizedBox(height: 9),
            HomiChoiceGroup<String>(
              values: _categories,
              selected: _category,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _category = value),
              compact: true,
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Repeats'),
            const SizedBox(height: 9),
            HomiChoiceGroup<RoutineRepeat>(
              values: _repeatOptions,
              selected: _repeat,
              labelFor: _repeatLabel,
              onSelected: (value) {
                setState(() {
                  _repeat = value;
                  if (value == RoutineRepeat.weekly && _repeatDays.isEmpty) {
                    _repeatDays = <int>{DateTime.now().weekday};
                  }
                });
              },
              compact: true,
            ),
            if (_repeat == RoutineRepeat.weekly) ...[
              const SizedBox(height: 18),
              const _FieldLabel('Days'),
              const SizedBox(height: 9),
              HomiMultiChoiceGroup<int>(
                values: _weekdays,
                selected: _repeatDays,
                labelFor: _shortDay,
                onChanged: (value) => setState(() => _repeatDays = value),
              ),
            ],
            if (_repeat == RoutineRepeat.monthly) ...[
              const SizedBox(height: 18),
              TextField(
                controller: _dayOfMonthController,
                keyboardType: TextInputType.number,
                maxLength: 2,
                decoration: const InputDecoration(
                  labelText: 'Day of the month',
                  hintText: '15',
                  counterText: '',
                ),
              ),
            ],
            if (_repeat != RoutineRepeat.once) ...[
              const SizedBox(height: 20),
              const _FieldLabel('Time'),
              const SizedBox(height: 4),
              Text(
                'Use 24-hour time, for example 14:30.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _hourController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'Hour',
                        counterText: '',
                        hintText: '14',
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _minuteController,
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      decoration: const InputDecoration(
                        labelText: 'Minutes',
                        counterText: '',
                        hintText: '30',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Usually takes'),
            const SizedBox(height: 9),
            HomiChoiceGroup<int>(
              values: _durations,
              selected: _estimatedMinutes,
              labelFor: (minutes) => '$minutes min',
              onSelected: (value) => setState(() => _estimatedMinutes = value),
              compact: true,
            ),
            const SizedBox(height: 22),
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900));
  }
}
