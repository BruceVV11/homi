import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/google_provider_mark.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    required this.authService,
    super.key,
  });

  final AuthService authService;

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late final TextEditingController _nameController;
  User? _user;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user = widget.authService.currentUser;
    _nameController = TextEditingController(text: _displayName(_user));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'Homi user';
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final user = await widget.authService.updateDisplayName(name);
      if (!mounted) return;
      setState(() => _user = user);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name updated.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Could not update your name.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendVerification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.authService.sendCurrentUserVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Open it, then refresh your status here.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not send the verification email.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refreshVerification() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final user = await widget.authService.reloadCurrentUser();
      if (!mounted) return;
      setState(() {
        _user = user;
        if (_nameController.text.trim().isEmpty) {
          _nameController.text = _displayName(user);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _user?.email;
    if (email == null || email.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Could not send the password reset email.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile settings')),
        body: const SafeArea(
          child: Center(child: Text('Sign in to manage your Homi profile.')),
        ),
      );
    }

    final google = widget.authService.signedInWithGoogle(user);
    final password = widget.authService.signedInWithPassword(user);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile settings'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    _AccountAvatar(user: user, size: 58),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _displayName(user),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (google) ...[
                                const SizedBox(width: 8),
                                const GoogleProviderMark(size: 18),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email ?? 'Signed in',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 5),
                          _VerificationStatus(verified: user.emailVerified),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('Profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveName(),
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'How should Homi address you?',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _saveName,
                child: Text(_busy ? 'Please wait…' : 'Save name'),
              ),
            ),
            const SizedBox(height: 22),
            Text('Account', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _AccountDetailRow(
                      icon: Icons.alternate_email_rounded,
                      label: 'Email',
                      value: user.email ?? 'Not available',
                    ),
                    const Divider(height: 24),
                    _AccountDetailRow(
                      icon: google
                          ? Icons.account_circle_outlined
                          : Icons.lock_outline_rounded,
                      label: 'Sign-in method',
                      value: google ? 'Google' : 'Email and password',
                      trailing: google
                          ? const GoogleProviderMark(size: 18)
                          : null,
                    ),
                    const Divider(height: 24),
                    _AccountDetailRow(
                      icon: user.emailVerified
                          ? Icons.verified_rounded
                          : Icons.mark_email_unread_outlined,
                      label: 'Email status',
                      value: user.emailVerified ? 'Verified' : 'Not verified',
                      valueColor: user.emailVerified
                          ? const Color(0xFF6F8B65)
                          : HomiColors.coral,
                    ),
                  ],
                ),
              ),
            ),
            if (!user.emailVerified && password) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _sendVerification,
                  icon: const Icon(Icons.outgoing_mail),
                  label: const Text('Send verification email'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _busy ? null : _refreshVerification,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh verification status'),
                ),
              ),
            ],
            if (password) ...[
              const SizedBox(height: 22),
              Text(
                'Password & security',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: const Icon(Icons.password_rounded),
                  title: const Text(
                    'Reset password',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text(
                    'Homi will email you a secure password reset link.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _sendPasswordReset,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountDetailRow extends StatelessWidget {
  const _AccountDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 21, color: HomiColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? HomiColors.slate,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? const Color(0xFF6F8B65) : HomiColors.coral;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.info_outline_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 5),
        Text(
          verified ? 'Verified email' : 'Email not verified',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.user, required this.size});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoURL;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.34),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl.isEmpty
          ? Icon(Icons.person_rounded, size: size * 0.52)
          : Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.person_rounded,
                size: size * 0.52,
              ),
            ),
    );
  }
}
