import 'package:cloud_functions/cloud_functions.dart';

class HomiCloudActionException implements Exception {
  const HomiCloudActionException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Small typed boundary around Homi's callable backend mutations.
///
/// Firebase Authentication and App Check tokens are attached by the Firebase
/// client SDK. Sensitive writes such as connection creation and shared-task
/// mutation are intentionally routed through this service instead of being
/// written directly to Firestore by the app.
class HomiCloudActions {
  HomiCloudActions({required this.firebaseReady});

  final bool firebaseReady;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'africa-south1');

  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const <String, dynamic>{},
  ]) async {
    if (!firebaseReady) {
      throw const HomiCloudActionException(
        code: 'unavailable',
        message: 'Homi cloud services are unavailable on this device.',
      );
    }

    try {
      final result = await _functions.httpsCallable(name).call<dynamic>(data);
      final value = result.data;
      if (value == null) return const <String, dynamic>{};
      if (value is Map) return Map<String, dynamic>.from(value);
      throw const HomiCloudActionException(
        code: 'invalid-response',
        message: 'Homi received an unexpected response. Try again.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw HomiCloudActionException(
        code: error.code,
        message: _friendlyMessage(error),
      );
    }
  }

  String _friendlyMessage(FirebaseFunctionsException error) {
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) return message;

    return switch (error.code) {
      'unauthenticated' => 'Sign in to continue.',
      'failed-precondition' => 'Homi cannot complete that action yet.',
      'permission-denied' => 'That action is not available to this account.',
      'resource-exhausted' => 'Too many attempts. Wait a moment and try again.',
      'unavailable' => 'Homi could not reach the cloud service. Try again shortly.',
      _ => 'Homi could not complete that action. Try again.',
    };
  }
}
