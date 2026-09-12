import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/homi_billing_catalog.dart';
import '../../domain/homi_entitlement.dart';
import '../../domain/homi_plus_plan.dart';
import '../../services/homi_billing_service.dart';
import '../../services/homi_entitlement_service.dart';
import '../../services/homi_plus_management_service.dart';
import '../../services/trusted_people_service.dart';
import '../../theme/homi_theme.dart';
import '../../widgets/homi_controls.dart';

class HomiPlusPage extends StatefulWidget {
  const HomiPlusPage({super.key});

  @override
  State<HomiPlusPage> createState() => _HomiPlusPageState();
}

class _HomiPlusPageState extends State<HomiPlusPage> {
  late final bool _firebaseReady;
  late final HomiEntitlementService _entitlementService;
  late final HomiBillingService _billingService;
  late final HomiPlusManagementService _managementService;
  late final TrustedPeopleService _trustedPeopleService;
  StreamSubscription<HomiBillingNotice>? _billingNoticeSubscription;

  HomiBillingCatalogSnapshot? _catalog;
  List<TrustedConnection> _connections = const <TrustedConnection>[];
  bool _loadingCatalog = true;
  bool _busy = false;

  User? get _user =>
      _firebaseReady ? FirebaseAuth.instance.currentUser : null;

  @override
  void initState() {
    super.initState();
    _firebaseReady = Firebase.apps.isNotEmpty;
    _entitlementService = HomiEntitlementService(
      firebaseReady: _firebaseReady,
    );
    _billingService = HomiBillingService(
      firebaseReady: _firebaseReady,
      catalog: HomiPlayBillingCatalog.current,
    )..start();
    _managementService = HomiPlusManagementService(
      firebaseReady: _firebaseReady,
    );
    _trustedPeopleService = TrustedPeopleService(
      firebaseReady: _firebaseReady,
    );
    _billingNoticeSubscription = _billingService.notices.listen(_showNotice);
    unawaited(_load());
  }

  @override
  void dispose() {
    _billingNoticeSubscription?.cancel();
    unawaited(_billingService.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    HomiBillingCatalogSnapshot? catalog;
    List<TrustedConnection> connections = const <TrustedConnection>[];
    try {
      catalog = await _billingService.loadCatalog();
    } catch (_) {
      catalog = const HomiBillingCatalogSnapshot(
        storeAvailable: false,
        catalogConfigured: true,
        offers: <HomiStoreOffer>[],
        message: 'Google Play billing could not be loaded on this device.',
      );
    }
    try {
      connections = (await _trustedPeopleService.getConnections())
          .where((connection) => connection.accepted)
          .toList(growable: false);
    } catch (_) {
      connections = const <TrustedConnection>[];
    }
    if (!mounted) return;
    setState(() {
      _catalog = catalog;
      _connections = connections;
      _loadingCatalog = false;
    });
  }

  Future<void> _showNotice(HomiBillingNotice notice) async {
    if (!mounted) return;
    final icon = switch (notice.type) {
      HomiBillingNoticeType.verified || HomiBillingNoticeType.restored =>
        Icons.check_circle_outline_rounded,
      HomiBillingNoticeType.pending => Icons.hourglass_top_rounded,
      HomiBillingNoticeType.canceled => Icons.info_outline_rounded,
      HomiBillingNoticeType.error => Icons.error_outline_rounded,
    };
    await showHomiInfoSheet(
      context,
      title: switch (notice.type) {
        HomiBillingNoticeType.verified => 'Homi+ verified',
        HomiBillingNoticeType.restored => 'Homi+ restored',
        HomiBillingNoticeType.pending => 'Purchase pending',
        HomiBillingNoticeType.canceled => 'Purchase canceled',
        HomiBillingNoticeType.error => 'Homi+ could not update',
      },
      message: notice.message,
      actionLabel: 'Okay',
      icon: icon,
    );
  }

  Future<void> _purchase(
    HomiPlusPlanDefinition definition,
    HomiBillingCadence cadence,
  ) async {
    if (_busy) return;
    final catalog = _catalog;
    final offer = catalog?.offerFor(definition.plan, cadence);
    if (offer == null) {
      await showHomiInfoSheet(
        context,
        title: 'This plan is not available yet',
        message:
            'Homi could not find the matching Google Play subscription offer. No purchase was started.',
        actionLabel: 'Okay',
        icon: Icons.shopping_bag_outlined,
      );
      return;
    }
    final cadenceLabel = cadence == HomiBillingCadence.annual
        ? 'year'
        : 'month';
    final confirmed = await showHomiConfirmSheet(
      context,
      title: 'Choose ${definition.name}?',
      message:
          '${offer.displayPrice} per $cadenceLabel through Google Play. Google Play shows the final billing terms before you confirm.',
      confirmLabel: 'Continue to Google Play',
      cancelLabel: 'Not now',
      icon: Icons.workspace_premium_outlined,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      final launched = await _billingService.purchase(offer);
      if (!launched && mounted) {
        await showHomiInfoSheet(
          context,
          title: 'Google Play did not open',
          message: 'No purchase was made. Try again in a moment.',
          actionLabel: 'Okay',
          icon: Icons.error_outline_rounded,
        );
      }
    } catch (error) {
      if (mounted) {
        await showHomiInfoSheet(
          context,
          title: 'Could not start purchase',
          message: _friendly(error),
          actionLabel: 'Okay',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _billingService.restorePurchases();
    } catch (error) {
      if (mounted) {
        await showHomiInfoSheet(
          context,
          title: 'Could not restore purchases',
          message: _friendly(error),
          actionLabel: 'Okay',
          icon: Icons.restore_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _manageInPlay(HomiEntitlement entitlement) async {
    final product = HomiPlayBillingCatalog.current.forPlan(entitlement.plan);
    final productId = product?.productId.trim() ?? '';
    final parameters = <String, String>{
      'package': 'za.co.theconceptlab.homi',
      if (productId.isNotEmpty) 'sku': productId,
    };
    final uri = Uri.https(
      'play.google.com',
      '/store/account/subscriptions',
      parameters,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      await showHomiInfoSheet(
        context,
        title: 'Could not open Google Play',
        message:
            'Open Google Play → Payments & subscriptions → Subscriptions to manage Homi+.',
        actionLabel: 'Okay',
        icon: Icons.open_in_new_rounded,
      );
    }
  }

  Future<void> _manageDuoSeat(HomiEntitlement entitlement) async {
    final user = _user;
    if (user == null || entitlement.purchaserUid != user.uid) return;
    final candidates = _connections
        .where((connection) => connection.otherUid(user.uid) != user.uid)
        .toList(growable: false);
    if (candidates.isEmpty) {
      await showHomiInfoSheet(
        context,
        title: 'Connect with someone first',
        message:
            'The second Homi+ Duo seat can be assigned to one accepted trusted Homi connection. Add a connection in People, then come back here.',
        actionLabel: 'Got it',
        icon: Icons.people_outline_rounded,
      );
      return;
    }

    final selectedUid = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Second Duo seat',
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Choose one accepted Homi connection. Reassigning a Duo seat is limited by the seven-day seat cooldown.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              ...candidates.map((connection) {
                final uid = connection.otherUid(user.uid);
                final selected = entitlement.duoSeatAssigneeUid == uid;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: HomiColors.peach.withValues(alpha: 0.25),
                      child: Text(connection.otherName(user.uid)[0].toUpperCase()),
                    ),
                    title: Text(connection.otherName(user.uid)),
                    subtitle: Text(selected ? 'Current second seat' : 'Trusted connection'),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded,
                            color: HomiColors.coral)
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(sheetContext, uid),
                  ),
                );
              }),
              if (entitlement.duoSeatAssigneeUid != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, ''),
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                    label: const Text('Unassign second seat'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selectedUid == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await _managementService.setDuoSeat(
        selectedUid.isEmpty ? null : selectedUid,
      );
      if (!mounted) return;
      final next = result.canReassignAt;
      await showHomiInfoSheet(
        context,
        title: result.assigned ? 'Duo seat assigned' : 'Duo seat unassigned',
        message: result.assigned
            ? next == null
                ? 'The second sender seat is now active.'
                : 'The second sender seat is now active. The next reassignment is available after ${_date(next)}.'
            : next == null
                ? 'The second seat is currently unassigned.'
                : 'The second seat is unassigned. The existing reassignment cooldown remains in place until ${_date(next)}.',
        actionLabel: 'Okay',
        icon: Icons.people_alt_outlined,
      );
    } catch (error) {
      if (mounted) {
        await showHomiInfoSheet(
          context,
          title: 'Duo seat was not changed',
          message: _friendly(error),
          actionLabel: 'Okay',
          icon: Icons.error_outline_rounded,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiColors.cream,
      appBar: AppBar(
        title: const Text('Homi+'),
        backgroundColor: HomiColors.cream,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<HomiEntitlement>(
          stream: _entitlementService.watchCurrent(),
          initialData: HomiEntitlement.free,
          builder: (context, snapshot) {
            final entitlement = snapshot.data ?? HomiEntitlement.free;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              children: [
                _CurrentPlanCard(
                  entitlement: entitlement,
                  onManage: entitlement.plan == HomiPlusPlan.free
                      ? null
                      : () => _manageInPlay(entitlement),
                  onManageDuo: entitlement.plan == HomiPlusPlan.duo &&
                          entitlement.purchaserUid == _user?.uid
                      ? () => _manageDuoSeat(entitlement)
                      : null,
                ),
                const SizedBox(height: 20),
                Text('Choose Homi+', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (_loadingCatalog)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_catalog?.catalogConfigured != true)
                  const _BillingSetupCard()
                else ...[
                  if (_catalog?.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SmallNotice(text: _catalog!.message!),
                    ),
                  ...HomiPlusPlans.all
                      .where((definition) => definition.isPaid)
                      .map((definition) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PlanCard(
                              definition: definition,
                              monthlyOffer: _catalog?.offerFor(
                                definition.plan,
                                HomiBillingCadence.monthly,
                              ),
                              annualOffer: _catalog?.offerFor(
                                definition.plan,
                                HomiBillingCadence.annual,
                              ),
                              busy: _busy,
                              onMonthly: () => _purchase(
                                definition,
                                HomiBillingCadence.monthly,
                              ),
                              onAnnual: definition.annualPriceCents == null
                                  ? null
                                  : () => _purchase(
                                        definition,
                                        HomiBillingCadence.annual,
                                      ),
                            ),
                          )),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy || _catalog?.catalogConfigured != true
                        ? null
                        : _restore,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Restore Google Play purchases'),
                  ),
                ),
                const SizedBox(height: 18),
                const _PrivacyBillingCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  String _friendly(Object error) => error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('StateError: ', '')
      .replaceFirst('Exception: ', '');

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({
    required this.entitlement,
    required this.onManage,
    required this.onManageDuo,
  });

  final HomiEntitlement entitlement;
  final VoidCallback? onManage;
  final VoidCallback? onManageDuo;

  @override
  Widget build(BuildContext context) {
    final definition = HomiPlusPlans.forPlan(entitlement.plan);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(Icons.workspace_premium_outlined,
                      color: HomiColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(definition.name,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text(
                        _stateLabel(entitlement.state),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(definition.summary,
                style: Theme.of(context).textTheme.bodyMedium),
            if (onManageDuo != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onManageDuo,
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('Manage second Duo seat'),
                ),
              ),
            ],
            if (onManage != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onManage,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Manage subscription in Google Play'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _stateLabel(HomiBillingState state) => switch (state) {
        HomiBillingState.active => 'Active subscription',
        HomiBillingState.gracePeriod => 'Payment issue · grace period',
        HomiBillingState.onHold => 'Subscription on hold',
        HomiBillingState.paused => 'Subscription paused',
        HomiBillingState.canceled => 'Canceled · access follows Google Play term',
        HomiBillingState.expired => 'Subscription expired',
        HomiBillingState.pending => 'Purchase pending',
        HomiBillingState.free => 'Free plan',
        HomiBillingState.unknown => 'Free plan',
      };
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.definition,
    required this.monthlyOffer,
    required this.annualOffer,
    required this.busy,
    required this.onMonthly,
    required this.onAnnual,
  });

  final HomiPlusPlanDefinition definition;
  final HomiStoreOffer? monthlyOffer;
  final HomiStoreOffer? annualOffer;
  final bool busy;
  final VoidCallback onMonthly;
  final VoidCallback? onAnnual;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(definition.name,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            Text(definition.summary,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy || monthlyOffer == null ? null : onMonthly,
                child: Text(
                  monthlyOffer == null
                      ? 'Monthly offer unavailable'
                      : '${monthlyOffer!.displayPrice} / month',
                ),
              ),
            ),
            if (onAnnual != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: busy || annualOffer == null ? null : onAnnual,
                  child: Text(
                    annualOffer == null
                        ? 'Annual offer unavailable'
                        : '${annualOffer!.displayPrice} / year',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BillingSetupCard extends StatelessWidget {
  const _BillingSetupCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.build_circle_outlined, color: HomiColors.coral),
                SizedBox(width: 9),
                Text('Google Play setup pending',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This development build has the secure Homi+ purchase and entitlement architecture, but the permanent Google Play subscription products have not been connected yet. Purchases stay disabled until those exact store IDs are verified.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBillingCard extends StatelessWidget {
  const _PrivacyBillingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: HomiColors.sage.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.privacy_tip_outlined, color: HomiColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Privacy exits stay free. Homi+ never blocks stopping location sharing, revoking access, leaving a Household where allowed, erasing this phone or deleting your Homi account. Deleting Homi does not cancel a Google Play subscription; subscriptions are managed separately in Google Play.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallNotice extends StatelessWidget {
  const _SmallNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiColors.peach.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
