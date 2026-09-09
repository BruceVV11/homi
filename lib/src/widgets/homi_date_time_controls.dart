import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/homi_theme.dart';

Future<DateTime?> showHomiDatePicker(
  BuildContext context, {
  required String title,
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  bool allowClear = false,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime?>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _HomiDatePickerSheet(
      title: title,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 10, 1, 1),
      lastDate: lastDate ?? DateTime(now.year + 10, 12, 31),
      allowClear: allowClear,
    ),
  );
}

Future<TimeOfDay?> showHomiTimePicker(
  BuildContext context, {
  required String title,
  TimeOfDay? initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _HomiTimePickerSheet(
      title: title,
      initialTime: initialTime ?? TimeOfDay.now(),
    ),
  );
}

Future<int?> showHomiDayOfMonthPicker(
  BuildContext context, {
  required String title,
  int initialDay = 1,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Choose the day Homi should use each month. Shorter months use their last day.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List<Widget>.generate(31, (index) {
                final day = index + 1;
                final selected = day == initialDay;
                return GestureDetector(
                  onTap: () => Navigator.pop(context, day),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? HomiColors.coral
                          : HomiColors.peach.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? HomiColors.coral : HomiColors.border,
                      ),
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : HomiColors.slate,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    ),
  );
}

class HomiDateField extends StatelessWidget {
  const HomiDateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.optional = false,
    this.onClear,
    super.key,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool optional;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return _HomiPickerField(
      label: label,
      value: value == null
          ? (optional ? 'Not set' : 'Choose date')
          : DateFormat('EEE, d MMM yyyy').format(value!),
      icon: Icons.calendar_month_outlined,
      onTap: onTap,
      onClear: value == null ? null : onClear,
    );
  }
}

class HomiTimeField extends StatelessWidget {
  const HomiTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.optional = false,
    this.onClear,
    super.key,
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;
  final bool optional;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? (optional ? 'Not set' : 'Choose time')
        : '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}';
    return _HomiPickerField(
      label: label,
      value: display,
      icon: Icons.schedule_outlined,
      onTap: onTap,
      onClear: value == null ? null : onClear,
    );
  }
}

class _HomiPickerField extends StatelessWidget {
  const _HomiPickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: HomiColors.muted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HomiColors.border),
              ),
              child: Row(
                children: [
                  Icon(icon, color: HomiColors.coral, size: 21),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (onClear != null)
                    IconButton(
                      tooltip: 'Clear',
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded, size: 19),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomiDatePickerSheet extends StatefulWidget {
  const _HomiDatePickerSheet({
    required this.title,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.allowClear,
  });

  final String title;
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool allowClear;

  @override
  State<_HomiDatePickerSheet> createState() => _HomiDatePickerSheetState();
}

class _HomiDatePickerSheetState extends State<_HomiDatePickerSheet> {
  late DateTime _selected;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _selected = _day(widget.initialDate);
    _month = DateTime(_selected.year, _selected.month);
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  bool _allowed(DateTime value) {
    final day = _day(value);
    return !day.isBefore(_day(widget.firstDate)) &&
        !day.isAfter(_day(widget.lastDate));
  }

  void _changeMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(firstMonth) || next.isAfter(lastMonth)) return;
    setState(() => _month = next);
  }

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = firstOfMonth.weekday - 1;
    const dayLabels = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: dayLabels
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: HomiColors.muted,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
              ),
              itemCount: leading + daysInMonth,
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final date = DateTime(_month.year, _month.month, index - leading + 1);
                final selected = _day(date) == _selected;
                final enabled = _allowed(date);
                return GestureDetector(
                  onTap: enabled ? () => setState(() => _selected = _day(date)) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? HomiColors.coral
                          : HomiColors.peach.withValues(alpha: enabled ? 0.10 : 0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? HomiColors.coral : HomiColors.border,
                      ),
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? Colors.white
                            : (enabled ? HomiColors.slate : HomiColors.muted.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (widget.allowClear) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: const Text('Clear date'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Use this date'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomiTimePickerSheet extends StatefulWidget {
  const _HomiTimePickerSheet({
    required this.title,
    required this.initialTime,
  });

  final String title;
  final TimeOfDay initialTime;

  @override
  State<_HomiTimePickerSheet> createState() => _HomiTimePickerSheetState();
}

class _HomiTimePickerSheetState extends State<_HomiTimePickerSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return Expanded(
      child: Container(
        height: 190,
        decoration: BoxDecoration(
          color: HomiColors.peach.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: HomiColors.border),
        ),
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 48,
          physics: const FixedExtentScrollPhysics(),
          perspective: 0.003,
          onSelectedItemChanged: onSelected,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, index) {
              final active = index == selected;
              return Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? HomiColors.coral : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: active ? 20 : 17,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : HomiColors.slate,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Choose a time without typing it in.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _wheel(
                  controller: _hourController,
                  count: 24,
                  selected: _hour,
                  onSelected: (value) => setState(() => _hour = value),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                ),
                _wheel(
                  controller: _minuteController,
                  count: 60,
                  selected: _minute,
                  onSelected: (value) => setState(() => _minute = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  TimeOfDay(hour: _hour, minute: _minute),
                ),
                child: Text(
                  'Use ${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
