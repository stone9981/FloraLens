import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../core/result.dart';

/// 对外分发：保存到系统相册 / 调起系统分享面板。
///
/// 为什么用系统分享面板而不是直接接微信 SDK：
/// 1. 微信朋友圈的分享接口需要开放平台账号 + 应用审核，个人开发者很难过审；
/// 2. 系统面板里本来就有微信、朋友圈、小红书、微博、QQ，覆盖面更广；
/// 3. 少一个原生依赖，包体更小、上架风险更低。
/// 用户最省事的链路是：先存相册 → 在朋友圈发图时直接选。
class ShareService {
  ShareService._();

  static const String albumName = 'FloraLens';

  /// 保存图片到系统相册。
  static Future<Result<void>> saveToGallery(String path) async {
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          return Result.err(AppException.permission());
        }
      }
      await Gal.putImage(path, album: albumName);
      return const Result<void>.ok(null);
    } catch (e) {
      debugPrint('[ShareService] 保存失败: $e');
      return Result.err(
        AppException(
          e.toString().contains('denied') || e.toString().contains('Permission')
              ? '相册权限被拒绝，请在系统设置中允许访问照片'
              : '保存失败，请重试',
          code: 'gallery',
        ),
      );
    }
  }

  /// 调起系统分享面板。图片必须是已存在的本地文件。
  static Future<Result<void>> shareImage(
    String path, {
    String? text,
    String? subject,
  }) async {
    try {
      if (!await File(path).exists()) {
        return Result.err(AppException('图片文件不存在', code: 'missing'));
      }
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path)],
          text: text,
          subject: subject,
          fileNameOverrides: <String>['floralens_flower.png'],
        ),
      );
      debugPrint('[ShareService] 分享结果: ${result.status}');
      return const Result<void>.ok(null);
    } catch (e) {
      debugPrint('[ShareService] 分享失败: $e');
      return Result.err(AppException('分享失败：$e', code: 'share'));
    }
  }

  /// 只分享文字（例如植物小知识）。
  static Future<Result<void>> shareText(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      return const Result<void>.ok(null);
    } catch (e) {
      return Result.err(AppException('分享失败：$e', code: 'share'));
    }
  }
}
