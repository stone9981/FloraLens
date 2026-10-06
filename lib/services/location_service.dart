import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// 分享卡片水印用的位置获取。
///
/// 设计原则：
/// - 只取「市 / 区」级别，绝不暴露街道等精确坐标，降低分享时的隐私风险；
/// - 任何一步失败（没授权、没网络、逆地理编码挂了）都返回 null，
///   调用方据此「不写位置」而不是弹错，体验不打断。
class LocationService {
  LocationService._();

  static bool _allowed(LocationPermission p) =>
      p == LocationPermission.always || p == LocationPermission.whileInUse;

  /// 返回形如「深圳市 南山区」的地点标签；不可用则返回 null。
  static Future<String?> placeLabel() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (!_allowed(perm)) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

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
          if (joined.isNotEmpty) return joined;
        }
      } catch (_) {
        // 逆地理编码失败（无网络 / 设备缺 GMS），退一步用坐标兜底。
      }
      return '${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}';
    } catch (_) {
      return null;
    }
  }
}
