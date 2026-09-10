import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomiCloudActionException implements Exception {
  const HomiCloudActionException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Small typed boundary around Homi's callable backend mutations.
///
/// Sensitive writes such as connection creation, shared-task mutation and
/// arrival delivery are intentionally routed through this service instead of
/// being written directly to Firestore by the app. The Firebase callable SDK
/// attaches Authentication and App Check tokens automatically; this boundary
/// also retries one genuinely stale protected session before surfacing a
/// product-level error.
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const HomiCloudActionException(
        code: 'unauthenticated',
        message: 'Sign in to continue.',
      );
    }

    try {
      return await _invoke(name, data);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        final recovered = await _refreshProtectedSession(user);
        if (recovered) {
          try {
            return await _invoke(name, data);
          } on FirebaseFunctionsException catch (retryError) {
            throw HomiCloudActionException(
              code: retryError.code,
              message: _friendlyMessage(retryError),
            );
          }
        }
      }

      throw HomiCloudActionException(
        code: error.code,
        message: _friendlyMessage(error),
      );
    }
  }

  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(name).call<dynamic>(data);
    final value = result.data;
    if (value == null) return const <String, dynamic>{};
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const HomiCloudActionException(
      code: 'invalid-response',
      message: 'Homi received an unexpected response. Try again.',
    );
  }

  Future<bool> _refreshProtectedSession(User user) async {
    try {
      // Refresh both proofs once. A stale Firebase ID token and a stale App
      // Check token can both surface as an unauthenticated protected callable.
      await user.getIdToken(true);
      await FirebaseAppCheck.instance.getToken(true);
      return FirebaseAuth.instance.currentUser?.uid == user.uid;
    } catch (_) {
      return false;
    }
  }

  String _friendlyMessage(FirebaseFunctionsException error) {
    final backendMessage = error.message?.trim();

    return switch (error.code) {
      'unauthenticated' =>
        'Homi could not verify your signed-in session. Check your connection and try again.',
      'unavailable' =>
        'Homi could not reach its cloud service. Check your connection and try again.',
      'deadline-exceeded' =>
        'Homi took too long to respond. Check your connection and try again.',
      'permission-denied' => 'That action is not available to this account.',
      'resource-exhausted' => 'Too many attempts. Wait a moment and try again.',
      'invalid-argument' => backendMessage?.isNotEmpty == true
          ? backendMessage!
          : 'Check the details and try again.',
      'failed-precondition' => backendMessage?.isNotEmpty == true
          ? backendMessage!
          : 'Homi cannot complete that action yet.',
      _ => 'Homi could not complete that action. Try again.',
    };
  }
}
