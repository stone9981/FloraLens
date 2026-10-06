import '../data/models/plant.dart';
import '../data/models/plant_profile.dart';

/// 百度百科跳转辅助。
///
/// 花名可能来自中文常用名，也可能回落到拉丁学名；百科词条以中文名最稳，
/// 因此先做清洗（去掉括号里的学名注释、首尾空白），再拼 item 链接。
/// 词条不存在时百科会显示「没有找到」，所以同时提供站内搜索链接兜底。
class Baike {
  Baike._();

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

  /// 取最适合百科检索的名字：优先中文常用名，回落档案标题，最后学名。
  static String bestName(PlantCandidate candidate, PlantProfile? profile) {
    if (candidate.commonName.isNotEmpty) return candidate.commonName;
    if (profile != null && profile.title.isNotEmpty) return profile.title;
    return candidate.scientificName;
  }

  /// 百科词条链接（App 内 WebView 打开，看完关闭即返回）。
  ///
  /// 注意：[Uri.https] 的 path 参数是「未编码」路径，Dart 会自行编码一次。
  /// 若先 [Uri.encodeComponent] 再传入，会把已编码的 `%` 再次编码成 `%25`，
  /// 导致链接变成 `%25E9%25BE...` 这种双重编码、百科无法识别。
  /// 因此这里直接传原始中文名，由 Uri 统一编码一次即可（中文用户即为 %E9%BE...）。
  static Uri itemUrl(String name) {
    final n = cleanName(name);
    return Uri.https(
      'baike.baidu.com',
      '/item/$n',
      <String, String>{'fromModule': 'lemma_search-box'},
    );
  }

  /// 词条不存在时的兜底：百度百科站内搜索链接。
  static Uri searchUrl(String name) {
    final n = cleanName(name);
    return Uri.https(
      'baike.baidu.com',
      '/search',
      <String, String>{'word': n, 'pn': '0'},
    );
  }
}
