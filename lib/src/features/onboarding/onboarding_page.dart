import 'package:flutter/material.dart';

import '../../domain/emergency_region.dart';
import '../../services/emergency_region_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/emergency_region_picker.dart';
import '../../widgets/homi_brand.dart';
import '../../widgets/homi_country_flag.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.onContinueLocal,
    required this.onContinueWithAccount,
    super.key,
  });

  final Future<void> Function(String homeName, String homeType) onContinueLocal;
  final Future<void> Function(String homeName, String homeType)
      onContinueWithAccount;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final TextEditingController _homeNameController =
      TextEditingController(text: 'My home');
  int _page = 0;
  String _homeType = 'House';
  EmergencyRegion? _emergencyRegion;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emergencyRegion = EmergencyRegionService.instance.current;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _homeNameController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < 3) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _chooseEmergencyRegion() async {
    final selected = await showEmergencyRegionPicker(context);
    if (selected != null && mounted) {
      setState(() => _emergencyRegion = selected);
    }
  }

  Future<void> _finish(bool localOnly) async {
    if (_busy || _emergencyRegion == null) return;
    setState(() => _busy = true);
    try {
      await EmergencyRegionService.instance.select(_emergencyRegion!);
      if (localOnly) {
        await widget.onContinueLocal(_homeNameController.text, _homeType);
      } else {
        await widget.onContinueWithAccount(
          _homeNameController.text,
          _homeType,
        );
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
                  Text(
                    '${_page + 1} / 4',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                    onTypeChanged: (value) =>
                        setState(() => _homeType = value),
                    onNext: _next,
                  ),
                  _EmergencyStep(
                    selectedRegion: _emergencyRegion,
                    onChoose: _chooseEmergencyRegion,
                    onNext: _emergencyRegion == null ? null : _next,
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
          Text(
            'A happier home starts here.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Homi keeps track of the small things around home, so you can spend less time remembering and more time living.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Get started'),
            ),
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
          Text(
            "Let's make this yours.",
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'A couple of basics help Homi keep the right things relevant.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            decoration:
                const InputDecoration(labelText: 'What should we call your home?'),
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
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmergencyStep extends StatelessWidget {
  const _EmergencyStep({
    required this.selectedRegion,
    required this.onChoose,
    required this.onNext,
  });

  final EmergencyRegion? selectedRegion;
  final VoidCallback onChoose;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final region = selectedRegion;
    final primary = region?.primaryContact;
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          Text(
            'Set your emergency region.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Homi keeps emergency numbers on this phone so the shortcuts do not depend on a data connection. Choose the country or region you want Homi to use.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(
                children: [
                  if (region == null)
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: HomiColors.peach.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.public_rounded,
                        color: HomiColors.coral,
                      ),
                    )
                  else
                    HomiCountryFlag(isoCode: region.isoCode, size: 48),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          region?.countryName ?? 'Choose a country or region',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          region == null
                              ? 'Required for the emergency call shortcuts.'
                              : primary == null
                                  ? 'Uses service-specific emergency numbers.'
                                  : 'Primary emergency number ${primary.number}.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onChoose,
              icon: const Icon(Icons.public_rounded),
              label: Text(region == null ? 'Choose region' : 'Change region'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can change this later. Homi opens the phone app with the number ready; it never silently places an emergency call or sends your location to responders.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: const Text('Continue'),
            ),
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
          Text(
            'Keep the people you trust close.',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 10),
          Text(
            'An account enables Homi connection codes, selected shared Tasks, notifications and location features. You can also start with Homi only on this phone.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 26),
          const _Benefit(
            icon: Icons.people_outline_rounded,
            text: 'Connect with people you choose',
          ),
          const _Benefit(
            icon: Icons.location_on_outlined,
            text: 'Control location sharing person by person',
          ),
          const _Benefit(
            icon: Icons.task_alt_rounded,
            text: 'Use supported shared Tasks and cloud features',
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy ? null : onAccount,
              child: Text(
                busy ? 'Getting Homi ready…' : 'Sign in or create account',
              ),
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
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
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
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          height: constraints.maxHeight > 36
              ? constraints.maxHeight - 36
              : constraints.maxHeight,
          child: child,
        ),
      ),
    );
  }
}
