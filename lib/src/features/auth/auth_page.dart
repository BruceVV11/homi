import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/google_provider_mark.dart';
import '../../widgets/homi_brand.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.authService,
    required this.onDone,
    required this.onContinueLocal,
    super.key,
  });

  final AuthService authService;
  final VoidCallback onDone;
  final VoidCallback onContinueLocal;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) widget.onDone();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyFirebaseError(error));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _emailAction() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    await _run(() async {
      if (_create) {
        await widget.authService.createWithEmail(email, password);
      } else {
        await widget.authService.signInWithEmail(email, password);
      }
    });
  }

  Future<void> _googleAction() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.authService.signInWithGoogle();
      if (result != null && mounted) widget.onDone();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyFirebaseError(error));
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(
        () => _error = 'Enter your email first, then tap reset password again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.authService.sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _error = _friendlyFirebaseError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HomiLogo(width: 220),
                  const SizedBox(height: 30),
                  Text(
                    _create ? 'Create your Homi account' : 'Welcome back',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _create
                        ? 'Use an account for shared home features, backup and trusted-person location.'
                        : 'Sign in to bring your shared Homi data back to this phone.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (!widget.authService.firebaseReady) ...[
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Cloud sign-in is temporarily unavailable. You can keep using Homi on this phone.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: _create
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    onSubmitted: (_) => _emailAction(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _error,
                    ),
                  ),
                  if (!_create)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy || !widget.authService.firebaseReady
                          ? null
                          : _emailAction,
                      child: Text(
                        _busy
                            ? 'Please wait…'
                            : (_create ? 'Create account' : 'Sign in'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || !widget.authService.firebaseReady
                          ? null
                          : _googleAction,
                      icon: const GoogleProviderMark(size: 20),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _create = !_create;
                              _error = null;
                            }),
                      child: Text(
                        _create
                            ? 'Already have an account? Sign in'
                            : 'New to Homi? Create account',
                      ),
                    ),
                  ),
                  const Divider(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _busy ? null : widget.onContinueLocal,
                      child: const Text('Continue on this phone without an account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _friendlyFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'That email or password is not correct.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'network-request-failed':
        return 'Homi could not reach the internet. Try again when you are connected.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment, then try again.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }
}
