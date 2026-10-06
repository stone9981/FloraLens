import 'dart:convert';

import '../models/history_item.dart';

/// 历史记录导出。
///
/// 在「我的记录」里多选若干条后，导出成一个 JSON 文件：
/// 含每条记录的完整字段，以及它在列表里的顺序索引（index），
/// 方便日后按原来的顺序排列或导入。图片仍留在 App 内，不打包进 JSON，
/// 以免文件过大；需要带图备份时再扩展。
class HistoryBackup {
  HistoryBackup._();

  static const String formatId = 'floralens.history';
  static const int version = 1;
  static const String fileExtension = 'json';

  static String fileNameFor(DateTime at) {
    String p(int n) => n.toString().padLeft(2, '0');
    return 'floralens-history-${at.year}${p(at.month)}${p(at.day)}'
        '-${p(at.hour)}${p(at.minute)}.$fileExtension';
  }

  /// 生成导出文本。
  ///
  /// [items] 应是「已选中的记录，且保持列表中的先后次序」，
  /// 这样每条自带的 index 才和界面顺序一致。
  static String encode(
    List<HistoryItem> items, {
    required String appVersion,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final entries = items.asMap().entries.map((e) => <String, dynamic>{
          'index': e.key,
          'item': e.value.toJson(),
        }).toList();
    final doc = <String, dynamic>{
      'format': formatId,
      'version': version,
      'appVersion': appVersion,
      'exportedAt': now.toIso8601String(),
      'count': items.length,
      'items': entries,
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }
}
