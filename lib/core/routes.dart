import 'package:flutter/material.dart';

import '../features/capture/capture_page.dart';
import '../features/document/document_page.dart';
import '../features/history/history_page.dart';
import '../features/home/home_page.dart';
import '../features/result/result_page.dart';
import '../features/settings/settings_page.dart';
import '../features/splash/splash_page.dart';

/// 应用路由表。
///
/// 采用原生 Navigator + 命名路由，避免引入第三方路由带来的版本耦合，
/// 同时保持 URL 语义清晰，便于后续接入 deep link。
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String capture = '/capture';
  static const String result = '/result';
  static const String history = '/history';
  static const String settings = '/settings';
  static const String document = '/document';

  static Route<dynamic>? generate(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments;

    switch (name) {
      case AppRoutes.splash:
        return _fadeRoute(const SplashPage(), settings);
      case AppRoutes.home:
        return _fadeRoute(const HomePage(), settings);
      case AppRoutes.capture:
        return _slideRoute(const CapturePage(), settings);
      case AppRoutes.history:
        return _slideRoute(const HistoryPage(), settings);
      case AppRoutes.settings:
        return _slideRoute(const SettingsPage(), settings);
      case AppRoutes.result:
        // 结果页必须携带一次识别会话的数据。
        if (args is ResultPageArgs) {
          return _slideRoute(ResultPage(args: args), settings);
        }
        return _errorRoute('结果页缺少参数', settings);
      case AppRoutes.document:
        if (args is DocumentPageArgs) {
          return _slideRoute(DocumentPage(args: args), settings);
        }
        return _errorRoute('文档页缺少参数', settings);
      default:
        return _errorRoute('未知路由：$name', settings);
    }
  }

  static Route<T> _fadeRoute<T>(Widget page, RouteSettings settings) {
    return PageRouteBuilder<T>(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  static Route<T> _slideRoute<T>(Widget page, RouteSettings settings) {
    return MaterialPageRoute<T>(
      settings: settings,
      builder: (_) => page,
    );
  }

  static Route<T> _errorRoute<T>(String message, RouteSettings settings) {
    return MaterialPageRoute<T>(
      settings: settings,
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('页面错误')),
        body: Center(child: Text(message)),
      ),
    );
  }
}
