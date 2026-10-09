import 'dart:ui';

import '../data/models/plant.dart';
import '../data/models/plant_profile.dart';

/// 外部百科跳转辅助。
///
/// 链接随界面语言切换：
/// - 中文（zh）：百度百科，中文俗名命中率最高、最稳；
/// - 英文（en）：维基百科（en.wikipedia.org），优先用识别引擎已返回的精确链接
///   [PlantCandidate.wikiUrl]（plant.id 等会直接给维基条目 URL），缺失时按学名兜底。
class Baike {
  Baike._();

  /// 当前是否英文界面。
  static bool _isEnglish(Locale? locale) => locale?.languageCode == 'en';

  /// 清洗花名：去掉括号注释与首尾空白。
  /// 「龟背竹（Monstera deliciosa）」→「龟背竹」。
  static String cleanName(String name) {
    var s = name.trim();
    if (s.isEmpty) return s;
    final lp = s.indexOf('（');
    if (lp != -1) s = s.substring(0, lp);
    final lpe = s.indexOf('(');
    if (lpe != -1) s = s.substring(0, lpe);
    return s.trim();
  }

  /// 取最适合检索的名字：
  /// 英文优先学名（维基英文条目以学名最稳），回落档案标题，最后常用名；
  /// 中文优先常用名，回落档案标题，最后学名。
  static String bestName(
    PlantCandidate candidate,
    PlantProfile? profile, {
    Locale? locale,
  }) {
    if (_isEnglish(locale)) {
      if (candidate.scientificName.isNotEmpty) return candidate.scientificName;
      if (profile != null && profile.title.isNotEmpty) return profile.title;
      return candidate.commonName;
    }
    if (candidate.commonName.isNotEmpty) return candidate.commonName;
    if (profile != null && profile.title.isNotEmpty) return profile.title;
    return candidate.scientificName;
  }

  /// 实际跳转链接：英文优先 [PlantCandidate.wikiUrl]，中文走百度百科。
  static Uri jumpUri(
    PlantCandidate candidate,
    PlantProfile? profile, {
    Locale? locale,
  }) {
    if (_isEnglish(locale)) {
      final w = candidate.wikiUrl;
      if (w != null && w.trim().isNotEmpty) return Uri.parse(w.trim());
    }
    return itemUrl(bestName(candidate, profile, locale: locale), locale: locale);
  }

  /// 百科词条链接（App 内 WebView 打开，看完关闭即返回）。
  ///
  /// 注意：[Uri.https] 的 path 参数是「未编码」路径，Dart 会自行编码一次。
  /// 若先 [Uri.encodeComponent] 再传入，会把已编码的 `%` 再次编码成 `%25`，
  /// 导致链接变成 `%25E9%25BE...` 这种双重编码、百科无法识别。
  /// 因此这里直接传原始名，由 Uri 统一编码一次即可（中文用户即为 %E9%BE...）。
  static Uri itemUrl(String name, {Locale? locale}) {
    final n = cleanName(name);
    if (_isEnglish(locale)) {
      final title = n.replaceAll(' ', '_');
      return Uri.https('en.wikipedia.org', '/wiki/$title');
    }
    return Uri.https(
      'baike.baidu.com',
      '/item/$n',
      <String, String>{'fromModule': 'lemma_search-box'},
    );
  }

  /// 词条不存在时的兜底搜索链接。
  static Uri searchUrl(String name, {Locale? locale}) {
    final n = cleanName(name);
    if (_isEnglish(locale)) {
      return Uri.https('en.wikipedia.org', '/wiki/Special:Search',
          <String, String>{'search': n});
    }
    return Uri.https(
      'baike.baidu.com',
      '/search',
      <String, String>{'word': n, 'pn': '0'},
    );
  }
}
