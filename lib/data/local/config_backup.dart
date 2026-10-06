import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

/// 配置备份文件的读写。
///
/// 换手机、重装、给家人装的时候，不用把 Plant.id / Pl@ntNet / 大模型
/// 的 Key 再敲一遍：在旧设备「导出配置」拿到一个 JSON，在新设备「导入配置」即可。
///
/// 文件是明文 JSON，会包含 API Key —— 所以导出走系统分享面板，
/// 用户可以自己决定发到哪里（微信文件传输助手、邮件、网盘），不要发到公开群。
class ConfigBackup {
  ConfigBackup._();

  static const String formatId = 'floralens.config';
  static const int version = 1;
  static const String fileExtension = 'json';

  static String fileNameFor(DateTime at) {
    String p(int n) => n.toString().padLeft(2, '0');
    return 'floralens-config-${at.year}${p(at.month)}${p(at.day)}'
        '-${p(at.hour)}${p(at.minute)}.$fileExtension';
  }

  /// 生成备份文本。pretty print 便于人眼核对 Key 是否写全。
  static String encode(
    AppSettings settings, {
    required String appVersion,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final doc = <String, dynamic>{
      'format': formatId,
      'version': version,
      'appVersion': appVersion,
      'exportedAt': now.toIso8601String(),
      'settings': settings.toJson(),
    };
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  static ConfigBackupDecode decode(String text) {
    if (text.trim().isEmpty) {
      return const ConfigBackupDecode.error('文件内容是空的');
    }

    Object? root;
    try {
      root = jsonDecode(text);
    } catch (_) {
      return const ConfigBackupDecode.error('不是合法的 JSON 文件');
    }
    if (root is! Map<String, dynamic>) {
      return const ConfigBackupDecode.error('文件格式不对，这不是花识导出的配置');
    }
    if (root['format'] != formatId) {
      return const ConfigBackupDecode.error('这不是花识的配置备份文件');
    }

    final rawVersion = root['version'];
    if (rawVersion is! int || rawVersion > version) {
      return ConfigBackupDecode.error(
        '这个备份来自更新版本的花识（v${rawVersion ?? '?'}），当前版本可能不认识',
      );
    }

    final raw = root['settings'];
    if (raw is! Map<String, dynamic>) {
      return const ConfigBackupDecode.error('备份里缺少配置内容');
    }

    AppSettings settings;
    try {
      settings = AppSettings.fromJson(raw);
    } catch (e) {
      return ConfigBackupDecode.error('配置解析失败：$e');
    }

    return ConfigBackupDecode.ok(settings);
  }

  /// 落到临时目录，随后交给系统分享面板发出去。
  static Future<String> writeToTemp(String text, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text, flush: true);
    return file.path;
  }
}

/// [ConfigBackup.decode] 的结果：成功给配置，失败给一句话原因。
class ConfigBackupDecode {
  const ConfigBackupDecode.ok(this.settings) : error = null;

  const ConfigBackupDecode.error(this.error) : settings = null;

  final AppSettings? settings;
  final String? error;

  bool get isOk => settings != null;
}
