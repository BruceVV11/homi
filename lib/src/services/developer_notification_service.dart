import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomiNotificationCampaign {
  const HomiNotificationCampaign({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.route,
    required this.audience,
    required this.priority,
    required this.status,
    required this.createdAt,
    this.sentCount = 0,
    this.failureCount = 0,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String route;
  final String audience;
  final String priority;
  final String status;
  final DateTime? createdAt;
  final int sentCount;
  final int failureCount;

  factory HomiNotificationCampaign.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final timestamp = data['createdAt'];
    return HomiNotificationCampaign(
      id: document.id,
      title: data['title'] as String? ?? 'Homi notification',
      body: data['body'] as String? ?? '',
      category: data['category'] as String? ?? 'update',
      route: data['route'] as String? ?? 'overview',
      audience: data['audience'] as String? ?? 'all',
      priority: data['priority'] as String? ?? 'normal',
      status: data['status'] as String? ?? 'queued',
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
      sentCount: (data['sentCount'] as num?)?.toInt() ?? 0,
      failureCount: (data['failureCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class DeveloperNotificationService {
  DeveloperNotificationService({required this.firebaseReady});

  final bool firebaseReady;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  User? get _user => firebaseReady ? FirebaseAuth.instance.currentUser : null;

  Future<bool> isDeveloperAdmin() async {
    final user = _user;
    if (user == null) return false;
    try {
      final snapshot =
          await _firestore.collection('developerAdmins').doc(user.uid).get();
      return snapshot.data()?['active'] == true;
    } on FirebaseException {
      return false;
    }
  }

  Future<void> queueCampaign({
    required String title,
    required String body,
    required String category,
    required String route,
    required String audience,
    required String priority,
  }) async {
    final user = _user;
    if (user == null) throw StateError('Sign in before sending a Homi notice.');
    if (!await isDeveloperAdmin()) {
      throw StateError('This account does not have developer notification access.');
    }
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      throw StateError('Add both a title and message.');
    }
    if (cleanTitle.length > 80 || cleanBody.length > 280) {
      throw StateError('Keep the title under 80 characters and the message under 280.');
    }

    await _firestore.collection('notificationCampaigns').add({
      'title': cleanTitle,
      'body': cleanBody,
      'category': category,
      'route': route,
      'audience': audience,
      'priority': priority,
      'createdByUid': user.uid,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<HomiNotificationCampaign>> watchRecentCampaigns() {
    final user = _user;
    if (user == null) {
      return Stream.value(const <HomiNotificationCampaign>[]);
    }
    return _firestore
        .collection('notificationCampaigns')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HomiNotificationCampaign.fromDocument)
              .toList(growable: false),
        );
  }
}
