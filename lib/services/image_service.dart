import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

import '../core/result.dart';

/// 图片处理服务：压缩、落盘、清理。
///
/// 拍照得到的原图动辄 5~12MB，直接上传既慢又费额度，
/// 所以上传前统一压到长边 1600px、质量 85，肉眼无损但体积通常能降到 300KB 以内。
class ImageService {
  ImageService._();

  static const int _uploadMaxSide = 1600;
  static const int _uploadQuality = 85;

  /// 上传前压缩。输出一定是 JPEG。
  static Future<Uint8List> compressForUpload(Uint8List source) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        source,
        minWidth: _uploadMaxSide,
        minHeight: _uploadMaxSide,
        quality: _uploadQuality,
        format: CompressFormat.jpeg,
        keepExif: false,
      );
      if (out.isNotEmpty) return out;
    } catch (e) {
      debugPrint('[ImageService] 压缩失败，改用原图: $e');
    }
    return source;
  }

  /// 临时目录：拍照/选图后的中转站。
  static Future<Directory> tempDir() => getTemporaryDirectory();

  /// 应用文档目录：历史图片与卡片长期存放处。
  static Future<Directory> docsDir() => getApplicationDocumentsDirectory();

  /// 把字节写入临时文件，返回路径。
  static Future<String> writeTemp(
    Uint8List bytes, {
    String prefix = 'flora',
    String ext = 'jpg',
  }) async {
    final dir = await tempDir();
    final name = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 读取本地图片为字节（用于上传）。
  static Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  /// 文件大小（KB），用于 UI 展示。
  static Future<int> sizeInKb(String path) async {
    try {
      final f = File(path);
      if (!await f.exists()) return 0;
      final len = await f.length();
      return len ~/ 1024;
    } catch (_) {
      return 0;
    }
  }

  /// 删除单张图片，失败不影响主流程。
  static Future<void> safeDelete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 生成唯一 id。
  static String newId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond % 100000}';

  /// 兜底：把原始图片另存到文档目录，供历史记录长期引用。
  static Future<Result<String>> copyToDocs(
    String sourcePath, {
    required String fileName,
  }) async {
    try {
      final docs = await docsDir();
      final target = File('${docs.path}/history/images/$fileName');
      await target.parent.create(recursive: true);
      await File(sourcePath).copy(target.path);
      return Result.ok(target.path);
    } catch (e) {
      return Result.err(AppException.unknown(e));
    }
  }

  /// 把已读出的字节直接写进受管目录，返回长期可用的路径。
  ///
  /// 比 [copyToDocs] 更通用：相册、截图、第三方 App 分享过来的图片，
  /// 只要能读出字节就能落盘，不依赖来源路径可写。失败返回 null。
  static Future<String?> writeManaged(String id, Uint8List bytes) async {
    try {
      final docs = await docsDir();
      final target = File('${docs.path}/history/images/$id.jpg');
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      return target.path;
    } catch (e) {
      debugPrint('[ImageService] 写入受管目录失败: $e');
      return null;
    }
  }
}
