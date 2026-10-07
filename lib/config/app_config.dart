/// 集中管理所有第三方「占位 / 生产 ID」，方便上线前一处替换、统一核对。
///
/// 上线前必做（按 checklist 逐项）：
/// 1. [AdsConfig.useTestAds] 改为 false；
/// 2. [AdsConfig] 里所有 `production*` 占位 ID 换成 AdMob 后台真实值；
/// 3. [IapProducts] 里三个商品 ID 若与 App Store Connect 创建的不一致，在此对齐；
/// 4. 原生配置里的 App ID 也要同步替换：
///    - iOS：ios/Runner/Info.plist 的 `GADApplicationIdentifier`
///    - Android：android/app/src/main/AndroidManifest.xml 的 `com.google.android.gms.ads.APPLICATION_ID`
///    （这两个值当前填的是 Google 官方测试 App ID，和本文件 `_testAppId` 一致。）
library;

import 'dart:io';

/// AdMob 广告配置：App ID、广告单元 ID、是否测试模式。
class AdsConfig {
  AdsConfig._();

  /// true=使用 Google 官方测试 ID（开发期安全，不会产生费用）；上线务必改 false。
  static const bool useTestAds = false;

  // ---------------------- 生产环境占位 ID（上线替换） ----------------------

  /// 生产 App ID（Android）。AdMob 后台每个应用独立分配。
  static const String productionAppIdAndroid =
      'ca-app-pub-xxxxxxxxxxxxxxxx~xxxxxxxxxx';

  /// 生产 App ID（iOS）。
  static const String productionAppIdIos =
      'ca-app-pub-8786681445100249~9395633460';

  /// 生产横幅广告单元 ID。
  static const String productionBannerAdUnit =
      'ca-app-pub-8786681445100249/6319622997';

  /// 生产插屏广告单元 ID。
  static const String productionInterstitialAdUnit =
      'ca-app-pub-8786681445100249/2282421043';

  // ---------------------- 以下为 Google 官方测试 ID（可直接提交） ----------------------

  static const String _testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  /// 当前生效的 App ID（测试期返回测试 ID，否则按平台返回生产 ID）。
  ///
  /// 注意：仅作集中参考；原生侧（Info.plist / AndroidManifest）仍需手动同步。
  static String get appId => useTestAds
      ? _testAppId
      : (Platform.isIOS ? productionAppIdIos : productionAppIdAndroid);

  /// 当前生效的横幅广告单元 ID。
  static String get bannerAdUnitId => useTestAds
      ? (Platform.isIOS ? _testBannerIos : _testBannerAndroid)
      : productionBannerAdUnit;

  /// 当前生效的插屏广告单元 ID。
  static String get interstitialAdUnitId => useTestAds
      ? (Platform.isIOS ? _testInterstitialIos : _testInterstitialAndroid)
      : productionInterstitialAdUnit;
}

/// 内购商品 ID。
///
/// 必须在 App Store Connect（iOS）/ Google Play Console（Android）创建对应商品，
/// 且 ID 与此完全一致。当前为占位 ID，上线前按需对齐。
///
/// 注意：iOS 上架前还需在 App Store Connect 签署《付费 App 协议》，
/// 否则 [InAppPurchase.isAvailable] 会返回 false。
class IapProducts {
  IapProducts._();

  /// 自动续期订阅：Pro 会员（月付）。
  static const String proMonthly = 'com.floralens.pro.monthly';

  /// 自动续期订阅：Pro 会员（年付，更划算）。
  static const String proYearly = 'com.floralens.pro.yearly';

  /// 非消耗型：永久去广告（也可并入 Pro，按需取舍）。
  static const String removeAds = 'com.floralens.remove_ads';

  /// 全部商品 ID，供 [queryProductDetails] 查询。
  static const List<String> all = <String>[proMonthly, proYearly, removeAds];

  /// 订阅类商品走 buyNonConsumable（续期由系统托管）。
  static bool isSubscription(String id) => id == proMonthly || id == proYearly;
}
