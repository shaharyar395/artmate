import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/app_config.dart';
import '../core/app_state.dart';

/// Google Play / App Store subscriptions for Premium.
///
/// Call [PremiumService.init] once at start-up. It listens to the purchase
/// stream for the whole app lifetime, so purchases that finish while the
/// app is in the background (or pending payments) are still delivered.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  AppState? _state;

  bool available = false;
  final Map<String, ProductDetails> products = {};

  /// Fires true when a purchase/restore is delivered, false on error/cancel.
  final StreamController<PurchaseEvent> events =
      StreamController<PurchaseEvent>.broadcast();

  static const Set<String> _ids = {
    AppConfig.premiumYearlyId,
    AppConfig.premiumWeeklyId,
  };

  Future<void> init(AppState state) async {
    _state = state;
    try {
      _sub ??= _iap.purchaseStream.listen(_onPurchases,
          onError: (Object e) => events.add(PurchaseEvent.error('$e')));
      available = await _iap.isAvailable();
      if (!available) return;
      final res = await _iap.queryProductDetails(_ids);
      for (final p in res.productDetails) {
        products.putIfAbsent(p.id, () => p);
      }
    } catch (e) {
      debugPrint('Premium unavailable: $e');
      available = false;
    }
  }

  ProductDetails? product(String id) => products[id];

  /// Why the real store sheet could not open (for the test sheet / logs).
  String? lastProblem;

  Future<void> _refreshProducts() async {
    final res = await _iap.queryProductDetails(_ids);
    if (res.error != null) lastProblem = res.error!.message;
    if (res.notFoundIDs.isNotEmpty) {
      lastProblem =
          'Products not found in Play Console: ${res.notFoundIDs.join(', ')}';
    }
    for (final p in res.productDetails) {
      products.putIfAbsent(p.id, () => p);
    }
  }

  /// Opens the store's payment sheet (Google Play / App Store).
  Future<BuyResult> buy(String productId) async {
    try {
      available = await _iap.isAvailable();
      if (!available) {
        lastProblem = 'Google Play Billing is not available on this device '
            '(install the app from Google Play and sign in to Play Store).';
        debugPrint('Premium: $lastProblem');
        return BuyResult.storeUnavailable;
      }
      if (products[productId] == null) await _refreshProducts();
      final p = products[productId];
      if (p == null) {
        lastProblem ??= 'Product "$productId" was not found.';
        debugPrint('Premium: $lastProblem');
        return BuyResult.productNotFound;
      }
      final ok = await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: p));
      return ok ? BuyResult.started : BuyResult.error;
    } catch (e) {
      lastProblem = '$e';
      debugPrint('Premium: $e');
      return BuyResult.error;
    }
  }

  /// Test purchase (used only by the test payment sheet when the real store
  /// can't be reached; see AppConfig.billingTestMode).
  void grantTestPremium(String productId) {
    _state?.setPremium(true, plan: '$productId (test)');
    events.add(const PurchaseEvent.success());
  }

  /// Asks the store for previous purchases. Resolves true if any were found
  /// within [timeout].
  Future<bool> restore({Duration timeout = const Duration(seconds: 4)}) async {
    if (!available) available = await _iap.isAvailable();
    if (!available) return false;
    final c = Completer<bool>();
    late final StreamSubscription<PurchaseEvent> s;
    s = events.stream.listen((e) {
      if (e.restored && !c.isCompleted) c.complete(true);
    });
    await _iap.restorePurchases();
    Future.delayed(timeout, () {
      if (!c.isCompleted) c.complete(_state?.isPremium == true);
    });
    final r = await c.future;
    await s.cancel();
    return r;
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          events.add(const PurchaseEvent.pending());
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (_ids.contains(p.productID)) {
            // NOTE: for production, verify p.verificationData on your server.
            _state?.setPremium(true, plan: p.productID);
            events.add(PurchaseEvent.success(
                restored: p.status == PurchaseStatus.restored));
          }
          break;
        case PurchaseStatus.error:
          events.add(PurchaseEvent.error(p.error?.message ?? 'error'));
          break;
        case PurchaseStatus.canceled:
          events.add(const PurchaseEvent.cancelled());
          break;
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    events.close();
  }
}

enum BuyResult { started, storeUnavailable, productNotFound, error }

class PurchaseEvent {
  const PurchaseEvent.success({this.restored = false})
      : ok = true,
        pending = false,
        cancelled = false,
        message = null;
  const PurchaseEvent.pending()
      : ok = false,
        pending = true,
        cancelled = false,
        restored = false,
        message = null;
  const PurchaseEvent.cancelled()
      : ok = false,
        pending = false,
        cancelled = true,
        restored = false,
        message = null;
  const PurchaseEvent.error(this.message)
      : ok = false,
        pending = false,
        cancelled = false,
        restored = false;

  final bool ok;
  final bool pending;
  final bool cancelled;
  final bool restored;
  final String? message;
}
