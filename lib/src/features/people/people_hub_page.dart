import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/arrival_check_in_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';
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
    required this.authService,
    required this.locationService,
    required this.trustedPeopleService,
    required this.checkInService,
    required this.firebaseReady,
    required this.onSignIn,
    super.key,
  });

  final AuthService authService;
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
  User? _authUser;
  bool _verificationBusy = false;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    _authUser = widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.idTokenChanges().listen((user) {
        if (!mounted) return;
        final previous = _authUser;
        if (previous?.uid == user?.uid &&
            previous?.emailVerified == user?.emailVerified) {
          return;
        }
        setState(() {
          _authUser = user;
          _verificationMessage = null;
        });
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    if (_verificationBusy || _authUser == null) return;
    setState(() {
      _verificationBusy = true;
      _verificationMessage = null;
    });
    try {
      await widget.authService.sendCurrentUserVerification();
      if (!mounted) return;
      setState(() {
        _verificationMessage =
            'Verification email sent. Open it, then come back and refresh.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verificationMessage =
            error.message ?? 'Homi could not send the verification email.';
      });
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
    }
  }

  Future<void> _refreshVerification() async {
    if (_verificationBusy || _authUser == null) return;
    setState(() {
      _verificationBusy = true;
      _verificationMessage = null;
    });
    try {
      final refreshed = await widget.authService.reloadCurrentUser();
      if (!mounted) return;
      setState(() {
        _authUser = refreshed;
        _verificationMessage = refreshed?.emailVerified == true
            ? null
            : 'That email is not verified yet. Open the verification link, then try again.';
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _verificationMessage =
            error.message ?? 'Homi could not refresh your verification status.';
      });
    } finally {
      if (mounted) setState(() => _verificationBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authUser;
    if (user == null || user.emailVerified != true) {
      return HomiPage(
        title: 'People',
        subtitle: 'Private location sharing and trusted connections.',
        children: [
          _PeopleAccessGate(
            signedIn: user != null,
            email: user?.email,
            busy: _verificationBusy,
            message: _verificationMessage,
            onSignIn: widget.onSignIn,
            onSendVerification: _sendVerification,
            onRefreshVerification: _refreshVerification,
          ),
        ],
      );
    }

    return PeoplePage(
      key: ValueKey<String>('people:${user.uid}:verified'),
      locationService: widget.locationService,
      trustedPeopleService: widget.trustedPeopleService,
      checkInService: widget.checkInService,
      firebaseReady: widget.firebaseReady,
      onSignIn: widget.onSignIn,
    );
  }
}

class _PeopleAccessGate extends StatelessWidget {
  const _PeopleAccessGate({
    required this.signedIn,
    required this.email,
    required this.busy,
    required this.message,
    required this.onSignIn,
    required this.onSendVerification,
    required this.onRefreshVerification,
  });

  final bool signedIn;
  final String? email;
  final bool busy;
  final String? message;
  final VoidCallback onSignIn;
  final VoidCallback onSendVerification;
  final VoidCallback onRefreshVerification;

  @override
  Widget build(BuildContext context) {
    final address = email?.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomiColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: HomiColors.peach.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.location_off_outlined,
              size: 34,
              color: HomiColors.coral,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            signedIn
                ? 'Verify your email to use People & location'
                : 'Sign in to use People & location',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            signedIn
                ? 'Homi keeps location sharing, trusted connections, maps and safety check-ins locked until your account email is verified.${address == null || address.isEmpty ? '' : '\n\nSigned in as $address'}'
                : 'People & location is an account feature. Sign in first, then use a verified email before Homi can show maps, connections or location-sharing controls.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HomiColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HomiColors.border),
              ),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (!signedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onSignIn,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign in'),
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : onSendVerification,
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: Text(busy ? 'Please wait…' : 'Send verification email'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRefreshVerification,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('I’ve verified — refresh'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Your personal Home, Tasks, Routines and Supplies can still stay on this phone without an account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
