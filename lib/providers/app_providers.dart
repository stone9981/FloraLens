import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine/identification_engine.dart';
import '../data/llm/llm_client.dart';
import '../data/local/settings_store.dart';
import '../data/models/app_settings.dart';
import '../data/offline/common_plants.dart';
import '../l10n/app_localizations.dart';
import '../services/ad_service.dart';
import '../services/iap_service.dart';

/// 内置植物词典（懒加载一次）。
final plantLibraryProvider = FutureProvider<CommonPlantLibrary>((ref) async {
  return CommonPlantLibrary.load();
});

/// 不依赖 BuildContext 的本地化实例。
///
/// 用在识别流程等没有 [BuildContext] 的地方：跟随设置里的语言，
/// 跟随系统时按设备语言解析（非中文回退英文）。
final appLocalizationsProvider = Provider<AppLocalizations>((ref) {
  final lang = AppLanguage.fromId(ref.watch(settingsProvider).language);
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  final locale =
      lang.locale ??
      AppLocalizations.resolve(deviceLocale ?? const Locale('en'));
  return AppLocalizations(locale);
});

/// 按当前设置构造的大模型客户端。
final llmClientProvider = Provider<LlmClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return LlmClient(settings.llm);
});

/// 档案生成器。
final profileGeneratorProvider = Provider<PlantProfileGenerator>((ref) {
  final settings = ref.watch(settingsProvider);
  final client = ref.watch(llmClientProvider);
  return PlantProfileGenerator(
    client,
    modelLabel: settings.llm.model.isEmpty ? '大模型' : settings.llm.model,
  );
});

/// 按当前设置构造的识别引擎。
final identificationEngineProvider = Provider<IdentificationEngine>((ref) {
  final settings = ref.watch(settingsProvider);
  final l10n = ref.watch(appLocalizationsProvider);
  return EngineFactory.create(settings, l10n);
});

/// 广告服务（AdMob）。单例，全应用共享识别计数，用于插屏阈值。
final adServiceProvider = Provider<AdService>((ref) {
  final svc = AdService();
  ref.onDispose(() => svc.dispose());
  return svc;
});

/// 内购服务（苹果 App Store / Google Play）。
///
/// 购买或恢复成功时，把 [AppSettings.isPro] 置真，从而去广告、解锁会员权益。
final iapServiceProvider = Provider<IapService>((ref) {
  final svc = IapService(
    onProUnlocked: () {
      ref.read(settingsProvider.notifier).setPro(true);
    },
  );
  ref.onDispose(() => svc.dispose());
  return svc;
});
