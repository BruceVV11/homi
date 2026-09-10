import 'package:flutter/material.dart';

import '../../services/arrival_check_in_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import 'people_page.dart';

/// Compatibility wrapper retained so the app shell does not need a navigation
/// rewrite. The People tab itself is the original map-first PeoplePage again;
/// 0.9 additions are integrated into that page rather than replacing it.
class PeopleHubPage extends StatelessWidget {
  const PeopleHubPage({
    required this.locationService,
    required this.trustedPeopleService,
    required this.checkInService,
    required this.firebaseReady,
    required this.onSignIn,
    super.key,
  });

  final LocationStatusService locationService;
  final TrustedPeopleService trustedPeopleService;
  final ArrivalCheckInService checkInService;
  final bool firebaseReady;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return PeoplePage(
      locationService: locationService,
      trustedPeopleService: trustedPeopleService,
      checkInService: checkInService,
      firebaseReady: firebaseReady,
      onSignIn: onSignIn,
    );
  }
}