import 'package:flutter/material.dart';

import '../../domain/home_thing.dart';
import '../../domain/household_task.dart';
import '../../domain/quick_reset_plan.dart';
import '../../domain/routine_item.dart';
import '../../domain/supply_item.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';

enum QuickAddDestination { task, routine, supply, home }

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.homeName,
    required this.quickItems,
    required this.tasks,
    required this.routines,
    required this.supplies,
    required this.homeThings,
    required this.onRemoveQuickItem,
    required this.onToggleRoutine,
    required this.onOpenRoutines,
    required this.onOpenHome,
    required this.onOpenSupplies,
    required this.onQuickAddTask,
    required this.onQuickAddRoutine,
    required this.onQuickAddSupply,
    required this.onQuickAddHome,
    super.key,
  });

  final String homeName;
  final List<String> quickItems;
  final List<HouseholdTask> tasks;
  final List<RoutineItem> routines;
  final List<SupplyItem> supplies;
  final List<HomeThing> homeThings;
  final Future<void> Function(String value) onRemoveQuickItem;
  final Future<void> Function(String id) onToggleRoutine;
  final VoidCallback onOpenRoutines;
  final VoidCallback onOpenHome;
  final VoidCallback onOpenSupplies;
  final VoidCallback onQuickAddTask;
  final VoidCallback onQuickAddRoutine;
  final VoidCallback onQuickAddSupply;
  final VoidCallback onQuickAddHome;

  Future<void> _quickAdd(BuildContext context) async {
    final destination = await showModalBottomSheet<QuickAddDestination>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _QuickAddSheet(),
    );
    if (destination == null) return;
    switch (destination) {
      case QuickAddDestination.task:
        onQuickAddTask();
      case QuickAddDestination.routine:
        onQuickAddRoutine();
      case QuickAddDestination.supply:
        onQuickAddSupply();
      case QuickAddDestination.home:
        onQuickAddHome();
    }
  }

  void _showQuickResetInfo(BuildContext context) {
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HomiColors.peach.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.timelapse_rounded,
                      color: HomiColors.coral,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'When you have time',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how much time you have and Homi builds a small Quick Reset that fits inside it. Routines that are actually due come first, using the time estimate you gave them.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'If there is spare time, Homi mixes in common household jobs. Those suggestions rotate each time, so the list stays useful instead of becoming the same checklist every day.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing starts automatically. When you complete a saved routine here, Homi records who did it, when it was done and when it is due again.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
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

  Future<void> _showTimePlan(BuildContext context, int minutes) async {
    final resetTasks = QuickResetPlanner.build(
      budgetMinutes: minutes,
      routines: routines,
      now: DateTime.now(),
    );
    final completedKeys = <String>{};
    final plannedMinutes = QuickResetPlanner.plannedMinutes(resetTasks);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$minutes-minute Quick Reset',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  resetTasks.isEmpty
                      ? 'You are caught up. Try again later for another mix of small household suggestions.'
                      : '$plannedMinutes minutes planned from useful jobs that fit the time you have.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (resetTasks.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HomiColors.peach.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Nothing small fits this reset right now.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  )
                else
                  ...resetTasks.map((task) {
                    final key = task.routineId ?? 'suggestion:${task.title}';
                    final completed = completedKeys.contains(key);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _QuickResetTaskRow(
                        task: task,
                        completed: completed,
                        onDone: () async {
                          if (completed) return;
                          if (task.routineId != null) {
                            await onToggleRoutine(task.routineId!);
                          }
                          if (!sheetContext.mounted) return;
                          setSheetState(() => completedKeys.add(key));
                        },
                      ),
                    );
                  }),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done for now'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final openTasks = tasks.where((item) => !item.completed).length;
    final dueRoutines = routines.where((item) => item.isDue(now)).length;
    final supplyAlerts = supplies
        .where((item) => item.effectiveStatus(now) != SupplyStatus.okay)
        .length;
    final homeAttention = homeThings
        .where((item) => item.serviceDue(now) || item.serviceSoon(now))
        .length;
    final hasAttention = openTasks > 0 ||
        dueRoutines > 0 ||
        supplyAlerts > 0 ||
        homeAttention > 0 ||
        quickItems.isNotEmpty;

    return HomiPage(
      title: '$greeting!',
      subtitle: '$homeName is ready when you are.',
      children: [
        const _SectionLabel(label: 'What needs attention'),
        const SizedBox(height: 10),
        if (!hasAttention)
          const _AttentionCard(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nothing needs attention right now',
            detail:
                'Open tasks, due routines, supplies, maintenance and saved reminders will appear here.',
          )
        else ...[
          if (openTasks > 0) ...[
            _AttentionCard(
              icon: Icons.task_alt_outlined,
              title:
                  '$openTasks ${openTasks == 1 ? 'task is' : 'tasks are'} still open',
              detail: 'One-off jobs waiting to be completed',
              onTap: onQuickAddTask,
            ),
            const SizedBox(height: 10),
          ],
          if (dueRoutines > 0) ...[
            _AttentionCard(
              icon: Icons.repeat_rounded,
              title:
                  '$dueRoutines ${dueRoutines == 1 ? 'routine is' : 'routines are'} due',
              detail: 'See what is due and who last completed it',
              onTap: onOpenRoutines,
            ),
            const SizedBox(height: 10),
          ],
          if (supplyAlerts > 0) ...[
            _AttentionCard(
              icon: Icons.inventory_2_outlined,
              title:
                  '$supplyAlerts ${supplyAlerts == 1 ? 'supply needs' : 'supplies need'} attention',
              detail: 'Expiry, low-stock or shopping items',
              onTap: onOpenSupplies,
            ),
            const SizedBox(height: 10),
          ],
          if (homeAttention > 0) ...[
            _AttentionCard(
              icon: Icons.home_repair_service_outlined,
              title:
                  '$homeAttention ${homeAttention == 1 ? 'home item needs' : 'home items need'} attention',
              detail: 'Service or maintenance is due soon',
              onTap: onOpenHome,
            ),
            const SizedBox(height: 10),
          ],
          ...quickItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.push_pin_outlined,
                          color: HomiColors.coral),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        tooltip: 'Mark done',
                        onPressed: () => onRemoveQuickItem(item),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        _SectionHeader(
          label: 'When you have time',
          actionLabel: 'How it works',
          onAction: () => _showQuickResetInfo(context),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _TimeCard(
                minutes: 10,
                detail: 'A quick reset',
                onTap: () => _showTimePlan(context, 10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TimeCard(
                minutes: 30,
                detail: 'Get a little more done',
                onTap: () => _showTimePlan(context, 30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _quickAdd(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Quick add'),
          ),
        ),
      ],
    );
  }
}

class _QuickAddSheet extends StatelessWidget {
  const _QuickAddSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick add', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Choose what you want to add and Homi will take you to the right place.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _QuickAddOption(
              icon: Icons.task_alt_outlined,
              title: 'Task',
              detail: 'A one-off job or reminder',
              onTap: () => Navigator.pop(context, QuickAddDestination.task),
            ),
            _QuickAddOption(
              icon: Icons.repeat_rounded,
              title: 'Routine',
              detail: 'Something that repeats',
              onTap: () => Navigator.pop(context, QuickAddDestination.routine),
            ),
            _QuickAddOption(
              icon: Icons.inventory_2_outlined,
              title: 'Supply',
              detail: 'Track stock or an expiry date',
              onTap: () => Navigator.pop(context, QuickAddDestination.supply),
            ),
            _QuickAddOption(
              icon: Icons.home_repair_service_outlined,
              title: 'Home',
              detail: 'Add an item, reading or home record',
              onTap: () => Navigator.pop(context, QuickAddDestination.home),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddOption extends StatelessWidget {
  const _QuickAddOption({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
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
                  child: Icon(icon, color: HomiColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label, style: Theme.of(context).textTheme.titleLarge);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleLarge)),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.info_outline_rounded, size: 17),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: HomiColors.peach.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: HomiColors.coral),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (onTap != null) const Icon(Icons.arrow_forward_rounded, size: 20),
        ],
      ),
    );
    return Card(
      child: onTap == null
          ? content
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: content,
            ),
    );
  }
}

class _QuickResetTaskRow extends StatelessWidget {
  const _QuickResetTaskRow({
    required this.task,
    required this.completed,
    required this.onDone,
  });
  final QuickResetTask task;
  final bool completed;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: completed
                    ? HomiColors.sage.withValues(alpha: 0.28)
                    : HomiColors.peach.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : (task.isSavedRoutine
                        ? Icons.repeat_rounded
                        : Icons.auto_awesome_outlined),
                size: 20,
                color: completed
                    ? const Color(0xFF6F8B65)
                    : HomiColors.coral,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      decoration:
                          completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.minutes} min · ${task.isSavedRoutine ? 'From your routines' : 'Quick suggestion'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: completed ? 'Done' : 'Mark done',
              onPressed: completed ? null : () => onDone(),
              icon: Icon(
                completed
                    ? Icons.check_circle_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.minutes,
    required this.detail,
    required this.onTap,
  });
  final int minutes;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$minutes minutes',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
