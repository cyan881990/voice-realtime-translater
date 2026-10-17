import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/config.dart';
import '../core/settings_controller.dart';

/// One-time, non-consumable "remove ads" purchase (Google Play / App Store).
class PurchaseService {
  PurchaseService(this._settings);

  final SettingsController _settings;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;

  Future<void> init() async {
    if (!await _iap.isAvailable()) return;
    _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
    final res = await _iap.queryProductDetails({AppConfig.removeAdsProductId});
    if (res.productDetails.isNotEmpty) product = res.productDetails.first;
  }

  /// Localised price, e.g. "₫49.000", or null until the store answers.
  String? get price => product?.price;

  Future<bool> buyRemoveAds() async {
    final p = product;
    if (p == null) return false;
    return _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      if (pd.productID == AppConfig.removeAdsProductId &&
          (pd.status == PurchaseStatus.purchased || pd.status == PurchaseStatus.restored)) {
        _settings.adsRemoved = true;
      }
      if (pd.pendingCompletePurchase) {
        await _iap.completePurchase(pd);
      }
    }
  }

  void dispose() => _sub?.cancel();
}
