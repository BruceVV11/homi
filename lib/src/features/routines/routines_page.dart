import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/household_task.dart';
import '../../domain/routine_create_data.dart';
import '../../domain/routine_item.dart';
import '../../services/shared_task_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';
import '../../widgets/homi_date_time_controls.dart';
import '../../widgets/homi_page.dart';

enum WorkView { tasks, routines }

class RoutinesPage extends StatefulWidget {
  const RoutinesPage({
    required this.items,
    required this.tasks,
    required this.actorName,
    required this.actorUid,
    required this.trustedPeopleService,
    required this.sharedTaskService,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onRemoveTask,
    this.requestedView = WorkView.tasks,
    this.viewRequest = 0,
    super.key,
  });

  final List<RoutineItem> items;
  final List<HouseholdTask> tasks;
  final String actorName;
  final String? actorUid;
  final TrustedPeopleService trustedPeopleService;
  final SharedTaskService sharedTaskService;
  final Future<void> Function(RoutineCreateData data) onAdd;
  final Future<void> Function(String id) onToggle;
  final Future<void> Function(String id) onRemove;
  final Future<void> Function(HouseholdTaskInput input) onAddTask;
  final Future<void> Function(String id) onToggleTask;
  final Future<void> Function(String id) onRemoveTask;
  final WorkView requestedView;
  final int viewRequest;

  @override
  State<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends State<RoutinesPage>
    with AutomaticKeepAliveClientMixin<RoutinesPage> {
  late WorkView _view;
  StreamSubscription<List<TrustedConnection>>? _connectionSub;
  StreamSubscription<Map<String, TrustedPersonPreference>>? _preferenceSub;
  StreamSubscription<List<HouseholdTask>>? _sharedTaskSub;
  List<TrustedConnection> _connections = const <TrustedConnection>[];
  Map<String, TrustedPersonPreference> _preferences =
      const <String, TrustedPersonPreference>{};
  List<HouseholdTask> _sharedTasks = const <HouseholdTask>[];
  String? _cloudMessage;

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
      repeat: RoutineRepeat.biweekly,
      estimatedMinutes: 10,
      repeatDays: <int>[7],
      dueHour: 9,
      dueMinute: 0,
    ),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _view = widget.requestedView;
    _bindCloud();
  }

  @override
  void didUpdateWidget(covariant RoutinesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actorUid != widget.actorUid) _bindCloud();
    if (oldWidget.viewRequest != widget.viewRequest ||
        oldWidget.requestedView != widget.requestedView) {
      _view = widget.requestedView;
    }
  }

  @override
  void dispose() {
    _cancelCloud();
    super.dispose();
  }

  void _cancelCloud() {
    _connectionSub?.cancel();
    _preferenceSub?.cancel();
    _sharedTaskSub?.cancel();
    _connectionSub = null;
    _preferenceSub = null;
    _sharedTaskSub = null;
  }

  void _bindCloud() {
    _cancelCloud();
    if (widget.actorUid == null) {
      _connections = const <TrustedConnection>[];
      _preferences = const <String, TrustedPersonPreference>{};
      _sharedTasks = const <HouseholdTask>[];
      return;
    }

    _connectionSub = widget.trustedPeopleService.watchConnections().listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _connections = value;
          _cloudMessage = null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _cloudMessage =
              'Household people could not refresh. Your saved tasks are still available.');
        }
      },
    );
    _preferenceSub = widget.trustedPeopleService.watchPreferences().listen(
      (value) {
        if (mounted) setState(() => _preferences = value);
      },
      onError: (_) {},
    );
    _sharedTaskSub = widget.sharedTaskService.watchSharedTasks().listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _sharedTasks = value;
          _cloudMessage = null;
        });
      },
      onError: (_) {
        if (mounted) {
          setState(() => _cloudMessage =
              'Shared tasks could not refresh. Homi will try again automatically.');
        }
      },
    );
  }

  List<String> get _householdMemberUids {
    final currentUid = widget.actorUid;
    if (currentUid == null) return const <String>[];
    return _connections
        .where((item) => item.accepted)
        .map((item) => item.otherUid(currentUid))
        .toSet()
        .toList(growable: false);
  }

  List<_AssigneeOption> get _assignees {
    final result = <_AssigneeOption>[
      const _AssigneeOption(
        label: 'Anyone at home',
        name: null,
        uid: null,
        detail: 'Visible to your household',
      ),
      _AssigneeOption(
        label: 'Me',
        name: widget.actorName,
        uid: widget.actorUid,
        detail: 'Private to you',
      ),
    ];

    final currentUid = widget.actorUid;
    if (currentUid == null) return result;
    for (final connection in _connections.where((item) => item.accepted)) {
      final uid = connection.otherUid(currentUid);
      final preference =
          _preferences[uid] ?? TrustedPersonPreference.fallback;
      result.add(
        _AssigneeOption(
          label: connection.otherName(currentUid),
          name: connection.otherName(currentUid),
          uid: uid,
          detail: preference.relationship == 'Trusted person'
              ? 'Household member'
              : preference.relationship,
        ),
      );
    }
    return result;
  }

  Future<void> _addTask() async {
    final draft = await showModalBottomSheet<HouseholdTaskInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TaskEditorSheet(
        assignees: _assignees,
        actorUid: widget.actorUid,
      ),
    );
    if (draft == null) return;

    final personal = widget.actorUid == null ||
        draft.assigneeUid == widget.actorUid;
    final householdUids = _householdMemberUids;

    if (!personal && householdUids.isNotEmpty) {
      try {
        await widget.sharedTaskService.createHouseholdTask(
          title: draft.title,
          householdMemberUids: householdUids,
          assigneeUid: draft.assigneeUid,
          assigneeName: draft.assigneeName,
          notes: draft.notes,
          dueAt: draft.dueAt,
        );
      } catch (error) {
        if (mounted) {
          setState(() => _cloudMessage = _taskError(error));
        }
      }
      return;
    }

    await widget.onAddTask(draft);
  }

  String _taskError(Object error) {
    final message = error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
    if (message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED')) {
      return 'Homi could not share that household task yet. Refresh your household connection and try again.';
    }
    return message;
  }

  Future<void> _addRoutine({_RoutineTemplate? template}) async {
    final draft = await showModalBottomSheet<RoutineCreateData>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RoutineEditorSheet(template: template),
    );
    if (draft != null) await widget.onAdd(draft);
  }

  Future<void> _removeTask(HouseholdTask task) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove task?',
      message: '“${task.title}” will be removed${task.shared ? ' for everyone who can see it' : ' from this phone'}.',
      confirmLabel: 'Remove task',
      cancelLabel: 'Keep task',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed) return;
    if (task.shared) {
      try {
        await widget.sharedTaskService.removeTask(task.id);
      } catch (_) {
        if (mounted) {
          setState(() => _cloudMessage = 'Homi could not remove that shared task.');
        }
      }
    } else {
      await widget.onRemoveTask(task.id);
    }
  }

  Future<void> _removeRoutine(RoutineItem item) async {
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
    if (confirmed) await widget.onRemove(item.id);
  }

  Future<void> _toggleTask(HouseholdTask task) async {
    if (task.shared) {
      try {
        await widget.sharedTaskService.toggleTask(task);
      } catch (_) {
        if (mounted) {
          setState(() => _cloudMessage = 'Homi could not update that shared task.');
        }
      }
    } else {
      await widget.onToggleTask(task.id);
    }
  }

  void _showTasksInfo() {
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
              Text('How Tasks work',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              const _InfoPoint(
                icon: Icons.task_alt_rounded,
                title: 'Tasks happen once',
                text:
                    'Use a Task for something such as taking food out to defrost, collecting a parcel or calling the plumber. A Routine is better when the job repeats.',
              ),
              const _InfoPoint(
                icon: Icons.schedule_outlined,
                title: 'A due time is optional',
                text:
                    'Choose a date and time when timing matters, or use No due time when the job simply needs to get done.',
              ),
              const _InfoPoint(
                icon: Icons.groups_outlined,
                title: 'Household tasks stay visible',
                text:
                    'Tasks for Anyone at home or another household person are visible to everyone in the household, including who they are assigned to and who completed them.',
              ),
              const _InfoPoint(
                icon: Icons.lock_outline_rounded,
                title: 'Tasks for Me stay private',
                text:
                    'Choose Me when the reminder is only for you. Location-only friends never receive household Tasks.',
              ),
              const _InfoPoint(
                icon: Icons.history_rounded,
                title: 'Recently completed stays useful',
                text:
                    'Completed Tasks remain visible for 2 days so everyone can see what was done, then Homi removes them from the active household list.',
              ),
              const SizedBox(height: 6),
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
    super.build(context);
    return HomiPage(
      title: 'Tasks & routines',
      subtitle: 'One-off jobs for today, routines for the things that come back.',
      children: [
        HomiChoiceGroup<WorkView>(
          values: WorkView.values,
          selected: _view,
          labelFor: (value) => value == WorkView.tasks ? 'Tasks' : 'Routines',
          onSelected: (value) => setState(() => _view = value),
        ),
        if (_cloudMessage != null) ...[
          const SizedBox(height: 10),
          _QuietNotice(text: _cloudMessage!),
        ],
        const SizedBox(height: 18),
        if (_view == WorkView.tasks)
          _buildTasks(context)
        else
          _buildRoutines(context),
      ],
    );
  }

  Widget _buildTasks(BuildContext context) {
    final now = DateTime.now();
    final all = <HouseholdTask>[...widget.tasks, ..._sharedTasks]
        .where((task) => !task.shouldPurge(now))
        .toList();
    all.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue == null && bDue != null) return 1;
      if (aDue != null && bDue == null) return -1;
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      return b.createdAt.compareTo(a.createdAt);
    });
    final open = all.where((item) => !item.completed).toList(growable: false);
    final completed = all
        .where((item) => item.completedWithinRetention(now))
        .toList(growable: false)
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
            ),
            TextButton.icon(
              onPressed: _showTasksInfo,
              icon: const Icon(Icons.info_outline_rounded, size: 17),
              label: const Text('How it works'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                open.isEmpty
                    ? 'Nothing is waiting right now.'
                    : '${open.length} ${open.length == 1 ? 'task is' : 'tasks are'} still open.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: _addTask,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (open.isEmpty)
          _EmptyCard(
            icon: Icons.task_alt_rounded,
            title: 'No open tasks',
            message:
                'Add a one-off job such as “Take the mince out to defrost”. Give it a time if it matters, or choose No due time.',
            action: 'Add a task',
            onTap: _addTask,
          )
        else
          ...open.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskCard(
                task: task,
                currentUid: widget.actorUid,
                onToggle: () => _toggleTask(task),
                onRemove: () => _removeTask(task),
              ),
            ),
          ),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text('Recently completed',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Completed Tasks stay here for 2 days, then Homi clears them automatically.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ...completed.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskCard(
                task: task,
                currentUid: widget.actorUid,
                onToggle: () => _toggleTask(task),
                onRemove: () => _removeTask(task),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoutines(BuildContext context) {
    final now = DateTime.now();
    final due = widget.items.where((item) => item.isDue(now)).toList(growable: false)
      ..sort((a, b) => (a.nextDueAt ?? a.initialDueAt())
          .compareTo(b.nextDueAt ?? b.initialDueAt()));
    final upToDate = widget.items
        .where((item) => !item.isDue(now))
        .toList(growable: false)
      ..sort((a, b) => (a.nextDueAt ?? a.initialDueAt())
          .compareTo(b.nextDueAt ?? b.initialDueAt()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                due.isEmpty
                    ? 'Everything scheduled is up to date.'
                    : '${due.length} ${due.length == 1 ? 'routine needs' : 'routines need'} attention.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _addRoutine(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add routine'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.items.isEmpty)
          _EmptyCard(
            icon: Icons.repeat_rounded,
            title: 'No routines yet',
            message:
                'Routines are for jobs that repeat. Homi remembers when they come around, who completed them and when they are due again.',
            action: 'Add a routine',
            onTap: () => _addRoutine(),
          )
        else ...[
          if (due.isNotEmpty) ...[
            Text('Due now', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...due.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoutineCard(
                  item: item,
                  now: now,
                  onToggle: () => widget.onToggle(item.id),
                  onRemove: () => _removeRoutine(item),
                ),
              ),
            ),
          ],
          if (upToDate.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Up to date', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'These routines are complete for their current occurrence. You can undo a tick if it was marked by mistake.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            ...upToDate.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoutineCard(
                  item: item,
                  now: now,
                  onToggle: () => widget.onToggle(item.id),
                  onRemove: () => _removeRoutine(item),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 20),
        Text('Common routines', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Tap one to start with a realistic schedule, then adjust it for your home.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        ..._examples.map(
          (template) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _RoutineExampleTile(
              template: template,
              onTap: () => _addRoutine(template: template),
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.currentUid,
    required this.onToggle,
    required this.onRemove,
  });

  final HouseholdTask task;
  final String? currentUid;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final due = task.dueAt;
    final assignedToMe =
        task.assigneeUid != null && task.assigneeUid == currentUid;
    final createdByOther = task.shared &&
        task.createdByUid != null &&
        task.createdByUid != currentUid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.completed,
              activeColor: HomiColors.coral,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        decoration:
                            task.completed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (task.notes?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(task.notes!,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (task.assigneeName != null)
                          _Meta(
                            icon: Icons.person_outline_rounded,
                            text: assignedToMe
                                ? 'Assigned to you'
                                : 'For ${task.assigneeName}',
                          )
                        else
                          const _Meta(
                            icon: Icons.groups_outlined,
                            text: 'Anyone at home',
                          ),
                        _Meta(
                          icon: Icons.schedule_outlined,
                          text: due == null
                              ? 'No due time'
                              : DateFormat('EEE d MMM · HH:mm').format(due),
                        ),
                        if (task.shared)
                          const _Meta(
                            icon: Icons.sync_rounded,
                            text: 'Household task',
                          ),
                      ],
                    ),
                    if (createdByOther) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Added by ${task.createdByName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (task.completedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Done ${DateFormat('EEE d MMM · HH:mm').format(task.completedAt!)} by ${task.completedByName ?? 'someone'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6F8B65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Task options',
              onPressed: onRemove,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.item,
    required this.now,
    required this.onToggle,
    required this.onRemove,
  });

  final RoutineItem item;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final due = item.isDue(now);
    final last = item.lastCompletion;
    final checked = !due && last != null;
    final next = item.nextDueAt ?? item.initialDueAt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: checked,
              activeColor: HomiColors.coral,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
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
                      '${item.category} · ${_scheduleLabel(item)} · about ${item.durationLabel}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (last != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Done ${DateFormat('EEE d MMM · HH:mm').format(last.at)} by ${last.byName}',
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
                            : 'Next ${DateFormat('EEE d MMM · HH:mm').format(next)}',
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
            ),
            IconButton(
              tooltip: 'Routine options',
              onPressed: onRemove,
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: HomiColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: HomiColors.muted,
          ),
        ),
      ],
    );
  }
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({
    required this.assignees,
    required this.actorUid,
  });

  final List<_AssigneeOption> assignees;
  final String? actorUid;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  late _AssigneeOption _assignee;
  bool _scheduled = false;
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  String? _error;

  @override
  void initState() {
    super.initState();
    _assignee = widget.assignees.first;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showHomiDatePicker(
      context,
      title: 'When is this task due?',
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showHomiTimePicker(
      context,
      title: 'What time is it due?',
      initialTime: _time,
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a short name.');
      return;
    }
    final dueAt = _scheduled
        ? DateTime(
            _date.year,
            _date.month,
            _date.day,
            _time.hour,
            _time.minute,
          )
        : null;
    Navigator.pop(
      context,
      HouseholdTaskInput(
        title: title,
        notes: _notesController.text,
        assigneeName: _assignee.name,
        assigneeUid: _assignee.uid,
        dueAt: dueAt,
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
            Text('Add a task', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Tasks happen once. Assign one to your household, keep it for yourself, or leave the due time open.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Task',
                hintText: 'e.g. Take the mince out to defrost',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything useful to know',
              ),
            ),
            const SizedBox(height: 18),
            Text('Assign to', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.assignees.map((option) {
                final active = option == _assignee;
                return GestureDetector(
                  onTap: () => setState(() => _assignee = option),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 90),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: active
                          ? HomiColors.coral
                          : HomiColors.peach.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: active ? HomiColors.coral : HomiColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: active ? Colors.white : HomiColors.slate,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          option.detail,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: active
                                ? Colors.white.withValues(alpha: 0.82)
                                : HomiColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 18),
            Text('Due time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<bool>(
              values: const <bool>[false, true],
              selected: _scheduled,
              labelFor: (value) => value ? 'Set date & time' : 'No due time',
              onSelected: (value) => setState(() => _scheduled = value),
            ),
            if (_scheduled) ...[
              const SizedBox(height: 12),
              HomiDateField(
                label: 'Date',
                value: _date,
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              HomiTimeField(
                label: 'Time',
                value: _time,
                onTap: _pickTime,
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(
                  _assignee.uid != null && _assignee.uid != widget.actorUid
                      ? 'Assign task'
                      : 'Add task',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  late RoutineRepeat _repeat;
  late int _estimatedMinutes;
  late Set<int> _repeatDays;
  late int _biweeklyDay;
  late int _dayOfMonth;
  late TimeOfDay _time;
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
    RoutineRepeat.daily,
    RoutineRepeat.weekdays,
    RoutineRepeat.weekly,
    RoutineRepeat.biweekly,
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
    _biweeklyDay = (template?.repeatDays.isNotEmpty == true)
        ? template!.repeatDays.first
        : DateTime.now().weekday;
    _dayOfMonth = DateTime.now().day;
    _time = TimeOfDay(
      hour: template?.dueHour ?? 9,
      minute: template?.dueMinute ?? 0,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final selected = await showHomiTimePicker(
      context,
      title: 'When should this routine be due?',
      initialTime: _time,
    );
    if (selected != null && mounted) setState(() => _time = selected);
  }

  Future<void> _pickMonthDay() async {
    final selected = await showHomiDayOfMonthPicker(
      context,
      title: 'Which day each month?',
      initialDay: _dayOfMonth,
    );
    if (selected != null && mounted) setState(() => _dayOfMonth = selected);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the routine a short name.');
      return;
    }
    if (_repeat == RoutineRepeat.weekly && _repeatDays.isEmpty) {
      setState(() => _error = 'Choose at least one day for a weekly routine.');
      return;
    }

    final repeatDays = switch (_repeat) {
      RoutineRepeat.weekly => (List<int>.of(_repeatDays)..sort()),
      RoutineRepeat.biweekly => <int>[_biweeklyDay],
      _ => const <int>[],
    };
    Navigator.pop(
      context,
      RoutineCreateData(
        title: title,
        category: _category,
        repeat: _repeat,
        estimatedMinutes: _estimatedMinutes,
        dueHour: _time.hour,
        dueMinute: _time.minute,
        repeatDays: repeatDays,
        dayOfMonth: _repeat == RoutineRepeat.monthly ? _dayOfMonth : null,
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
            Text('Add a routine', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Routines repeat. Homi brings each occurrence back when it is due and keeps the latest completion visible.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              autofocus: widget.template == null,
              decoration: InputDecoration(
                labelText: 'Routine',
                hintText: 'e.g. Feed the pets',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 18),
            Text('Category', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<String>(
              values: _categories,
              selected: _category,
              labelFor: (value) => value,
              onSelected: (value) => setState(() => _category = value),
              compact: true,
            ),
            const SizedBox(height: 18),
            Text('Repeats', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<RoutineRepeat>(
              values: _repeatOptions,
              selected: _repeat,
              labelFor: (value) => value.label,
              onSelected: (value) {
                setState(() {
                  _repeat = value;
                  if (_repeat == RoutineRepeat.weekly && _repeatDays.isEmpty) {
                    _repeatDays = <int>{DateTime.now().weekday};
                  }
                });
              },
              compact: true,
            ),
            if (_repeat == RoutineRepeat.weekly) ...[
              const SizedBox(height: 14),
              Text('Days', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              HomiMultiChoiceGroup<int>(
                values: _weekdays,
                selected: _repeatDays,
                labelFor: _shortDay,
                onChanged: (value) => setState(() => _repeatDays = value),
              ),
            ],
            if (_repeat == RoutineRepeat.biweekly) ...[
              const SizedBox(height: 14),
              Text('Every second', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              HomiChoiceGroup<int>(
                values: _weekdays,
                selected: _biweeklyDay,
                labelFor: _shortDay,
                onSelected: (value) => setState(() => _biweeklyDay = value),
                compact: true,
              ),
            ],
            if (_repeat == RoutineRepeat.monthly) ...[
              const SizedBox(height: 14),
              _PickerRow(
                label: 'Day of month',
                value: 'Day $_dayOfMonth',
                icon: Icons.calendar_view_month_outlined,
                onTap: _pickMonthDay,
              ),
            ],
            const SizedBox(height: 14),
            HomiTimeField(
              label: 'Time',
              value: _time,
              onTap: _pickTime,
            ),
            const SizedBox(height: 18),
            Text('Usually takes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            HomiChoiceGroup<int>(
              values: _durations,
              selected: _estimatedMinutes,
              labelFor: (value) => value >= 60 ? '60+ min' : '$value min',
              onSelected: (value) => setState(() => _estimatedMinutes = value),
              compact: true,
            ),
            const SizedBox(height: 18),
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

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HomiColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, color: HomiColors.coral),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ],
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
                    Text(template.title,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(
                      '${_templateSchedule(template)} · about ${template.estimatedMinutes >= 60 ? '60+ min' : '${template.estimatedMinutes} min'}',
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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: HomiColors.coral),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

class _QuietNotice extends StatelessWidget {
  const _QuietNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
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

class _AssigneeOption {
  const _AssigneeOption({
    required this.label,
    required this.name,
    required this.uid,
    required this.detail,
  });

  final String label;
  final String? name;
  final String? uid;
  final String detail;
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
  });

  final IconData icon;
  final String title;
  final String category;
  final RoutineRepeat repeat;
  final int estimatedMinutes;
  final int dueHour;
  final int dueMinute;
  final List<int> repeatDays;
}

String _scheduleLabel(RoutineItem item) {
  if (!item.repeats) return 'One-off';
  final time =
      '${item.dueHour.toString().padLeft(2, '0')}:${item.dueMinute.toString().padLeft(2, '0')}';
  switch (item.repeat) {
    case RoutineRepeat.once:
      return 'One-off';
    case RoutineRepeat.daily:
      return 'Daily at $time';
    case RoutineRepeat.weekdays:
      return 'Weekdays at $time';
    case RoutineRepeat.weekly:
      final days = item.repeatDays.isEmpty
          ? <int>[item.createdAt.weekday]
          : item.repeatDays;
      return '${days.map(_shortDay).join(', ')} at $time';
    case RoutineRepeat.biweekly:
      final day = item.repeatDays.isEmpty
          ? item.createdAt.weekday
          : item.repeatDays.first;
      return 'Every 2 weeks · ${_shortDay(day)} at $time';
    case RoutineRepeat.monthly:
      return 'Day ${item.dayOfMonth ?? item.createdAt.day} each month at $time';
  }
}

String _templateSchedule(_RoutineTemplate template) {
  final time =
      '${template.dueHour.toString().padLeft(2, '0')}:${template.dueMinute.toString().padLeft(2, '0')}';
  if (template.repeat == RoutineRepeat.daily) return 'Daily at $time';
  if (template.repeat == RoutineRepeat.weekly) {
    return '${template.repeatDays.map(_shortDay).join(', ')} at $time';
  }
  if (template.repeat == RoutineRepeat.biweekly) {
    final day = template.repeatDays.isEmpty
        ? DateTime.monday
        : template.repeatDays.first;
    return 'Every 2 weeks · ${_shortDay(day)} at $time';
  }
  return template.repeat.label;
}

String _shortDay(int weekday) {
  const days = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[(weekday - 1).clamp(0, 6)];
}
