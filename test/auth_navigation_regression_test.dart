import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signed-out account hub reveals auth immediately', () {
    final hub = File(
      'lib/src/features/profile/account_hub_page.dart',
    ).readAsStringSync();

    expect(hub, contains('void _beginSignIn()'));
    expect(hub, contains('final openAuth = widget.onSignIn;'));
    expect(hub, contains('openAuth();'));
    expect(hub, contains('Navigator.of(context).pop();'));
    expect(
      hub,
      contains('onPressed: _busy ? null : _beginSignIn'),
      reason: 'The signed-out account CTA must use the route-closing helper.',
    );
  });

  test('authentication has a branded blocking progress state', () {
    final auth = File(
      'lib/src/features/auth/auth_page.dart',
    ).readAsStringSync();

    expect(auth, contains('bool _authenticating = false;'));
    expect(auth, contains("progressLabel:"));
    expect(auth, contains("'Signing you in…'"));
    expect(auth, contains("'Connecting with Google…'"));
    expect(auth, contains('class _AuthProgressOverlay'));
    expect(auth, contains('CircularProgressIndicator(strokeWidth: 3)'));
    expect(auth, contains('Setting up your secure Homi session.'));
    expect(
      auth,
      contains(
        'Shared Household, trusted-person and location features need an account.',
      ),
      reason: 'Local-only mode must be clearly distinct from a Free account.',
    );
  });
}
