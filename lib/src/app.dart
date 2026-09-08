import 'package:flutter/material.dart';

import 'features/auth/auth_page.dart';
import 'features/onboarding/onboarding_page.dart';
import 'services/auth_service.dart';
import 'shell/homi_shell.dart';
import 'state/homi_app_controller.dart';
import 'theme/homi_theme.dart';
import 'widgets/homi_brand.dart';

class HomiApp extends StatefulWidget {
  const HomiApp({
    required this.firebaseReady,
    this.firebaseError,
    super.key,
  });

  final bool firebaseReady;
  final Object? firebaseError;

  @override
  State<HomiApp> createState() => _HomiAppState();
}

class _HomiAppState extends State<HomiApp> {
  final HomiAppController _controller = HomiAppController();
  late final AuthService _authService;
  bool _showAuth = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(firebaseReady: widget.firebaseReady);
    _controller.addListener(_refresh);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Homi',
      debugShowCheckedModeBanner: false,
      theme: HomiTheme.light,
      home: !_controller.isReady
          ? const _HomiLoadingScreen()
          : !_controller.onboardingComplete
              ? OnboardingPage(
                  onContinueLocal: (name, type) async {
                    await _controller.completeOnboarding(name: name, type: type, useLocalOnly: true);
                  },
                  onContinueWithAccount: (name, type) async {
                    await _controller.completeOnboarding(name: name, type: type, useLocalOnly: false);
                    if (mounted) setState(() => _showAuth = true);
                  },
                )
              : _showAuth
                  ? AuthPage(
                      authService: _authService,
                      onDone: () async {
                        await _controller.setLocalOnly(false);
                        if (mounted) setState(() => _showAuth = false);
                      },
                      onContinueLocal: () async {
                        await _controller.setLocalOnly(true);
                        if (mounted) setState(() => _showAuth = false);
                      },
                    )
                  : HomiShell(
                      controller: _controller,
                      authService: _authService,
                      firebaseReady: widget.firebaseReady,
                      onOpenAuth: () => setState(() => _showAuth = true),
                    ),
    );
  }
}

class _HomiLoadingScreen extends StatelessWidget {
  const _HomiLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HomiMark(size: 110),
              SizedBox(height: 18),
              Text('Getting Homi ready…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
