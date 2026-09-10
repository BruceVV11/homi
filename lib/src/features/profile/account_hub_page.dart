import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/account_data_service.dart';
import '../../services/auth_service.dart';
import '../../services/location_status_service.dart';
import '../../state/homi_app_controller.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/google_provider_mark.dart';
import '../../widgets/homi_controls.dart';
import 'profile_settings_page.dart';

class AccountHubPage extends StatefulWidget {
  const AccountHubPage({
    required this.authService,
    required this.accountDataService,
    required this.controller,
    required this.locationService,
    required this.onSignIn,
    super.key,
  });

  final AuthService authService;
  final AccountDataService accountDataService;
  final HomiAppController controller;
  final LocationStatusService locationService;
  final VoidCallback onSignIn;

  @override
  State<AccountHubPage> createState() => _AccountHubPageState();
}

class _AccountHubPageState extends State<AccountHubPage> {
  bool _busy = false;

  User? get _user => widget.authService.currentUser;

  String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email != null && email.contains('@')) return email.split('@').first;
    return 'Your Homi';
  }

  Future<void> _openProfile() async {
    if (_user == null) {
      widget.onSignIn();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsPage(authService: widget.authService),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.locationService.stopContinuousSharing();
      await widget.authService.signOut();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _eraseLocalData() async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Erase Homi data from this phone?',
      message:
          'This removes local Tasks, Routines, Supplies, Home records and Homi’s cached location from this device. Your signed-in cloud account and records shared with other people are not deleted by this action.',
      confirmLabel: 'Erase this phone',
      cancelLabel: 'Keep my data',
      icon: Icons.phonelink_erase_outlined,
      destructive: true,
    );
    if (!confirmed || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.locationService.clearCachedStatus();
      await widget.controller.eraseLocalHouseholdData();
      if (!mounted) return;
      await _showMessage(
        title: 'This phone has been cleared',
        message:
            'Local household records and Homi’s cached location were erased from this device.',
        icon: Icons.check_circle_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final user = _user;
    if (user == null || _busy) return;

    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Permanently delete your Homi account?',
      message:
          'This cannot be undone. Homi will delete your account identity, connection code, trusted connections, location-sharing permissions, latest cloud location and cloud collaboration data associated with your account. It will also erase this phone’s Homi household data and cached location.',
      confirmLabel: 'Continue to delete',
      cancelLabel: 'Keep my account',
      icon: Icons.delete_forever_outlined,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    String? password;
    if (widget.authService.signedInWithPassword(user)) {
      password = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _PasswordConfirmationSheet(),
      );
      if (password == null || password.isEmpty || !mounted) return;
    }

    final finalCheck = await showHomiConfirmSheet(
      context,
      title: 'Final confirmation',
      message:
          'Delete ${user.email ?? 'this Homi account'} and its associated cloud data permanently?',
      confirmLabel: 'Delete permanently',
      cancelLabel: 'Cancel',
      icon: Icons.warning_amber_rounded,
      destructive: true,
    );
    if (!finalCheck || _busy) return;

    setState(() => _busy = true);
    try {
      await widget.locationService.stopContinuousSharing();
      await widget.authService.reauthenticateCurrentUser(password: password);
      await widget.accountDataService.deleteCurrentAccountData();
      await widget.authService.deleteReauthenticatedCurrentUser();
      await widget.controller.eraseLocalHouseholdData();
      await widget.locationService.clearCachedStatus();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      await _showMessage(
        title: 'Account deletion did not finish',
        message:
            '${_friendly(error)} Your account remains available so you can retry. If cloud cleanup partially completed, retrying is safe.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showMessage({
    required String title,
    required String message,
    required IconData icon,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HomiColors.peach.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: HomiColors.coral),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendly(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Homi could not confirm your current sign-in details.';
        case 'requires-recent-login':
          return 'Homi needs you to confirm your sign-in again before deletion.';
        case 'network-request-failed':
          return 'Homi could not reach the account service.';
      }
      return error.message ?? 'Homi could not complete the account request.';
    }
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final google = user != null && widget.authService.signedInWithGoogle(user);

    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Homi & account'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
          children: [
            _AccountHero(
              user: user,
              displayName: _displayName(user),
              google: google,
              onTap: _openProfile,
            ),
            const SizedBox(height: 20),
            Text('Homi', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _HubCard(
              icon: Icons.favorite_outline_rounded,
              title: 'Why Homi exists',
              subtitle: 'The problem Homi is trying to solve at home and beyond it.',
              onTap: () => _openInfo(context, HomiInfoTopic.whyHomi),
            ),
            _HubCard(
              icon: Icons.help_outline_rounded,
              title: 'Help & support',
              subtitle: 'How Homi works, common questions and support.',
              onTap: () => _openInfo(context, HomiInfoTopic.help),
            ),
            const SizedBox(height: 14),
            Text('Privacy & legal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _HubCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy & your data',
              subtitle: 'What stays on your phone, what uses the cloud and why.',
              onTap: () => _openInfo(context, HomiInfoTopic.privacy),
            ),
            _HubCard(
              icon: Icons.location_on_outlined,
              title: 'Location & safety',
              subtitle: 'Consent, background location, accuracy and important limits.',
              onTap: () => _openInfo(context, HomiInfoTopic.location),
            ),
            _HubCard(
              icon: Icons.description_outlined,
              title: 'Terms of use',
              subtitle: 'The practical rules and responsibilities for using Homi.',
              onTap: () => _openInfo(context, HomiInfoTopic.terms),
            ),
            _HubCard(
              icon: Icons.info_outline_rounded,
              title: 'About Homi',
              subtitle: 'Version, developer information and product principles.',
              onTap: () => _openInfo(context, HomiInfoTopic.about),
            ),
            const SizedBox(height: 14),
            Text('Your data', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            _HubCard(
              icon: Icons.phonelink_erase_outlined,
              title: 'Erase data from this phone',
              subtitle:
                  'Clear local household records and cached location without deleting your cloud account.',
              onTap: _busy ? null : _eraseLocalData,
            ),
            if (user != null)
              _HubCard(
                icon: Icons.delete_forever_outlined,
                title: 'Delete Homi account',
                subtitle:
                    'Permanently remove your account and associated Homi cloud data.',
                destructive: true,
                onTap: _busy ? null : _deleteAccount,
              ),
            const SizedBox(height: 14),
            if (user == null)
              FilledButton.icon(
                onPressed: _busy ? null : widget.onSignIn,
                icon: const Icon(Icons.cloud_outlined),
                label: const Text('Sign in for cloud features'),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openInfo(BuildContext context, HomiInfoTopic topic) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => HomiInfoPage(topic: topic)),
    );
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({
    required this.user,
    required this.displayName,
    required this.google,
    required this.onTap,
  });

  final User? user;
  final String displayName;
  final bool google;
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
              _Avatar(user: user, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (google) ...[
                          const SizedBox(width: 7),
                          const GoogleProviderMark(size: 18),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user == null
                          ? 'Using Homi on this phone'
                          : (user?.email ?? 'Signed in'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user == null
                          ? 'Tap to sign in'
                          : 'Tap for profile settings',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: HomiColors.coral,
                      ),
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

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : HomiColors.coral;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: destructive ? color : HomiColors.slate,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size});
  final User? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HomiColors.sage.withValues(alpha: 0.34),
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.52)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.person_rounded, size: size * 0.52),
            ),
    );
  }
}

enum HomiInfoTopic { whyHomi, privacy, location, terms, help, about }

class HomiInfoPage extends StatelessWidget {
  const HomiInfoPage({required this.topic, super.key});
  final HomiInfoTopic topic;

  @override
  Widget build(BuildContext context) {
    final content = _content(topic);
    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: Text(content.title),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(content.icon, color: HomiColors.coral, size: 27),
            ),
            const SizedBox(height: 14),
            Text(content.title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(content.intro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 22),
            ...content.sections.map(
              (section) => _InfoSection(section: section),
            ),
            if (topic == HomiInfoTopic.help) ...[
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://theconceptlab.co.za'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Visit Concept Lab'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.section});
  final _SectionContent section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                section.heading,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...section.paragraphs.map(
                (paragraph) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text(
                    paragraph,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordConfirmationSheet extends StatefulWidget {
  const _PasswordConfirmationSheet();

  @override
  State<_PasswordConfirmationSheet> createState() =>
      _PasswordConfirmationSheetState();
}

class _PasswordConfirmationSheetState
    extends State<_PasswordConfirmationSheet> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm it is you',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 7),
            Text(
              'Firebase requires a recent sign-in before Homi can permanently delete an account. Your password is used only for this confirmation and is not stored.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (_controller.text.isNotEmpty) {
                  Navigator.pop(context, _controller.text);
                }
              },
              decoration: InputDecoration(
                labelText: 'Current password',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    Navigator.pop(context, _controller.text);
                  }
                },
                child: const Text('Confirm sign-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoContent {
  const _InfoContent({
    required this.title,
    required this.icon,
    required this.intro,
    required this.sections,
  });

  final String title;
  final IconData icon;
  final String intro;
  final List<_SectionContent> sections;
}

class _SectionContent {
  const _SectionContent(this.heading, this.paragraphs);
  final String heading;
  final List<String> paragraphs;
}

_InfoContent _content(HomiInfoTopic topic) {
  switch (topic) {
    case HomiInfoTopic.whyHomi:
      return const _InfoContent(
        title: 'Why Homi exists',
        icon: Icons.favorite_outline_rounded,
        intro:
            'A home is full of small things that matter, but most of them live in somebody’s head. Homi exists to make that shared picture easier to see without turning home life into another admin job.',
        sections: [
          _SectionContent('The problem at home', [
            'Homes run on dozens of small decisions: who fed the dogs, whether the milk is finished, when the geyser was serviced, what needs to be bought, who was meant to take something out of the freezer, or whether a recurring job has already been done.',
            'The information is usually scattered between memory, messages, notes, cupboards and one person who quietly keeps track of more than everyone realises. That works until somebody forgets, plans change, or another person needs the answer immediately.',
          ]),
          _SectionContent('A shared source of truth', [
            'Homi is being built as a practical operating layer for everyday home life. Tasks deal with one-off jobs. Routines deal with things that come back. Supplies make it easier to see what is running out or expiring. Home keeps useful history about the physical things you own and maintain.',
            'The goal is not to record every tiny detail. Homi should ask for only enough information to prevent repeated questions, missed responsibilities and avoidable uncertainty.',
          ]),
          _SectionContent('The people you care about', [
            'Home life is also connected to people. Sometimes knowing that someone you care about has arrived safely, where a partner is when plans change, or whether a close friend is still on the way is genuinely useful.',
            'That is why Homi’s People feature is broader than a family tracker. Partners, relatives, roommates and trusted friends can choose to share location with each other. The relationship can be location-only: a friend does not become part of your household data simply because you both choose to share location.',
          ]),
          _SectionContent('Useful, not intrusive', [
            'Homi is deliberately built around consent. Connecting with somebody, marking them as part of a household and sharing location are separate choices. A person controls whether their location is shared and can stop it again.',
            'The product should make home life clearer and the people you care about easier to check in on without creating a hidden surveillance system or a daily data-entry burden.',
          ]),
          _SectionContent('The standard we are aiming for', [
            'Homi should earn a place on someone’s phone by being useful in ordinary moments: “Has this been done?”, “Do we still have this?”, “When was that serviced?”, “Who is handling this?”, and “Are they where I expected them to be?”',
            'If a feature creates more administration than value, it does not belong in Homi in that form.',
          ]),
        ],
      );

    case HomiInfoTopic.privacy:
      return const _InfoContent(
        title: 'Privacy & your data',
        icon: Icons.privacy_tip_outlined,
        intro:
            'Homi is local-first where practical and uses cloud services only when a feature needs identity, sharing or multi-device access.',
        sections: [
          _SectionContent('What can stay on your phone', [
            'Homi can be used without creating an account. Local Tasks, Routines, Supplies, Home items, maintenance history and utility readings are currently stored on the device unless a specific sharing feature says otherwise.',
            'Signing out does not silently erase those local household records.',
          ]),
          _SectionContent('What currently uses the cloud', [
            'When you sign in and use cloud features, Homi may store account/profile identity, your Homi connection code, trusted connections, private relationship preferences, specifically shared household Tasks, location-sharing permissions, and your latest shared location/battery status.',
            'Full cloud sync of every Home, Routine and Supply record is not active yet. When that is introduced, Homi will explain what is being synced and will not silently overwrite meaningful local data.',
          ]),
          _SectionContent('Location data', [
            'Location is treated as sensitive. Homi only shares it with connected people you explicitly choose. Background updates require a separate permission and Android keeps a visible notification while live updates are active.',
            'Homi currently stores the latest location state rather than building a default long-term travel history.',
          ]),
          _SectionContent('Service providers', [
            'Homi uses Google/Firebase services for authentication and cloud data, and Google Maps services for map display. Those providers process technical data needed to deliver those services under their own terms and privacy commitments.',
          ]),
          _SectionContent('What Homi does not need', [
            'Homi does not need to sell your location or household records to make the product work. Privacy controls, stopping location sharing and deleting an account must not be locked behind a paid plan.',
          ]),
          _SectionContent('Your controls', [
            'You can stop live location updates, revoke location access to an individual person, disconnect trusted people, erase local data from a device, sign out, or permanently delete your Homi account.',
            'Deleting an account is different from signing out. Account deletion removes the Homi cloud identity and associated Homi cloud data that the app currently manages. The deletion flow also explicitly offers device-data removal rather than doing it invisibly.',
          ]),
        ],
      );

    case HomiInfoTopic.location:
      return const _InfoContent(
        title: 'Location & safety',
        icon: Icons.location_on_outlined,
        intro:
            'Location can be useful for everyday check-ins, but it is sensitive and it is never a guarantee that somebody is safe.',
        sections: [
          _SectionContent('Consent comes first', [
            'A trusted connection does not automatically start location sharing. Household status does not start location sharing either. The person being located decides who can see their location.',
            'Homi has no intended stealth-sharing mode. Live background updates are visible through Android’s foreground-service notification.',
          ]),
          _SectionContent('Friends are supported too', [
            'People can use Homi with close friends purely for location check-ins. A friend can remain “location only” and does not receive Home, Supplies, Routines or other household records.',
          ]),
          _SectionContent('Accuracy and freshness', [
            'Phone location can be delayed or inaccurate because of GPS conditions, network connectivity, battery state, Android permissions, device power management or the app process being stopped.',
            'Always look at the last-updated time. A map marker is not proof of a person’s current safety or exact position.',
          ]),
          _SectionContent('Battery-conscious updates', [
            'Homi’s current Android live mode uses medium accuracy, a movement threshold and spaced updates instead of continuously requesting maximum-accuracy GPS. Exact battery use varies by phone and conditions.',
          ]),
          _SectionContent('Not an emergency service', [
            'Homi does not dispatch emergency services, provide crash detection, guarantee child safety or replace emergency communication. If someone may be in danger, use the appropriate emergency services or contact them directly rather than relying on Homi alone.',
          ]),
          _SectionContent('Age and responsible use', [
            'Homi’s initial account experience is intended for adults. Do not use Homi to track another adult without their knowledge and consent. Any future product support specifically aimed at minors will require separate safety, consent and legal review before release.',
          ]),
        ],
      );

    case HomiInfoTopic.terms:
      return const _InfoContent(
        title: 'Terms of use',
        icon: Icons.description_outlined,
        intro:
            'These practical terms describe the intended use of the current Homi service. Formal launch terms should be professionally reviewed before public release.',
        sections: [
          _SectionContent('Using Homi', [
            'You are responsible for information you enter, the people you connect with and the permissions you grant. Use Homi lawfully and only share or track information you are entitled to use.',
          ]),
          _SectionContent('Location responsibility', [
            'Do not use Homi for covert tracking, harassment or surveillance. Location sharing requires the other Homi user’s participation and remains subject to phone permissions, connectivity and platform limitations.',
          ]),
          _SectionContent('Service availability', [
            'Homi is software, not an emergency or guaranteed-availability service. Features may be unavailable because of network, cloud-provider, device, operating-system or maintenance conditions. Keep independent ways to handle genuinely important household and safety matters.',
          ]),
          _SectionContent('Your content', [
            'You remain responsible for household notes, task text and other information you add. Do not upload unlawful content or information you do not have a right to use.',
          ]),
          _SectionContent('Subscriptions', [
            'Some future cloud or advanced features may require a paid Homi plan. Core consent, privacy, stop-sharing and account-deletion controls will not require payment. Any paid plan will show its price and renewal terms before purchase.',
          ]),
          _SectionContent('Changes', [
            'Homi will evolve. Material changes to privacy-sensitive behaviour, paid features or these terms should be communicated clearly rather than hidden inside a software update.',
          ]),
        ],
      );

    case HomiInfoTopic.help:
      return const _InfoContent(
        title: 'Help & support',
        icon: Icons.help_outline_rounded,
        intro:
            'Homi should explain itself in the place where a question appears. This page covers the broader questions that do not belong to one screen.',
        sections: [
          _SectionContent('Local or cloud?', [
            'You can use Homi locally without an account. Sign-in is for features that need identity or sharing. Not every household record is cloud-synced yet, so another phone will not automatically see every local record until household sync is enabled for that data type.',
          ]),
          _SectionContent('Why is my location not updating?', [
            'Check that location is enabled on the phone and that Homi still has the permission needed for the mode you chose. Live background updates require “Allow all the time” on Android and a visible Homi notification.',
          ]),
          _SectionContent('Can friends use People?', [
            'Yes. A trusted person can be marked as a Friend · location only. That lets people opt into location check-ins without exposing household records.',
          ]),
          _SectionContent('What if I change phones?', [
            'Cloud-backed features can follow your account. Local-only household records currently remain on the device until the broader household sync/backup layer is implemented, so do not treat the current local store as a complete cloud backup.',
          ]),
          _SectionContent('Need more help?', [
            'Homi is developed by Concept Lab. The public support address and account-deletion web resource must be finalised and published before the production store release. The developer website is available below during this pre-release stage.',
          ]),
        ],
      );

    case HomiInfoTopic.about:
      return const _InfoContent(
        title: 'About Homi',
        icon: Icons.info_outline_rounded,
        intro: 'Happy homes, easier days.',
        sections: [
          _SectionContent('Homi 0.7.0', [
            'Build 7 · Android development release.',
            'Homi is a local-first household operating system with an explicit trusted-person location layer.',
          ]),
          _SectionContent('Built by Concept Lab', [
            'Homi is developed by Concept Lab in South Africa. The product is being built around practical household clarity, restrained data collection and user-controlled sharing.',
          ]),
          _SectionContent('Product principles', [
            'Local-first where practical. Share only with intent. Do not hide location tracking. Do not paywall privacy controls. Do not turn everyday home life into unnecessary admin.',
          ]),
        ],
      );
  }
}
