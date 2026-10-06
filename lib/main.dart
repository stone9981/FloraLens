import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants.dart';
import 'core/routes.dart';
import 'core/theme.dart';
import 'data/local/settings_store.dart';

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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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
      ref.read(settingsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generate,
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
