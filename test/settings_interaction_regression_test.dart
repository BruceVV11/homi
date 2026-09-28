import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification settings keep the requested instant tap contract', () {
    final page = File(
      'lib/src/features/profile/notification_settings_page.dart',
    ).readAsStringSync();
    final service = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();

    expect(
      page,
      contains('onTap: canToggle ? () => onChanged!(!value) : null'),
      reason: 'The whole notification preference card must be a tap target.',
    );
    expect(
      page,
      isNot(contains("'Notifications are on for this device.'")),
      reason: 'Do not reintroduce the redundant enabled-success banner.',
    );
    expect(
      RegExp(r'enabled: active,').allMatches(page).length,
      5,
      reason:
          'Every notification category must stay disabled until both the Homi master setting and Android permission are active.',
    );
    expect(
      page,
      contains('opacity: canToggle ? 1 : 0.42'),
      reason:
          'Disabled notification categories must look visibly disabled, not only reject taps.',
    );
    expect(
      page,
      contains('_PushDeliveryStatusCard'),
      reason:
          'Notification settings must expose whether remote push registration is actually ready.',
    );

    final setEnabledStart = service.indexOf(
      'Future<void> setEnabled(bool value) async {',
    );
    final updateStart = service.indexOf(
      'Future<void> updatePreferences(HomiNotificationPreferences value) async {',
    );
    expect(setEnabledStart, greaterThanOrEqualTo(0));
    expect(updateStart, greaterThan(setEnabledStart));

    final setEnabledBody = service.substring(setEnabledStart, updateStart);
    expect(
      setEnabledBody.indexOf('notifyListeners();'),
      lessThan(setEnabledBody.indexOf('await _savePreferences();')),
      reason:
          'Master notification state must repaint before local/provider work.',
    );

    final updateEnd = service.indexOf(
      'Future<void> _savePreferences() async {',
      updateStart,
    );
    final updateBody = service.substring(updateStart, updateEnd);
    expect(
      updateBody.indexOf('notifyListeners();'),
      lessThan(updateBody.indexOf('await _savePreferences();')),
      reason:
          'Category notification state must repaint before local/provider work.',
    );
    expect(
      service,
      contains('_queuePreferenceSync();'),
      reason: 'Remote notification registration belongs in background sync.',
    );
  });

  test('sign out keeps session closure ahead of provider cleanup', () {
    final hub = File(
      'lib/src/features/profile/account_hub_page.dart',
    ).readAsStringSync();
    final auth = File(
      'lib/src/services/auth_service.dart',
    ).readAsStringSync();

    expect(
      hub,
      contains("label: Text(_signingOut ? 'Signing out…' : 'Sign out')"),
      reason: 'Sign-out progress should live inside the button.',
    );
    expect(
      hub,
      contains('if (_busy && !_signingOut)'),
      reason:
          'The generic below-button spinner must not render during sign-out.',
    );
    expect(
      hub,
      contains('.timeout(const Duration(seconds: 1))'),
      reason: 'Push cleanup must not hold sign-out indefinitely.',
    );

    final authSignOut = auth.indexOf('await _auth.signOut();');
    final googleCleanup = auth.indexOf(
      'await _googleSignIn',
      authSignOut,
    );

    expect(authSignOut, greaterThanOrEqualTo(0));
    expect(googleCleanup, greaterThan(authSignOut));
    expect(
      auth.substring(authSignOut, googleCleanup),
      isNot(contains('await _googleSignIn')),
      reason: 'Firebase Auth is the actual Homi session boundary.',
    );
    expect(
      auth,
      contains('.timeout(const Duration(seconds: 1))'),
      reason: 'Google provider cleanup must be bounded.',
    );
  });
}
