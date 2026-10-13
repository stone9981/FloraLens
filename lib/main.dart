import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/routes.dart';
import 'core/route_observer.dart';
import 'core/theme.dart';
import 'data/local/settings_store.dart';
import 'data/models/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 竖屏优先，符合手机拍摄类应用的使用习惯。
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FloraLensApp(),
    ),
  );
}

/// 应用级入口 Widget。
///
/// 这里只负责主题、路由与全局 providers 的装配，
/// 具体业务页面放在 features/ 下。
class FloraLensApp extends ConsumerStatefulWidget {
  const FloraLensApp({super.key});

  @override
  ConsumerState<FloraLensApp> createState() => _FloraLensAppState();
}

class _FloraLensAppState extends ConsumerState<FloraLensApp> {
  @override
  void initState() {
    super.initState();
    // 预热设置，避免首帧读取磁盘造成抖动。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      // 初始化广告与内购（懒加载 provider，首次读取即创建并触发 init）。
      // 只有非 Pro 用户才请求 ATT 追踪授权：Pro 不展示广告，
      // 对其弹「允许跟踪」属于理由不成立的权限申请，易被 5.1.1 质疑。
      ref.read(adServiceProvider).init(requestTracking: !settings.isProActive);
      ref.read(iapServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = AppLanguage.fromId(settings.language).locale;

    return MaterialApp(
      title: 'FloraLens',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: locale,
      // 跟随系统且设备非中文时，一律回退英文。
      localeResolutionCallback: (deviceLocale, _) =>
          AppLocalizations.resolve(deviceLocale),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generate,
      navigatorObservers: <NavigatorObserver>[routeObserver],
      builder: (context, child) {
        // 限制整体字号缩放倍率，避免用户系统大字导致卡片排版溢出。
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.15,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
