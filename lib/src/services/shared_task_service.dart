import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/household_task.dart';

class SharedTaskService {
  SharedTaskService({required this.firebaseReady});

  final bool firebaseReady;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get currentUser =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  String _displayName(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Homi user';
  }

  Stream<List<HouseholdTask>> watchSharedTasks() {
    final user = currentUser;
    if (user == null) return Stream.value(const <HouseholdTask>[]);

    return _firestore
        .collection('sharedTasks')
        .where('memberUids', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
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
    });
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

    if (assigneeUid != null) {
      final preference = await _firestore
          .collection('peoplePreferences')
          .doc(user.uid)
          .collection('people')
          .doc(assigneeUid)
          .get();
      if (preference.data()?['scope'] != 'household') {
        throw StateError(
          'Mark this person as Household in People before assigning household tasks to them.',
        );
      }
    }

    final members = <String>{user.uid};
    members.addAll(
      householdMemberUids.where((uid) => uid.trim().isNotEmpty),
    );
    if (assigneeUid != null && assigneeUid.isNotEmpty) {
      members.add(assigneeUid);
    }
    if (members.length < 2) {
      throw StateError(
        'Add at least one Household person in People before sharing a household task.',
      );
    }

    final memberUids = members.toList()..sort();
    final ref = _firestore.collection('sharedTasks').doc();
    await ref.set({
      'title': trimmedTitle,
      'notes': _clean(notes),
      'assigneeUid': assigneeUid,
      'assigneeName': _clean(assigneeName),
      'createdByUid': user.uid,
      'createdByName': _displayName(user),
      'memberUids': memberUids,
      'createdAt': FieldValue.serverTimestamp(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'completedAt': null,
      'completedByName': null,
      'completedByUid': null,
      'purgeAt': null,
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
    final user = _requireUser();
    final ref = _firestore.collection('sharedTasks').doc(task.id);
    if (task.completed) {
      await ref.update({
        'completedAt': null,
        'completedByName': null,
        'completedByUid': null,
        'purgeAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final completedAt = DateTime.now();
    await ref.update({
      'completedAt': Timestamp.fromDate(completedAt),
      'completedByName': _displayName(user),
      'completedByUid': user.uid,
      'purgeAt': Timestamp.fromDate(
        completedAt.add(HouseholdTask.completedRetention),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeTask(String id) async {
    _requireUser();
    await _firestore.collection('sharedTasks').doc(id).delete();
  }

  Future<void> _deleteExpired(List<String> ids) async {
    if (ids.isEmpty || currentUser == null) return;
    try {
      final batch = _firestore.batch();
      for (final id in ids) {
        batch.delete(_firestore.collection('sharedTasks').doc(id));
      }
      await batch.commit();
    } on FirebaseException {
      // Expired tasks are already hidden locally. Another authorised member or
      // the next successful sync can retry the permanent cleanup.
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
