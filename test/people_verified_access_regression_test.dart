import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('People location surface requires a verified signed-in account', () {
    final hub = File(
      'lib/src/features/people/people_hub_page.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/src/shell/homi_shell.dart',
    ).readAsStringSync();

    expect(hub, contains('user == null || user.emailVerified != true'));
    expect(hub, contains('Sign in to use People & location'));
    expect(hub, contains('Verify your email to use People & location'));
    expect(hub, contains('Send verification email'));
    expect(hub, contains('I’ve verified — refresh'));
    expect(
      hub,
      contains('Homi keeps location sharing, trusted connections, maps and safety check-ins locked'),
    );
    expect(
      shell,
      contains('authService: widget.authService'),
      reason: 'People access must use the shared authenticated account state.',
    );

    final location = File(
      'lib/src/services/location_status_service.dart',
    ).readAsStringSync();
    final checkIn = File(
      'lib/src/services/arrival_check_in_service.dart',
    ).readAsStringSync();
    final callable = File(
      'functions/location_share.js',
    ).readAsStringSync();
    final rules = File(
      'firebase/firestore.rules',
    ).readAsStringSync();

    expect(location, contains('user.emailVerified != true'));
    expect(checkIn, contains('user.emailVerified != true'));
    expect(callable, contains('request.auth.token.email_verified !== true'));
    expect(rules, contains('function verifiedSignedIn()'));
    expect(rules, contains('function isVerifiedSelf(uid)'));
  });
}
