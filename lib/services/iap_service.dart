import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../config/app_config.dart';

/// 苹果 / Google Play 内购服务。
///
/// 负责加载商品、发起购买、恢复购买，并监听 [purchaseStream]：
/// 一旦 purchase 成功或恢复，就通过 [onProUnlocked] 把 [AppSettings.isPro] 置真，
/// 并写入订阅到期日，从而去除广告、解锁会员权益。订阅到期后 [onProExpired] 会被触发，
/// 权益按 [AppSettings.isProActive] 自动回落为免费。
///
/// 说明：这里走的是客户端解锁（适合个人开发者快速上线）。若担心越狱/退款作弊，
/// 生产环境应再加一道服务端收据校验（App Store / Play 服务端通知），服务端返回的
/// 真实到期日应回写 [AppSettings.proExpiryMillis]，覆盖本类的客户端近似推算。
class IapService {
  IapService({
    required this.onProUnlocked,
    this.onProExpired,
  });

  /// 解锁 Pro 时回调。
  ///
  /// [expiry] 为订阅到期日：传 null 表示永久（非消耗型「去广告」）；
  /// 订阅则按客户端近似周期推算（见 [IapProducts.subscriptionDays]）。
  /// 由 provider 写入 [AppSettings.isPro] 与到期日。
  final void Function({DateTime? expiry}) onProUnlocked;

  /// 订阅已过期 / 无法解锁时回调（由 provider 将 isPro 回落为 false）。
  final void Function()? onProExpired;

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

  /// 发起购买。
  ///
  /// 当前 SDK 版本（in_app_purchase ^3.3.1）中订阅与非消耗型都走
  /// [InAppPurchase.buyNonConsumable]——订阅在商店后台按商品类型区分，不由 Dart
  /// 调用区分（该版本尚无 [InAppPurchase.buySubscription]）。若日后升级到暴露
  /// buySubscription 的版本，订阅应改走该方法。
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
        _unlockOrExpire(d);
      }
      // 不论成功失败，pending 的交易都要完结，否则系统会反复回调。
      if (d.pendingCompletePurchase) {
        _iap.completePurchase(d);
      }
    }
  }

  /// 根据购买/恢复记录解锁 Pro 并写入到期日。
  ///
  /// - 非消耗型（永久去广告）：[expiry] 为 null，永久 Pro。
  /// - 订阅：以「当前时间 + 周期」近似为到期日写入 [AppSettings.proExpiryMillis]。
  ///   只要商店仍回调该笔交易，就视为有效续期并顺延。真正是否仍在有效期内，
  ///   由 [AppSettings.isProActive] 按持久化的到期日实时判断（过期则广告/水印自动回落）。
  ///   若日后接入服务端收据校验，校验到已过期时应调用 [onProExpired] 主动清零。
  void _unlockOrExpire(PurchaseDetails d) {
    if (IapProducts.isSubscription(d.productID)) {
      final expiry = DateTime.now().add(
        Duration(days: IapProducts.subscriptionDays(d.productID)),
      );
      onProUnlocked(expiry: expiry);
    } else {
      onProUnlocked(expiry: null);
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
