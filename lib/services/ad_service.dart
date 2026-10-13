import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';

/// AdMob 广告服务：初始化、横幅/插屏加载与展示，以及识别计数（用于插屏阈值）。
///
/// 是否为 Pro 用户由调用方（设置页/各页面读 [AppSettings.isPro]）判断，
/// 本服务只负责「按 Pro 之外」的时机把广告展示出来。
class AdService {
  AdService();

  bool _initialized = false;
  int _identifyCount = 0;
  InterstitialAd? _interstitial;

  /// 累计进入结果页的次数，用于决定何时弹插屏（每 3 次）。
  int get identifyCount => _identifyCount;

  /// 每次打开结果页调用一次。
  void recordIdentify() => _identifyCount++;

  /// 是否到了该弹插屏的计数时机（仅看计数；是否 Pro 由调用方把关）。
  bool get shouldShowInterstitial =>
      _identifyCount > 0 && _identifyCount % 3 == 0;

  /// 初始化广告 SDK。
  ///
  /// [requestTracking] 为 true 时才在 iOS 上弹 ATT 追踪授权。
  /// **Pro 用户不展示广告，不应请求追踪授权**（理由不成立易被 5.1.1 质疑），
  /// 截图模式下同理——连广告都不展示，没必要申请授权。
  Future<void> init({bool requestTracking = true}) async {
    if (_initialized) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      // iOS 14+ 需要 ATT 授权才能投放个性化广告。
      if (Platform.isIOS && requestTracking && !AdsConfig.screenshotMode) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }
    } catch (e) {
      debugPrint('[AdService] init failed: $e');
    }
  }

  /// 预加载一张插屏，便于返回首页时即时弹出。
  Future<void> preloadInterstitial() async {
    if (AdsConfig.screenshotMode) return;
    if (_interstitial != null) return;
    await InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] interstitial load failed: $error');
          _interstitial = null;
        },
      ),
    );
  }

  /// 立即展示插屏（若尚未加载则先加载）。无广告可用时静默返回。
  Future<void> showInterstitial() async {
    if (AdsConfig.screenshotMode) return;
    if (_interstitial == null) {
      await preloadInterstitial();
    }
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    try {
      ad.show();
    } catch (e) {
      debugPrint('[AdService] show interstitial failed: $e');
    }
  }

  void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
  }
}

/// 底部横幅广告组件。
///
/// 调用方需自行判断是否渲染：Pro 用户（[AppSettings.isPro]）不要挂载本组件。
/// 广告未加载完成前返回空占位，避免布局抖动。
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key, this.size = AdSize.banner});

  final AdSize size;

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _banner;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 截图模式：不创建、不加载任何广告，确保截出的图干净无广告。
    if (AdsConfig.screenshotMode) return;
    _banner = BannerAd(
      adUnitId: AdsConfig.bannerAdUnitId,
      size: widget.size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _ready = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdBanner] failed: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    _banner = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AdsConfig.screenshotMode) return const SizedBox.shrink();
    final banner = _banner;
    if (!_ready || banner == null) return const SizedBox.shrink();
    return SizedBox(
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: AdWidget(ad: banner),
    );
  }
}

/// 信息流里的「广告卡」：复用横幅广告，外层由调用方用 SoftCard 包成卡片。
class AdInlineCard extends StatelessWidget {
  const AdInlineCard({super.key, this.size = AdSize.largeBanner});

  final AdSize size;

  @override
  Widget build(BuildContext context) => AdBannerWidget(size: size);
}
