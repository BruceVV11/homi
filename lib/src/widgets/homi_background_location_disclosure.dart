import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'homi_controls.dart';

const _backgroundLocationDisclosureKey =
    'homi.location.backgroundDisclosureAccepted.v1';

/// Shows Homi's prominent background-location disclosure before Android is
/// allowed to present a runtime location permission prompt.
///
/// The acknowledgement is device-local and intentionally survives normal app
/// restarts so Homi does not repeatedly interrupt a user who has already read
/// and accepted the disclosure. Declining never changes Android permissions.
Future<bool> showHomiBackgroundLocationDisclosure(
  BuildContext context,
) async {
  SharedPreferences? preferences;
  try {
    preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(_backgroundLocationDisclosureKey) == true) {
      return true;
    }
  } catch (_) {
    // If local preference storage is temporarily unavailable, still show the
    // disclosure. Permission must never be requested without the disclosure.
  }

  if (!context.mounted) return false;

  final accepted = await showHomiConfirmSheet(
    context,
    title: 'Location in the background',
    message:
        'Homi collects location data to keep Live Location sharing and Home or Work arrival check-ins working even when Homi is closed or not in use. Background location is only used while one of these features is turned on. Live Location is shared only with people you choose, and arrival check-ins are sent only to recipients you choose. You can turn either feature off at any time.',
    confirmLabel: 'Continue',
    cancelLabel: 'Not now',
    icon: Icons.location_on_outlined,
  );

  if (accepted) {
    try {
      preferences ??= await SharedPreferences.getInstance();
      await preferences.setBool(_backgroundLocationDisclosureKey, true);
    } catch (_) {
      // The disclosure has already been shown for this action. A preference
      // write failure must not silently grant permission on a later attempt;
      // the disclosure will simply be shown again.
    }
  }

  return accepted;
}
