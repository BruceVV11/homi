import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/arrival_check_in_service.dart';
import '../../services/location_status_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_page.dart';
import 'people_page.dart';
import 'safety_check_in_page.dart';

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

class _PeopleHubPageState extends State<PeopleHubPage>
    with AutomaticKeepAliveClientMixin<PeopleHubPage> {
  StreamSubscription<List<TrustedConnection>>? _connectionSubscription;
  StreamSubscription<Map<String, TrustedPersonPreference>>?
      _preferenceSubscription;
  StreamSubscription<User?>? _authSubscription;
  List<TrustedConnection> _connections = const <TrustedConnection>[];
  Map<String, TrustedPersonPreference> _preferences =
      const <String, TrustedPersonPreference>{};
  String? _message;

  User? get _user =>
      widget.firebaseReady ? FirebaseAuth.instance.currentUser : null;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.checkInService.addListener(_refresh);
    if (widget.firebaseReady) {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
        _bind();
        if (mounted) setState(() {});
      });
    }
    _bind();
  }

  @override
  void dispose() {
    widget.checkInService.removeListener(_refresh);
    _connectionSubscription?.cancel();
    _preferenceSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _bind() {
    _connectionSubscription?.cancel();
    _preferenceSubscription?.cancel();
    if (_user == null) {
      if (mounted) {
        setState(() {
          _connections = const <TrustedConnection>[];
          _preferences = const <String, TrustedPersonPreference>{};
        });
      }
      return;
    }

    _connectionSubscription = widget.trustedPeopleService
        .watchConnections()
        .listen((value) {
      if (!mounted) return;
      setState(() {
        _connections = value;
        _message = null;
      });
    }, onError: (_) {
      if (mounted) {
        setState(() => _message =
            'People could not refresh. Homi will try again automatically.');
      }
    });
    _preferenceSubscription = widget.trustedPeopleService
        .watchPreferences()
        .listen((value) {
      if (mounted) setState(() => _preferences = value);
    }, onError: (_) {});
  }

  Future<void> _openPeopleManager() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: HomiColors.cream,
          appBar: AppBar(
            title: const Text('Connections & location'),
            backgroundColor: HomiColors.cream,
            surfaceTintColor: Colors.transparent,
          ),
          body: PeoplePage(
            locationService: widget.locationService,
            trustedPeopleService: widget.trustedPeopleService,
            firebaseReady: widget.firebaseReady,
            onSignIn: widget.onSignIn,
          ),
        ),
      ),
    );
  }

  Future<void> _openSafety() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SafetyCheckInPage(
          checkInService: widget.checkInService,
          locationService: widget.locationService,
          trustedPeopleService: widget.trustedPeopleService,
          firebaseReady: widget.firebaseReady,
          onSignIn: widget.onSignIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = _user;
    final accepted = user == null
        ? const <TrustedConnection>[]
        : _connections.where((item) => item.accepted).toList(growable: false);
    final pending = _connections.where((item) => item.pending).toList(growable: false);

    final household = <TrustedConnection>[];
    final trusted = <TrustedConnection>[];
    if (user != null) {
      for (final connection in accepted) {
        final uid = connection.otherUid(user.uid);
        if (_preferences[uid]?.household == true) {
          household.add(connection);
        } else {
          trusted.add(connection);
        }
      }
      household.sort((a, b) =>
          a.otherName(user.uid).compareTo(b.otherName(user.uid)));
      trusted.sort((a, b) =>
          a.otherName(user.uid).compareTo(b.otherName(user.uid)));
    }

    return HomiPage(
      title: 'People',
      subtitle: 'Your household, trusted people, location and check-ins in one place.',
      children: [
        _SafetyCard(
          checkInsEnabled: widget.checkInService.config.enabled,
          onTap: _openSafety,
        ),
        const SizedBox(height: 12),
        if (user == null)
          _SignedOutCard(onSignIn: widget.onSignIn)
        else ...[
          if (_message != null) ...[
            _QuietNotice(text: _message!),
            const SizedBox(height: 12),
          ],
          if (pending.isNotEmpty) ...[
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _openPeopleManager,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: HomiColors.peach.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.person_add_alt_1_rounded,
                            color: HomiColors.coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pending.length} ${pending.length == 1 ? 'connection request' : 'connection requests'}',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Open connections to review pending invitations.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
          _SectionHeader(
            title: 'Household',
            count: household.length,
            detail: 'People who share your household context and can be assigned household tasks.',
          ),
          const SizedBox(height: 9),
          if (household.isEmpty)
            const _EmptyPeopleCard(
              icon: Icons.home_outlined,
              title: 'No household members yet',
              detail:
                  'Connected people you mark as Household will appear here.',
            )
          else
            ...household.map((connection) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _PersonCard(
                    connection: connection,
                    currentUid: user.uid,
                    preference: _preferences[connection.otherUid(user.uid)] ??
                        TrustedPersonPreference.fallback,
                    household: true,
                    onTap: _openPeopleManager,
                  ),
                )),
          const SizedBox(height: 20),
          _SectionHeader(
            title: 'Friends & trusted people',
            count: trusted.length,
            detail:
                'Connected people who stay outside your household task and home-data context.',
          ),
          const SizedBox(height: 9),
          if (trusted.isEmpty)
            const _EmptyPeopleCard(
              icon: Icons.favorite_border_rounded,
              title: 'No other trusted people yet',
              detail:
                  'Friends and location-only connections will appear separately here.',
            )
          else
            ...trusted.map((connection) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _PersonCard(
                    connection: connection,
                    currentUid: user.uid,
                    preference: _preferences[connection.otherUid(user.uid)] ??
                        TrustedPersonPreference.fallback,
                    household: false,
                    onTap: _openPeopleManager,
                  ),
                )),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openPeopleManager,
              icon: const Icon(Icons.people_outline_rounded),
              label: const Text('Manage connections & live location'),
            ),
          ),
        ],
      ],
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard({required this.checkInsEnabled, required this.onTap});

  final bool checkInsEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HomiColors.coral.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.health_and_safety_outlined,
                    color: HomiColors.coral),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Safety & check-ins',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(height: 3),
                    Text(
                      checkInsEnabled
                          ? 'Emergency call shortcuts · arrival check-ins on'
                          : 'Emergency call shortcuts · Home & Work arrival check-ins',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.detail,
  });

  final String title;
  final int count;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: HomiColors.sage.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$count',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(detail, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.connection,
    required this.currentUid,
    required this.preference,
    required this.household,
    required this.onTap,
  });

  final TrustedConnection connection;
  final String currentUid;
  final TrustedPersonPreference preference;
  final bool household;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = connection.otherName(currentUid);
    final photoUrl = connection.otherPhotoUrl(currentUid);
    final relation = preference.relationship == 'Trusted person'
        ? (household ? 'Household member' : 'Trusted person')
        : preference.relationship;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _PersonAvatar(name: name, photoUrl: photoUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(relation, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: household
                      ? HomiColors.sage.withValues(alpha: 0.18)
                      : HomiColors.peach.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  household ? 'Household' : 'Trusted',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return Container(
      width: 46,
      height: 46,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.27),
        shape: BoxShape.circle,
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: Text(
                name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
                style: const TextStyle(
                  color: HomiColors.slate,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: HomiColors.slate,
              ),
            ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Connect your people',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              'Sign in to connect trusted people, choose who belongs to your household and share location when you want to.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      ),
    );
  }
}

class _EmptyPeopleCard extends StatelessWidget {
  const _EmptyPeopleCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: HomiColors.coral),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietNotice extends StatelessWidget {
  const _QuietNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
