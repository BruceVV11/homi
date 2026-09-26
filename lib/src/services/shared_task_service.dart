import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/homi_household.dart';
import '../domain/household_task.dart';
import 'homi_cloud_actions.dart';
import 'household_service.dart';

class SharedTaskService {
  SharedTaskService({required this.firebaseReady})
      : _cloudActions = HomiCloudActions(firebaseReady: firebaseReady),
        _householdService = HouseholdService(firebaseReady: firebaseReady);

  final bool firebaseReady;
  final HomiCloudActions _cloudActions;
  final HouseholdService _householdService;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  Stream<List<HouseholdTask>> watchSharedTasks() {
    final user = currentUser;
    if (user == null) return Stream.value(const <HouseholdTask>[]);

    late final StreamController<List<HouseholdTask>> controller;
    StreamSubscription<HomiHousehold?>? householdSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? taskSub;
    var generation = 0;

    Future<void> bindHousehold(HomiHousehold? household) async {
      final currentGeneration = ++generation;
      await taskSub?.cancel();
      taskSub = null;
      if (currentGeneration != generation) return;

      if (household == null) {
        controller.add(const <HouseholdTask>[]);
        return;
      }

      // Both query constraints are deliberate security inputs. Firestore rules
      // are not filters: householdId proves the canonical Household scope while
      // memberUids preserves the exact audience of migrated pre-0.12 Tasks.
      // New 0.12 Tasks use the full canonical Household audience and are kept
      // aligned by onHouseholdTaskMembershipChanged.
      taskSub = _firestore
          .collection('sharedTasks')
          .where('householdId', isEqualTo: household.id)
          .where('memberUids', arrayContains: user.uid)
          .snapshots()
          .listen(
        (snapshot) => controller.add(_tasksFromSnapshot(snapshot)),
        onError: controller.addError,
      );
    }

    controller = StreamController<List<HouseholdTask>>(
      onListen: () {
        householdSub = _householdService.watchCurrentHousehold().listen(
          (household) => unawaited(bindHousehold(household)),
          onError: controller.addError,
        );
      },
      onCancel: () async {
        generation += 1;
        await householdSub?.cancel();
        await taskSub?.cancel();
      },
    );
    return controller.stream;
  }

  List<HouseholdTask> _tasksFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final now = DateTime.now();
    final allTasks = snapshot.docs
        .map(_taskFromDocument)
        .whereType<HouseholdTask>()
        .toList(growable: false);
    final expiredIds = allTasks
        .where((task) => task.shouldPurge(now))
        .map((task) => task.id)
        .toList(growable: false);
    if (expiredIds.isNotEmpty) {
      unawaited(_deleteExpired(expiredIds));
    }

    final tasks = allTasks
        .where((task) => !task.shouldPurge(now))
        .toList(growable: false);
    tasks.sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      final aDue = a.dueAt;
      final bDue = b.dueAt;
      if (aDue == null && bDue != null) return 1;
      if (aDue != null && bDue == null) return -1;
      if (aDue != null && bDue != null) return aDue.compareTo(bDue);
      return b.createdAt.compareTo(a.createdAt);
    });
    return tasks;
  }

  Future<void> createHouseholdTask({
    required String title,
    required Iterable<String> householdMemberUids,
    String? assigneeUid,
    String? assigneeName,
    String? notes,
    DateTime? dueAt,
  }) async {
    final user = _requireUser();
    if (assigneeUid == user.uid) {
      throw StateError(
        'Tasks assigned to you stay private. Save this one as a personal task instead.',
      );
    }

    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Give the task a short name.');
    }
    if (trimmedTitle.length > 120) {
      throw StateError('Keep the task name under 120 characters.');
    }
    final cleanNotes = _clean(notes);
    if (cleanNotes != null && cleanNotes.length > 1000) {
      throw StateError('Keep task notes under 1000 characters.');
    }

    // The server derives the actual member list from canonical Household
    // membership. The caller-provided iterable remains only for compatibility
    // with the existing UI signature and is never trusted for authorization.
    await _cloudActions.call('createSharedTask', <String, dynamic>{
      'title': trimmedTitle,
      'notes': cleanNotes,
      'assigneeUid': assigneeUid,
      'dueAtMs': dueAt?.toUtc().millisecondsSinceEpoch,
    });
  }

  Future<void> createAssignedTask({
    required String title,
    required String assigneeUid,
    required String assigneeName,
    String? notes,
    DateTime? dueAt,
  }) {
    return createHouseholdTask(
      title: title,
      householdMemberUids: <String>[assigneeUid],
      assigneeUid: assigneeUid,
      assigneeName: assigneeName,
      notes: notes,
      dueAt: dueAt,
    );
  }

  Future<void> toggleTask(HouseholdTask task) async {
    _requireUser();
    await _cloudActions.call('toggleSharedTask', <String, dynamic>{
      'taskId': task.id,
    });
  }

  Future<void> removeTask(String id) async {
    _requireUser();
    await _cloudActions.call('removeSharedTask', <String, dynamic>{
      'taskId': id,
    });
  }

  Future<void> _deleteExpired(List<String> ids) async {
    if (ids.isEmpty || currentUser == null) return;
    for (final id in ids) {
      try {
        await _cloudActions.call('removeSharedTask', <String, dynamic>{
          'taskId': id,
        });
      } catch (_) {
        // Expired tasks are already hidden locally. A later successful sync
        // retries server cleanup without exposing the stale task in the UI.
      }
    }
  }

  HouseholdTask? _taskFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    if (data == null) return null;
    final createdTimestamp = data['createdAt'];
    final dueTimestamp = data['dueAt'];
    final completedTimestamp = data['completedAt'];
    return HouseholdTask(
      id: document.id,
      title: data['title'] as String? ?? 'Task',
      notes: data['notes'] as String?,
      assigneeName: data['assigneeName'] as String?,
      assigneeUid: data['assigneeUid'] as String?,
      dueAt: dueTimestamp is Timestamp ? dueTimestamp.toDate() : null,
      createdAt: createdTimestamp is Timestamp
          ? createdTimestamp.toDate()
          : DateTime.now(),
      createdByName: data['createdByName'] as String? ?? 'Homi user',
      createdByUid: data['createdByUid'] as String?,
      completedAt:
          completedTimestamp is Timestamp ? completedTimestamp.toDate() : null,
      completedByName: data['completedByName'] as String?,
      completedByUid: data['completedByUid'] as String?,
      shared: true,
    );
  }

  User _requireUser() {
    if (!firebaseReady) throw StateError('Sign in to share a task.');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to share a task.');
    return user;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
