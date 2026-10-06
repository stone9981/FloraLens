import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants.dart';

/// 分享卡片水印用的位置获取。
///
/// 设计原则：
/// - 只取「市 / 区」级别，绝不暴露街道等精确坐标，降低分享时的隐私风险；
/// - 任何一步失败（没授权、没网络、逆地理编码挂了）都返回明确的失败原因，
///   调用方据此「不写位置」而不是弹错，体验不打断。
class LocationService {
  LocationService._();

  static bool _allowed(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  /// 取位置的结果：成功时 [label] 非空（如「深圳市 南山区」）；
  /// 失败时 [label] 为 null、[error] 给出中文原因，便于提示用户到底卡在哪一步。
  static const LocationResult _serviceOff =
      LocationResult(error: AppStrings.locationServiceOff);
  static const LocationResult _permissionDenied =
      LocationResult(error: AppStrings.locationPermissionDenied);
  static const LocationResult _noFix =
      LocationResult(error: AppStrings.locationNoFix);
  static const LocationResult _generic =
      LocationResult(error: AppStrings.locationUnavailable);

  /// 返回形如「深圳市 南山区」的地点标签；不可用则返回带原因的 [LocationResult]。
  static Future<LocationResult> placeLabel() async {
    try {
      // 1) 系统定位服务是否开启——没开就别傻等 12s 超时，直接提示。
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _serviceOff;
      }

      // 2) 权限：被拒（含永久拒绝）直接返回，不抛异常、不打断。
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!_allowed(perm)) return _permissionDenied;

      // 3) 取当前定位：12s 超时则回落到「最近一次已知位置」，都拿不到才认输。
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return _noFix;

      // 4) 逆地理编码：需要网络 + GMS，失败就退化为经纬度兜底，不报错。
      try {
        final geocoding = Geocoding();
        final marks = await geocoding.placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        final pm = marks.isEmpty ? null : marks.first;
        if (pm != null) {
          final parts = <String>[
            if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
            if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
              pm.subLocality!,
          ];
          final joined = parts.join(' ').trim();
          if (joined.isNotEmpty) return LocationResult.label(joined);
        }
      } catch (_) {
        // 逆地理编码失败（无网络 / 设备缺 GMS），退一步用坐标兜底。
      }
      return LocationResult.label(
        '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}',
      );
    } catch (_) {
      return _generic;
    }
  }
}

/// 取位置的结果封装：[label] 与 [error] 二选一。
class LocationResult {
  const LocationResult({this.label, this.error});
  const LocationResult.label(this.label) : error = null;
  final String? label;
  final String? error;
}
