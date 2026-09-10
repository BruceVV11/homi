import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/arrival_check_in_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import 'people_page.dart';

/// Compatibility wrapper retained so the app shell does not need a navigation
/// rewrite. The People tab itself remains the original map-first PeoplePage.
///
/// PeoplePage owns several realtime Firestore subscriptions that are scoped to
/// the authenticated UID at creation time. Recreate only this destination when
/// Firebase restores, refreshes or clears the signed-in identity so a kept-alive
/// page can never remain bound to a stale/signed-out session.
class PeopleHubPage extends StatefulWidget {
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
  State<PeopleHubPage> createState() => _PeopleHubPageState();
}

class _PeopleHubPageState extends State<PeopleHubPage> {
  StreamSubscription<User?>? _authSubscription;
  String? _authUid;

  @override
  void initState() {
    super.initState();
    _authUid = widget.firebaseReady ? FirebaseAuth.instance.currentUser?.uid : null;
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((user) {
        final uid = user?.uid;
        if (!mounted || uid == _authUid) return;
        setState(() => _authUid = uid);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PeoplePage(
      key: ValueKey<String>('people:${_authUid ?? 'signed-out'}'),
      locationService: widget.locationService,
      trustedPeopleService: widget.trustedPeopleService,
      checkInService: widget.checkInService,
      firebaseReady: widget.firebaseReady,
      onSignIn: widget.onSignIn,
    );
  }
}
