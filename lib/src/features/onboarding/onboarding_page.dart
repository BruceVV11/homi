import 'package:flutter/material.dart';

import '../../theme/homi_theme.dart';
import '../../widgets/homi_brand.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.onContinueLocal,
    required this.onContinueWithAccount,
    super.key,
  });

  final Future<void> Function(String homeName, String homeType) onContinueLocal;
  final Future<void> Function(String homeName, String homeType) onContinueWithAccount;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _homeNameController = TextEditingController(text: 'My home');
  int _page = 0;
  String _homeType = 'House';
  bool _busy = false;

  @override
  void dispose() {
    _pageController.dispose();
    _homeNameController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 2) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish(bool localOnly) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (localOnly) {
        await widget.onContinueLocal(_homeNameController.text, _homeType);
      } else {
        await widget.onContinueWithAccount(_homeNameController.text, _homeType);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Row(
                children: [
                  const HomiMark(size: 42),
                  const Spacer(),
                  Text('${_page + 1} / 3', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (value) => setState(() => _page = value),
                children: [
                  _WelcomeStep(onNext: _next),
                  _HomeStep(
                    controller: _homeNameController,
                    selectedType: _homeType,
                    onTypeChanged: (value) => setState(() => _homeType = value),
                    onNext: _next,
                  ),
                  _AccountStep(
                    busy: _busy,
                    onLocal: () => _finish(true),
                    onAccount: () => _finish(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const HomiLogo(width: 250),
          const SizedBox(height: 28),
          Text('A happier home starts here.', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 12),
          Text(
            'Homi keeps track of the small things around home, so you can spend less time remembering and more time living.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onNext, child: const Text('Get started')),
          ),
        ],
      ),
    );
  }
}

class _HomeStep extends StatelessWidget {
  const _HomeStep({
    required this.controller,
    required this.selectedType,
    required this.onTypeChanged,
    required this.onNext,
  });

  final TextEditingController controller;
  final String selectedType;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    const types = ['House', 'Apartment', 'Townhouse', 'Other'];
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          Text("Let's make this yours.", style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text('A couple of basics help Homi keep the right things relevant.', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'What should we call your home?'),
          ),
          const SizedBox(height: 22),
          Text('Home type', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final selected = selectedType == type;
              return ChoiceChip(
                label: Text(type),
                selected: selected,
                onSelected: (_) => onTypeChanged(type),
                selectedColor: HomiColors.peach.withValues(alpha: 0.34),
                side: const BorderSide(color: HomiColors.border),
              );
            }).toList(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onNext, child: const Text('Continue')),
          ),
        ],
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.busy,
    required this.onLocal,
    required this.onAccount,
  });

  final bool busy;
  final VoidCallback onLocal;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          Text('Keep home life together.', style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 10),
          Text(
            'An account lets Homi sync shared routines, trusted people and backup across devices. You can also start on this phone without an account.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          _Benefit(icon: Icons.sync_rounded, text: 'Sync changes across your devices'),
          _Benefit(icon: Icons.people_outline_rounded, text: 'Share routines and location only with people you choose'),
          _Benefit(icon: Icons.cloud_outlined, text: 'Restore your home setup when you change phones'),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onAccount,
              child: Text(busy ? 'Getting Homi ready…' : 'Sign in or create account'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : onLocal,
              child: const Text('Use Homi on this phone'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: HomiColors.sage.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  const _StepShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.viewPaddingOf(context).bottom),
        child: SizedBox(
          height: constraints.maxHeight > 36 ? constraints.maxHeight - 36 : constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
