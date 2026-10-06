import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../core/result.dart';

/// 把 Widget 原样导出为高清 PNG。
///
/// 分享卡片不做截图式录屏，而是用 RepaintBoundary 离屏渲染，
/// 好处是导出分辨率与屏幕无关（默认 3x，最高可到 4x），
/// 发朋友圈/小红书时不会被压糊。
class CardCaptureService {
  CardCaptureService._();

  /// [key] 必须是套在卡片最外层的 RepaintBoundary 的 GlobalKey。
  static Future<Result<Uint8List>> capture(
    GlobalKey key, {
    double pixelRatio = 3,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        return Result.err(
            AppException('卡片还没渲染好，请稍后再试', code: 'not_ready'));
      }
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        return Result.err(AppException('导出图片失败', code: 'encode'));
      }
      return Result.ok(bytes.buffer.asUint8List());
    } catch (e, s) {
      debugPrint('[CardCaptureService] 导出失败: $e');
      return Result.err(AppException.unknown(e), s);
    }
  }

  /// 导出并写入临时文件，交给分享/保存逻辑消费。
  static Future<Result<String>> captureToFile(
    GlobalKey key, {
    String prefix = 'flora_card',
    double pixelRatio = 3,
  }) async {
    final r = await capture(key, pixelRatio: pixelRatio);
    return r.when(
      ok: (bytes) async {
        try {
          final dir = await getTemporaryDirectory();
          final file = File(
              '${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png');
          await file.writeAsBytes(bytes, flush: true);
          return Result.ok(file.path);
        } catch (e, s) {
          return Result.err(AppException.unknown(e), s);
        }
      },
      err: (e) async => Result.err(e),
    );
  }

  /// 长图拼接：把卡片与植物照片上下合成一张，更适合小红书。
  ///
  /// 纯 Dart 实现（Canvas 绘制），不依赖原生库。
  static Future<Result<Uint8List>> composeVertical({
    required Uint8List cardPng,
    required Uint8List photoBytes,
    double gap = 0,
    Color background = Colors.white,
  }) async {
    try {
      final cardCodec = await ui.instantiateImageCodec(cardPng);
      final photoCodec = await ui.instantiateImageCodec(photoBytes);
      final cardFrame = await cardCodec.getNextFrame();
      final photoFrame = await photoCodec.getNextFrame();
      final cardImg = cardFrame.image;
      final photoImg = photoFrame.image;

      final width = cardImg.width > photoImg.width ? cardImg.width : photoImg.width;
      final height = cardImg.height + photoImg.height + gap.round();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = background,
      );
      canvas.drawImage(
        cardImg,
        Offset(((width - cardImg.width) / 2).toDouble(), 0),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.drawImage(
        photoImg,
        Offset(((width - photoImg.width) / 2).toDouble(),
            (cardImg.height + gap).toDouble()),
        Paint()..filterQuality = ui.FilterQuality.high,
      );
      final picture = recorder.endRecording();
      final composed = await picture.toImage(width, height);
      final data = await composed.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return Result.err(AppException('合成失败', code: 'encode'));
      }
      return Result.ok(data.buffer.asUint8List());
    } catch (e, s) {
      return Result.err(AppException.unknown(e), s);
    }
  }
}
