import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../domain/homi_billing_catalog.dart';
import '../domain/homi_plus_plan.dart';
import 'homi_cloud_actions.dart';

class HomiStoreOffer {
  const HomiStoreOffer({
    required this.plan,
    required this.cadence,
    required this.productDetails,
    required this.basePlanId,
    required this.displayPrice,
    required this.offerToken,
  });

  final HomiPlusPlan plan;
  final HomiBillingCadence cadence;
  final ProductDetails productDetails;
  final String basePlanId;
  final String displayPrice;
  final String? offerToken;
}

class HomiBillingCatalogSnapshot {
  const HomiBillingCatalogSnapshot({
    required this.storeAvailable,
    required this.catalogConfigured,
    required this.offers,
    this.message,
  });

  final bool storeAvailable;
  final bool catalogConfigured;
  final List<HomiStoreOffer> offers;
  final String? message;

  HomiStoreOffer? offerFor(HomiPlusPlan plan, HomiBillingCadence cadence) {
    for (final offer in offers) {
      if (offer.plan == plan && offer.cadence == cadence) return offer;
    }
    return null;
  }
}

enum HomiBillingNoticeType {
  pending,
  verified,
  restored,
  canceled,
  error,
}

class HomiBillingNotice {
  const HomiBillingNotice({
    required this.type,
    required this.message,
    this.productId,
  });

  final HomiBillingNoticeType type;
  final String message;
  final String? productId;
}

/// Google Play purchase boundary for Homi+.
///
/// A local purchase callback never grants Homi+ access. Purchased/restored
/// tokens are sent to the App-Check-protected backend. That backend verifies
/// Google Play, writes entitlement state and acknowledges a new subscription
/// when Play says acknowledgement is pending. Flutter consumes paid capability
/// exclusively from the server-written entitlement document.
class HomiBillingService {
  HomiBillingService({
    required this.firebaseReady,
    required this.catalog,
    InAppPurchase? inAppPurchase,
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _cloudActions = HomiCloudActions(firebaseReady: firebaseReady);

  final bool firebaseReady;
  final HomiPlayBillingCatalog catalog;
  final InAppPurchase _inAppPurchase;
  final HomiCloudActions _cloudActions;
  final StreamController<HomiBillingNotice> _noticeController =
      StreamController<HomiBillingNotice>.broadcast();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  HomiBillingCatalogSnapshot? _lastCatalog;
  bool _started = false;

  Stream<HomiBillingNotice> get notices => _noticeController.stream;
  HomiBillingCatalogSnapshot? get lastCatalog => _lastCatalog;

  User? get _user =>
      firebaseReady ? FirebaseAuth.instance.currentUser : null;

  void start() {
    if (_started) return;
    _started = true;
    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      (purchases) => unawaited(_handlePurchases(purchases)),
      onError: (Object error) {
        _emit(
          HomiBillingNoticeType.error,
          'Google Play billing could not refresh. Try again.',
        );
      },
    );
  }

  Future<HomiBillingCatalogSnapshot> loadCatalog() async {
    if (!catalog.configured) {
      return _lastCatalog = const HomiBillingCatalogSnapshot(
        storeAvailable: false,
        catalogConfigured: false,
        offers: <HomiStoreOffer>[],
        message: 'Homi+ products have not been connected to Google Play yet.',
      );
    }

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      return _lastCatalog = const HomiBillingCatalogSnapshot(
        storeAvailable: false,
        catalogConfigured: true,
        offers: <HomiStoreOffer>[],
        message: 'Google Play billing is not available on this device.',
      );
    }

    final response = await _inAppPurchase.queryProductDetails(catalog.productIds);
    if (response.error != null) {
      return _lastCatalog = HomiBillingCatalogSnapshot(
        storeAvailable: true,
        catalogConfigured: true,
        offers: const <HomiStoreOffer>[],
        message: response.error!.message,
      );
    }

    final offers = <HomiStoreOffer>[];
    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;
      final basePlanId = _basePlanId(details);
      if (basePlanId == null) continue;

      // Homi may deliberately use one Google Play subscription product with
      // separate base plans for Personal, Duo and Household. Match the base
      // plan as well as the product ID so the same product can safely map to
      // different Homi entitlements.
      final productRef = catalog.products
          .where(
            (item) =>
                item.productId == details.id &&
                (item.monthlyBasePlanId == basePlanId ||
                    item.annualBasePlanId == basePlanId),
          )
          .firstOrNull;
      if (productRef == null) continue;

      final cadence = basePlanId == productRef.monthlyBasePlanId
          ? HomiBillingCadence.monthly
          : basePlanId == productRef.annualBasePlanId
              ? HomiBillingCadence.annual
              : null;
      if (cadence == null) continue;

      offers.add(
        HomiStoreOffer(
          plan: productRef.plan,
          cadence: cadence,
          productDetails: details,
          basePlanId: basePlanId,
          displayPrice: details.price,
          offerToken: details.offerToken,
        ),
      );
    }

    final missing = response.notFoundIDs.toList(growable: false);
    return _lastCatalog = HomiBillingCatalogSnapshot(
      storeAvailable: true,
      catalogConfigured: true,
      offers: List.unmodifiable(offers),
      message: missing.isEmpty
          ? null
          : 'Some Homi+ products are not available from Google Play yet.',
    );
  }

  Future<bool> purchase(HomiStoreOffer offer) async {
    final user = _requireUser();
    start();
    final parameter = GooglePlayPurchaseParam(
      productDetails: offer.productDetails,
      applicationUserName: obfuscatedAccountId(user.uid),
      offerToken: offer.offerToken,
    );
    return _inAppPurchase.buyNonConsumable(purchaseParam: parameter);
  }

  Future<void> restorePurchases() async {
    final user = _requireUser();
    start();
    await _inAppPurchase.restorePurchases(
      applicationUserName: obfuscatedAccountId(user.uid),
    );
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          _emit(
            HomiBillingNoticeType.pending,
            'Google Play is still processing this purchase.',
            productId: purchase.productID,
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyPurchase(purchase);
        case PurchaseStatus.canceled:
          _emit(
            HomiBillingNoticeType.canceled,
            'The purchase was canceled.',
            productId: purchase.productID,
          );
        case PurchaseStatus.error:
          _emit(
            HomiBillingNoticeType.error,
            purchase.error?.message ?? 'Google Play could not complete the purchase.',
            productId: purchase.productID,
          );
      }
    }
  }

  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    final user = _user;
    if (user == null) {
      _emit(
        HomiBillingNoticeType.error,
        'Sign in to verify this Homi+ purchase.',
        productId: purchase.productID,
      );
      return;
    }
    if (!catalog.productIds.contains(purchase.productID)) {
      _emit(
        HomiBillingNoticeType.error,
        'This Google Play purchase is not a configured Homi+ product.',
        productId: purchase.productID,
      );
      return;
    }

    final token = purchase.verificationData.serverVerificationData.trim();
    if (token.isEmpty) {
      _emit(
        HomiBillingNoticeType.error,
        'Google Play did not provide a purchase token for secure verification.',
        productId: purchase.productID,
      );
      return;
    }

    try {
      final result = await _cloudActions.call(
        'verifyGooglePlaySubscription',
        <String, dynamic>{
          'purchaseToken': token,
          'productId': purchase.productID,
        },
      );
      if (result['verified'] != true) {
        throw StateError('Google Play could not verify this subscription.');
      }

      // The backend uses the Android Publisher API to acknowledge the purchase
      // only when Google reports ACKNOWLEDGEMENT_STATE_PENDING. Do not issue a
      // second client acknowledgement against a stale local PurchaseDetails.
      _emit(
        purchase.status == PurchaseStatus.restored
            ? HomiBillingNoticeType.restored
            : HomiBillingNoticeType.verified,
        purchase.status == PurchaseStatus.restored
            ? 'Your Homi+ subscription was restored.'
            : 'Your Homi+ subscription was verified.',
        productId: purchase.productID,
      );
    } catch (_) {
      // The backend remains the only authority allowed to grant or acknowledge
      // Homi+. Failed server verification therefore leaves paid access locked.
      _emit(
        HomiBillingNoticeType.error,
        'Homi could not verify this purchase securely. No paid access was granted.',
        productId: purchase.productID,
      );
    }
  }

  String? _basePlanId(GooglePlayProductDetails details) {
    final index = details.subscriptionIndex;
    final offerDetails = details.productDetails.subscriptionOfferDetails;
    if (index == null ||
        offerDetails == null ||
        index < 0 ||
        index >= offerDetails.length) {
      return null;
    }
    return offerDetails[index].basePlanId;
  }

  static String obfuscatedAccountId(String uid) {
    return sha256.convert(utf8.encode('homi:$uid')).toString();
  }

  User _requireUser() {
    final user = _user;
    if (user == null) {
      throw StateError('Sign in to manage a Homi+ subscription.');
    }
    return user;
  }

  void _emit(
    HomiBillingNoticeType type,
    String message, {
    String? productId,
  }) {
    if (_noticeController.isClosed) return;
    _noticeController.add(
      HomiBillingNotice(type: type, message: message, productId: productId),
    );
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _noticeController.close();
  }
}
