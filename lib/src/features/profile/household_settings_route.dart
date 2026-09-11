import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../services/household_service.dart';
import '../../services/trusted_people_service.dart';
import '../../state/homi_app_controller.dart';
import '../../theme/homi_theme.dart';
import 'household_settings_page.dart';

/// Loads the existing local Homi home identity before opening the canonical
/// shared-Household management surface. Keeping this route self-contained lets
/// profile/account UI open Household settings without duplicating app-shell
/// service ownership or changing local-first household state.
class HouseholdSettingsRoute extends StatefulWidget {
  const HouseholdSettingsRoute({super.key});

  @override
  State<HouseholdSettingsRoute> createState() => _HouseholdSettingsRouteState();
}

class _HouseholdSettingsRouteState extends State<HouseholdSettingsRoute> {
  final HomiAppController _controller = HomiAppController();
  late final HouseholdService _householdService;
  late final TrustedPeopleService _trustedPeopleService;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final firebaseReady = Firebase.apps.isNotEmpty;
    _householdService = HouseholdService(firebaseReady: firebaseReady);
    _trustedPeopleService = TrustedPeopleService(firebaseReady: firebaseReady);
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _ready = false;
        _error = null;
      });
    }
    try {
      await _controller.load();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Homi could not load your local home details. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return HouseholdSettingsPage(
        householdService: _householdService,
        trustedPeopleService: _trustedPeopleService,
        controller: _controller,
        // This route is entered from a signed-in profile. If the auth session
        // disappears while it is open, returning to Account is the safe path.
        onSignIn: () {
          Navigator.of(context).maybePop();
        },
      );
    }

    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Household'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
