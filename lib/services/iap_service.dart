import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_config.dart';

/// 苹果 / Google Play 内购服务。
///
/// 负责加载商品、发起购买、恢复购买，并监听 [purchaseStream]：
/// 一旦 purchase 成功或恢复，就通过 [onProUnlocked] 把 [AppSettings.isPro] 置真，
/// 从而去除广告、解锁会员权益。
///
/// 说明：这里走的是客户端解锁（适合个人开发者快速上线）。若担心越狱/退款作弊，
/// 生产环境应再加一道服务端收据校验（App Store / Play 服务端通知）。
class IapService {
  IapService({required this.onProUnlocked});

  /// 解锁 Pro 时回调（由 provider 写入 settings.isPro）。
  final void Function() onProUnlocked;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// 商店是否可用（沙盒/真机可用；模拟器通常不可用）。
  bool available = false;

  /// 已加载的商品详情，UI 用它展示价格。
  List<ProductDetails> products = const <ProductDetails>[];

  Future<void> init() async {
    available = await _iap.isAvailable();
    if (!available) return;
    _sub = _iap.purchaseStream.listen(_handlePurchase);
    try {
      final resp = await _iap.queryProductDetails(IapProducts.all.toSet());
      products = resp.productDetails;
    } catch (e) {
      debugPrint('[IapService] queryProductDetails failed: $e');
    }
  }

  ProductDetails? productById(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 发起购买。订阅与「去广告」都走 buyNonConsumable。
  ///
  /// 返回 true 表示购买流程已发起（不代表已支付成功，成功以 purchaseStream 为准）。
  Future<bool> buy(ProductDetails product) async {
    if (!available) return false;
    final param = PurchaseParam(productDetails: product);
    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      return ok;
    } catch (e) {
      debugPrint('[IapService] buy failed: $e');
      return false;
    }
  }

  /// 恢复已购（App Store 审核要求必须提供入口）。
  Future<void> restore() async {
    if (!available) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IapService] restore failed: $e');
    }
  }

  void _handlePurchase(List<PurchaseDetails> details) {
    for (final d in details) {
      if (d.status == PurchaseStatus.purchased ||
          d.status == PurchaseStatus.restored) {
        onProUnlocked();
      }
      // 不论成功失败，pending 的交易都要完结，否则系统会反复回调。
      if (d.pendingCompletePurchase) {
        _iap.completePurchase(d);
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
