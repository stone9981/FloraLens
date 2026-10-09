import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/history_item.dart';
import '../models/plant.dart';

/// 本地历史仓库。
///
/// 采用"索引文件 + 图片目录"的结构：
/// index.json 存元数据，images/ 存原图与卡片图，二者通过 id 关联。
/// 相比数据库方案零依赖，且便于用户导出备份。
class HistoryRepository {
  HistoryRepository(this._root);

  final Directory _root;

  File get _indexFile => File('${_root.path}/history/index.json');

  Directory get _imageDir => Directory('${_root.path}/history/images');

  static Future<HistoryRepository> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final repo = HistoryRepository(docs);
    await repo._imageDir.create(recursive: true);
    return repo;
  }

  Future<List<HistoryItem>> all() async {
    if (!await _indexFile.exists()) return <HistoryItem>[];
    try {
      final raw = await _indexFile.readAsString();
      if (raw.isEmpty) return <HistoryItem>[];
      final list = jsonDecode(raw) as List<dynamic>;
      final items = list
          .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
          .where((e) => e.id.isNotEmpty)
          .map(
            (e) => e.copyWith(
              imagePath: _toAbsolute(e.imagePath),
              cardPath: e.cardPath == null ? null : _toAbsolute(e.cardPath!),
            ),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      debugPrint('[HistoryRepository] 读取失败: $e');
      return <HistoryItem>[];
    }
  }

  Future<void> save(HistoryItem item) async {
    final items = (await all()).toList();
    final idx = items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item);
    }
    await _writeAll(items);
  }

  Future<void> update(String id, HistoryItem Function(HistoryItem) mutator) async {
    final items = (await all()).toList();
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    items[idx] = mutator(items[idx]);
    await _writeAll(items);
  }

  Future<void> remove(String id) async {
    final items = (await all()).toList();
    HistoryItem? target;
    for (final item in items) {
      if (item.id == id) {
        target = item;
        break;
      }
    }
    if (target == null) return;

    items.removeWhere((e) => e.id == id);
    await _writeAll(items);

    for (final path in <String?>[target.imagePath, target.cardPath]) {
      if (path == null || path.isEmpty) continue;
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> clear() async {
    await _writeAll(const <HistoryItem>[]);
    try {
      if (await _imageDir.exists()) {
        await _imageDir.delete(recursive: true);
        await _imageDir.create(recursive: true);
      }
    } catch (_) {}
  }

  /// 超出上限时裁剪最旧的记录及其图片，避免体积无限增长。
  Future<void> trimTo(int maxCount) async {
    final items = (await all()).toList();
    if (items.length <= maxCount) return;
    final removed = items.sublist(maxCount);
    await _writeAll(items.take(maxCount).toList());
    for (final item in removed) {
      for (final path in <String?>[item.imagePath, item.cardPath]) {
        if (path == null || path.isEmpty) continue;
        try {
          final f = File(path);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// 把图片写入受管目录，返回稳定路径。
  Future<String> persistImage(
    String sourcePath, {
    required String id,
    required String suffix,
  }) async {
    await _imageDir.create(recursive: true);
    final target = File('${_imageDir.path}/$id$suffix');
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<void> _writeAll(List<HistoryItem> items) async {
    await _indexFile.parent.create(recursive: true);
    // 只持久化相对路径，避免 App 重装后沙盒容器 UUID 变化导致绝对路径失效。
    final data = items
        .map(
          (e) => e
              .copyWith(
                imagePath: _toRelative(e.imagePath),
                cardPath: e.cardPath == null ? null : _toRelative(e.cardPath!),
              )
              .toJson(),
        )
        .toList();
    await _indexFile.writeAsString(jsonEncode(data));
  }

  /// 把存储路径解析为当前容器下的绝对路径。
  ///
  /// 历史原因：旧数据存的是含沙盒容器 UUID 的绝对路径，App 重装后 UUID 会变，
  /// 旧路径就失效了。这里优先用文件是否真实存在来判断；若不存在则退回到
  /// "以 history/ 为起点的相对路径 + 当前 _root" 拼出的新绝对路径。
  String _toAbsolute(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('/')) {
      if (File(path).existsSync()) return path;
      final marker = path.indexOf('history/');
      if (marker >= 0) return '${_root.path}/${path.substring(marker)}';
      return path;
    }
    return '${_root.path}/$path';
  }

  /// 把绝对路径收敛为相对路径（以 history/ 为起点），用于持久化。
  String _toRelative(String path) {
    if (path.isEmpty) return path;
    final marker = path.indexOf('history/');
    if (marker >= 0) return path.substring(marker);
    return path;
  }
}

/// 空占位候选，仅用于构造哨兵对象，不参与展示。
final PlantCandidate emptyCandidate =
    PlantCandidate(scientificName: '', commonName: '');

final historyRepositoryProvider = FutureProvider<HistoryRepository>((ref) async {
  return HistoryRepository.open();
});
