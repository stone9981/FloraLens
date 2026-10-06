import '../core/baike.dart';
import '../data/models/history_item.dart';
import '../data/models/plant.dart';
import '../data/models/plant_profile.dart';

/// 把识别结果页的全部内容拼成一份 Markdown，便于复制到备忘录 / 公众号 / Obsidian。
///
/// 关键：百度百科链接原样写入，用户粘贴后即可肉眼核对链接是否正确、
/// 词条名是否匹配；词条缺失时附上站内搜索链接兜底。
String buildResultMarkdown({
  required PlantCandidate candidate,
  required PlantProfile? profile,
  required IdentifySource source,
  required DateTime date,
}) {
  final b = StringBuffer();
  final title =
      (profile?.title.isNotEmpty ?? false) ? profile!.title : candidate.displayName;

  b.writeln('# $title');
  b.writeln();

  final meta = <String>[];
  if (candidate.scientificName.isNotEmpty) meta.add('*${candidate.scientificName}*');
  final fg = candidate.familyGenus;
  if (fg.isNotEmpty) meta.add(fg);
  if (meta.isNotEmpty) {
    b.writeln('> ${meta.join(' · ')}');
    b.writeln('> 置信度：${candidate.confidencePercent}% · 来源：${source.label}');
    b.writeln();
  }

  final p = profile;
  if (p != null && p.summary.isNotEmpty) {
    b.writeln('## 简介');
    b.writeln();
    b.writeln(p.story.isNotEmpty ? p.story : p.summary);
    b.writeln();
  }
  if (p != null && p.language.isNotEmpty) {
    b.writeln('## 花语');
    b.writeln();
    b.writeln(p.language);
    b.writeln();
  }
  if (p != null && p.careTips.isNotEmpty) {
    b.writeln('## 养护要点');
    b.writeln();
    for (final t in p.careTips) {
      b.writeln('- $t');
    }
    b.writeln();
  }

  final facts = <String>[];
  if (p != null && p.bloomTime.isNotEmpty) facts.add('- 花期：${p.bloomTime}');
  if (p != null && p.origin.isNotEmpty) facts.add('- 产地：${p.origin}');
  if (candidate.familyGenus.isNotEmpty) facts.add('- 科属：${candidate.familyGenus}');
  if (candidate.aliases.isNotEmpty) facts.add('- 别名：${candidate.aliases.join('、')}');
  if (facts.isNotEmpty) {
    b.writeln('## 资料卡');
    b.writeln();
    b.writeln(facts.join('\n'));
    b.writeln();
  }

  final baikeName = Baike.bestName(candidate, profile);
  final item = Baike.itemUrl(baikeName).toString();
  final search = Baike.searchUrl(baikeName).toString();
  b.writeln('## 延伸阅读');
  b.writeln();
  b.writeln('- 百度百科：$item');
  b.writeln('- 百科搜索（词条缺失时用）：$search');
  b.writeln();

  final d =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  b.writeln('---');
  b.writeln('由 花识 FloraLens 生成 · $d');

  return b.toString();
}
