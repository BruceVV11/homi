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
      final tasks = snapshot.docs
          .map(_taskFromDocument)
          .whereType<HouseholdTask>()
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

  Future<void> createAssignedTask({
    required String title,
    required String assigneeUid,
    required String assigneeName,
    String? notes,
    DateTime? dueAt,
  }) async {
    final user = _requireUser();
    if (assigneeUid == user.uid) {
      throw StateError('Choose another person for a shared task.');
    }
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw StateError('Give the task a short name.');
    }

    final ref = _firestore.collection('sharedTasks').doc();
    await ref.set({
      'title': trimmedTitle,
      'notes': _clean(notes),
      'assigneeUid': assigneeUid,
      'assigneeName': assigneeName.trim().isEmpty ? 'Homi user' : assigneeName.trim(),
      'createdByUid': user.uid,
      'createdByName': _displayName(user),
      'memberUids': <String>[user.uid, assigneeUid],
      'createdAt': FieldValue.serverTimestamp(),
      'dueAt': dueAt == null ? null : Timestamp.fromDate(dueAt),
      'completedAt': null,
      'completedByName': null,
      'completedByUid': null,
    });
  }

  Future<void> toggleTask(HouseholdTask task) async {
    final user = _requireUser();
    final ref = _firestore.collection('sharedTasks').doc(task.id);
    if (task.completed) {
      await ref.update({
        'completedAt': null,
        'completedByName': null,
        'completedByUid': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    await ref.update({
      'completedAt': FieldValue.serverTimestamp(),
      'completedByName': _displayName(user),
      'completedByUid': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeTask(String id) async {
    _requireUser();
    await _firestore.collection('sharedTasks').doc(id).delete();
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
