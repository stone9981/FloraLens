import 'package:flutter/widgets.dart';

/// 全局路由观察者，用于首页「从结果页返回时」触发插屏广告。
///
/// 在 [MaterialApp.navigatorObservers] 注册，首页 [HomePage] 通过
/// [RouteObserver.subscribe] 监听 [RouteAware.didPopNext]。
final RouteObserver<ModalRoute<dynamic>> routeObserver =
    RouteObserver<ModalRoute<dynamic>>();
