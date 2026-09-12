import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../domain/homi_household.dart';
import '../../services/household_service.dart';
import '../../services/trusted_people_service.dart';
import '../../state/homi_app_controller.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';

class HouseholdSettingsPage extends StatefulWidget {
  const HouseholdSettingsPage({
    required this.householdService,
    required this.trustedPeopleService,
    required this.controller,
    required this.onSignIn,
    super.key,
  });

  final HouseholdService householdService;
  final TrustedPeopleService trustedPeopleService;
  final HomiAppController controller;
  final VoidCallback onSignIn;

  @override
  State<HouseholdSettingsPage> createState() => _HouseholdSettingsPageState();
}

class _HouseholdSettingsPageState extends State<HouseholdSettingsPage> {
  bool _busy = false;
  String? _message;

  User? get _user => widget.householdService.currentUser;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _message = _friendly(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');

  Future<String?> _nameSheet({
    required String title,
    required String initialValue,
    required String buttonLabel,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _HouseholdNameSheet(
        title: title,
        initialValue: initialValue,
        buttonLabel: buttonLabel,
      ),
    );
  }

  Future<void> _createHousehold() async {
    final name = await _nameSheet(
      title: 'Create your Household',
      initialValue: widget.controller.homeName,
      buttonLabel: 'Create Household',
    );
    if (name == null) return;
    await _run(() async {
      await widget.householdService.createHousehold(name);
    });
  }

  Future<void> _renameHousehold(HomiHousehold household) async {
    final name = await _nameSheet(
      title: 'Rename Household',
      initialValue: household.name,
      buttonLabel: 'Save name',
    );
    if (name == null || name.trim() == household.name) return;
    await _run(() => widget.householdService.renameHousehold(name));
  }

  Future<void> _inviteMember(HomiHousehold household) async {
    List<TrustedConnection> connections;
    try {
      connections = await widget.trustedPeopleService.getConnections();
    } catch (error) {
      if (!mounted) return;
      await showHomiInfoSheet(
        context,
        title: 'Could not load your connections',
        message:
            '${_friendly(error)} Your Household has not been changed. Try again when your connection is stable.',
        actionLabel: 'Okay',
        icon: Icons.cloud_off_outlined,
      );
      return;
    }
    final currentUid = _user?.uid;
    if (currentUid == null || !mounted) return;

    final candidates = connections.where((connection) {
      if (!connection.accepted) return false;
      final uid = connection.otherUid(currentUid);
      return !household.memberUids.contains(uid) &&
          !household.pendingInviteUids.contains(uid);
    }).toList(growable: false);

    if (candidates.isEmpty) {
      if (_message != null) setState(() => _message = null);
      final hasReservedInvite = household.pendingInviteUids.isNotEmpty;
      await showHomiInfoSheet(
        context,
        title: household.full ? 'Your Household is full' : 'No one else to add yet',
        message: household.full
            ? 'All four Household seats are already occupied or reserved by pending invitations.'
            : hasReservedInvite
                ? 'Everyone you can currently add is already in your Household or has a pending invitation. Connect with another person in People, then come back here to invite them.'
                : 'Connect with another person in People first. Once that trusted connection is accepted, come back here to invite them to your Household.',
        actionLabel: 'Got it',
        icon: household.full
            ? Icons.groups_outlined
            : Icons.person_add_disabled_outlined,
      );
      return;
    }

    final selected = await showModalBottomSheet<TrustedConnection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _InviteMemberSheet(
        candidates: candidates,
        currentUid: currentUid,
      ),
    );
    if (selected == null) return;
    await _run(() => widget.householdService
        .inviteMember(selected.otherUid(currentUid)));
  }

  Future<void> _manageMember(
    HomiHousehold household,
    HomiHouseholdMember member,
  ) async {
    final action = await showModalBottomSheet<_MemberAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.displayName,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                'Manage this Household membership. Their trusted People connection is kept unless either person removes it separately.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _MemberAction.transferOwnership,
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Make Household owner'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    _MemberAction.remove,
                  ),
                  icon: const Icon(Icons.person_remove_outlined),
                  label: const Text('Remove from Household'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == _MemberAction.transferOwnership) {
      final confirmed = await showHomiConfirmSheet(
        context,
        title: 'Make ${member.displayName} the owner?',
        message:
            'They will manage Household membership and invitations. You will remain a member.',
        confirmLabel: 'Transfer ownership',
        cancelLabel: 'Keep ownership',
        icon: Icons.admin_panel_settings_outlined,
      );
      if (confirmed) {
        await _run(() => widget.householdService.transferOwnership(member.uid));
      }
      return;
    }

    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Remove ${member.displayName} from ${household.name}?',
      message:
          'They will no longer be a member of this shared Household. Their normal trusted connection is not removed.',
      confirmLabel: 'Remove member',
      cancelLabel: 'Keep member',
      icon: Icons.person_remove_outlined,
      destructive: true,
    );
    if (confirmed) {
      await _run(() => widget.householdService.removeMember(member.uid));
    }
  }

  Future<void> _leaveHousehold(HomiHousehold household) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Leave ${household.name}?',
      message:
          'You will stop being a member of this shared Household. Your normal trusted People connections stay in place.',
      confirmLabel: 'Leave Household',
      cancelLabel: 'Stay',
      icon: Icons.logout_rounded,
      destructive: true,
    );
    if (confirmed) {
      await _run(widget.householdService.leaveHousehold);
    }
  }

  Future<void> _deleteHousehold(HomiHousehold household) async {
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Delete ${household.name}?',
      message:
          'This removes the shared Household identity and any pending invitations. Your personal Homi data and trusted People connections stay in place.',
      confirmLabel: 'Delete Household',
      cancelLabel: 'Keep Household',
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (confirmed) {
      await _run(widget.householdService.deleteHousehold);
    }
  }

  Future<void> _respondInvite(
    HomiHouseholdInvite invite, {
    required bool accept,
  }) async {
    if (accept) {
      final confirmed = await showHomiConfirmSheet(
        context,
        title: 'Join ${invite.householdName}?',
        message:
            '${invite.inviterName} invited you to join this Homi Household. One Homi account can belong to one shared Household at a time.',
        confirmLabel: 'Join Household',
        cancelLabel: 'Not now',
        icon: Icons.home_work_outlined,
      );
      if (!confirmed) return;
    }
    await _run(() => widget.householdService.respondToInvite(
          invite.id,
          accept: accept,
        ));
  }

  Future<void> _cancelInvite(HomiHouseholdInvite invite) async {
    await _run(() => widget.householdService.cancelInvite(invite.id));
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Household'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: user == null
            ? _SignedOutHousehold(onSignIn: widget.onSignIn)
            : StreamBuilder<HomiHousehold?>(
                stream: widget.householdService.watchCurrentHousehold(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const _LoadError(
                      message:
                          'Homi could not refresh your Household. Check your connection and try again.',
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final household = snapshot.data;
                  return household == null
                      ? _buildNoHousehold(context)
                      : _buildHousehold(context, household, user.uid);
                },
              ),
      ),
    );
  }

  Widget _buildNoHousehold(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
      children: [
        const _HouseholdIntroCard(
          title: 'One home, one Household',
          text:
              'Create a Household when you want Homi to know which trusted people belong to the same home. Each account can belong to one Household at a time.',
          icon: Icons.home_work_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _busy ? null : _createHousehold,
          icon: const Icon(Icons.add_home_work_outlined),
          label: const Text('Create Household'),
        ),
        const SizedBox(height: 22),
        Text('Invitations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        StreamBuilder<List<HomiHouseholdInvite>>(
          stream: widget.householdService.watchIncomingInvites(),
          builder: (context, snapshot) {
            final invites = snapshot.data ?? const <HomiHouseholdInvite>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (invites.isEmpty) {
              return const _EmptyCard(
                icon: Icons.mark_email_read_outlined,
                text: 'No Household invitations right now.',
              );
            }
            return Column(
              children: invites
                  .map((invite) => _IncomingInviteCard(
                        invite: invite,
                        busy: _busy,
                        onAccept: () => _respondInvite(invite, accept: true),
                        onDecline: () => _respondInvite(invite, accept: false),
                      ))
                  .toList(growable: false),
            );
          },
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(text: _message!),
        ],
      ],
    );
  }

  Widget _buildHousehold(
    BuildContext context,
    HomiHousehold household,
    String currentUid,
  ) {
    final isOwner = household.isOwner(currentUid);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 34),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.home_work_rounded,
                        color: HomiColors.coral,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            household.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${household.memberUids.length} of ${household.memberLimit} members · ${isOwner ? 'You are the owner' : 'You are a member'}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        onPressed:
                            _busy ? null : () => _renameHousehold(household),
                        tooltip: 'Rename Household',
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                if (household.pendingInviteUids.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${household.pendingInviteUids.length} seat${household.pendingInviteUids.length == 1 ? '' : 's'} reserved by pending invitation${household.pendingInviteUids.length == 1 ? '' : 's'}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                'Members',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (isOwner)
              TextButton.icon(
                onPressed: _busy || household.full
                    ? null
                    : () => _inviteMember(household),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Add person'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<HomiHouseholdMember>>(
          stream: widget.householdService.watchMembers(household.id),
          builder: (context, snapshot) {
            final members = snapshot.data ?? const <HomiHouseholdMember>[];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Column(
              children: members
                  .map((member) => _MemberCard(
                        member: member,
                        isCurrentUser: member.uid == currentUid,
                        canManage: isOwner && member.uid != currentUid,
                        onManage: () => _manageMember(household, member),
                      ))
                  .toList(growable: false),
            );
          },
        ),
        if (isOwner) ...[
          const SizedBox(height: 18),
          Text(
            'Pending invitations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<HomiHouseholdInvite>>(
            stream: widget.householdService.watchOutgoingInvites(),
            builder: (context, snapshot) {
              final invites = (snapshot.data ?? const <HomiHouseholdInvite>[])
                  .where((invite) => invite.householdId == household.id)
                  .toList(growable: false);
              if (invites.isEmpty) {
                return const _EmptyCard(
                  icon: Icons.outgoing_mail,
                  text: 'No pending Household invitations.',
                );
              }
              return Column(
                children: invites
                    .map((invite) => _OutgoingInviteCard(
                          invite: invite,
                          busy: _busy,
                          onCancel: () => _cancelInvite(invite),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ],
        if (_message != null) ...[
          const SizedBox(height: 12),
          _InlineMessage(text: _message!),
        ],
        const SizedBox(height: 24),
        if (!isOwner)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _leaveHousehold(household),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Leave Household'),
          )
        else if (household.memberUids.length == 1)
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _deleteHousehold(household),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete Household'),
          )
        else
          Text(
            'To leave as owner, first transfer ownership to another member.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (_busy) ...[
          const SizedBox(height: 14),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }
}

enum _MemberAction { transferOwnership, remove }

class _HouseholdNameSheet extends StatefulWidget {
  const _HouseholdNameSheet({
    required this.title,
    required this.initialValue,
    required this.buttonLabel,
  });

  final String title;
  final String initialValue;
  final String buttonLabel;

  @override
  State<_HouseholdNameSheet> createState() => _HouseholdNameSheetState();
}

class _HouseholdNameSheetState extends State<_HouseholdNameSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Use a name everyone in this Household will recognise.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 60,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(labelText: 'Household name'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(widget.buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.pop(context, value);
  }
}

class _InviteMemberSheet extends StatelessWidget {
  const _InviteMemberSheet({
    required this.candidates,
    required this.currentUid,
  });

  final List<TrustedConnection> candidates;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add to Household',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose an existing trusted Homi connection. They decide whether to accept the Household invitation.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final connection = candidates[index];
                  return ListTile(
                    onTap: () => Navigator.pop(context, connection),
                    leading: _PersonAvatar(
                      name: connection.otherName(currentUid),
                      photoUrl: connection.otherPhotoUrl(currentUid),
                    ),
                    title: Text(
                      connection.otherName(currentUid),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    subtitle: const Text('Trusted Homi connection'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: HomiColors.sage.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: HomiColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      size: 19,
                      color: HomiColors.muted,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Household membership does not turn on location sharing. Each person keeps location sharing as a separate opt-in choice.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HouseholdIntroCard extends StatelessWidget {
  const _HouseholdIntroCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  final String title;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: HomiColors.peach.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: HomiColors.coral),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(text, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingInviteCard extends StatelessWidget {
  const _IncomingInviteCard({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final HomiHouseholdInvite invite;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invite.householdName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              '${invite.inviterName} invited you to join.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onAccept,
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingInviteCard extends StatelessWidget {
  const _OutgoingInviteCard({
    required this.invite,
    required this.busy,
    required this.onCancel,
  });

  final HomiHouseholdInvite invite;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _PersonAvatar(
          name: invite.inviteeName,
          photoUrl: invite.inviteePhotoUrl,
        ),
        title: Text(
          invite.inviteeName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text('Invitation pending'),
        trailing: TextButton(
          onPressed: busy ? null : onCancel,
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isCurrentUser,
    required this.canManage,
    required this.onManage,
  });

  final HomiHouseholdMember member;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _PersonAvatar(
          name: member.displayName,
          photoUrl: member.photoUrl,
        ),
        title: Text(
          isCurrentUser ? '${member.displayName} · You' : member.displayName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(member.role.label),
        trailing: canManage
            ? TextButton(onPressed: onManage, child: const Text('Manage'))
            : member.role == HomiHouseholdRole.owner
                ? const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: HomiColors.coral,
                  )
                : null,
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
    final photo = photoUrl?.trim();
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.28),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo == null || photo.isEmpty
          ? Text(
              initial,
              style: const TextStyle(fontWeight: FontWeight.w900),
            )
          : Image.network(
              photo,
              fit: BoxFit.cover,
              width: 44,
              height: 44,
              errorBuilder: (_, __, ___) => Text(
                initial,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
    );
  }
}

class _SignedOutHousehold extends StatelessWidget {
  const _SignedOutHousehold({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
      children: [
        const _HouseholdIntroCard(
          title: 'A shared Household needs an account',
          text:
              'Sign in to create or join a Household. Homi still keeps personal household tools available on this phone without an account.',
          icon: Icons.cloud_outlined,
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onSignIn,
          icon: const Icon(Icons.login_rounded),
          label: const Text('Sign in'),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: HomiColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiColors.border),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
