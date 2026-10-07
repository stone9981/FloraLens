import '../core/baike.dart';
import '../data/models/history_item.dart';
import '../data/models/plant.dart';
import '../data/models/plant_profile.dart';
import '../l10n/app_localizations.dart';

/// 把识别结果页的全部内容拼成一份 Markdown，便于复制到备忘录 / 公众号 / Obsidian。
///
/// 关键：百度百科链接原样写入，用户粘贴后即可肉眼核对链接是否正确、
/// 词条名是否匹配；词条缺失时附上站内搜索链接兜底。
String buildResultMarkdown({
  required AppLocalizations l10n,
  required PlantCandidate candidate,
  required PlantProfile? profile,
  required IdentifySource source,
  required DateTime date,
}) {
  final b = StringBuffer();
  final title = (profile?.title.isNotEmpty ?? false)
      ? profile!.title
      : candidate.displayName;

  b.writeln('# $title');
  b.writeln();

  final meta = <String>[];
  if (candidate.scientificName.isNotEmpty)
    meta.add('*${candidate.scientificName}*');
  final fg = candidate.familyGenus;
  if (fg.isNotEmpty) meta.add(fg);
  if (meta.isNotEmpty) {
    b.writeln('> ${meta.join(' · ')}');
    b.writeln(
      '> ${l10n.tr('mdConfidence')}：${candidate.confidencePercent}% · '
      '${l10n.tr('mdSource')}：${l10n.source(source.id)}',
    );
    b.writeln();
  }

  final p = profile;
  if (p != null && p.summary.isNotEmpty) {
    b.writeln('## ${l10n.tr('mdIntro')}');
    b.writeln();
    b.writeln(p.story.isNotEmpty ? p.story : p.summary);
    b.writeln();
  }
  if (p != null && p.language.isNotEmpty) {
    b.writeln('## ${l10n.tr('mdFlowerLanguage')}');
    b.writeln();
    b.writeln(p.language);
    b.writeln();
  }
  if (p != null && p.careTips.isNotEmpty) {
    b.writeln('## ${l10n.tr('mdCare')}');
    b.writeln();
    for (final t in p.careTips) {
      b.writeln('- $t');
    }
    b.writeln();
  }

  final facts = <String>[];
  if (p != null && p.bloomTime.isNotEmpty)
    facts.add('- ${l10n.tr('mdBloom')}：${p.bloomTime}');
  if (p != null && p.origin.isNotEmpty)
    facts.add('- ${l10n.tr('mdOrigin')}：${p.origin}');
  if (candidate.familyGenus.isNotEmpty)
    facts.add('- ${l10n.tr('mdFamily')}：${candidate.familyGenus}');
  if (candidate.aliases.isNotEmpty)
    facts.add('- ${l10n.tr('mdAlias')}：${candidate.aliases.join('、')}');
  if (facts.isNotEmpty) {
    b.writeln('## ${l10n.tr('mdFacts')}');
    b.writeln();
    b.writeln(facts.join('\n'));
    b.writeln();
  }

  final baikeName = Baike.bestName(candidate, profile);
  final item = Baike.itemUrl(baikeName).toString();
  final search = Baike.searchUrl(baikeName).toString();
  b.writeln('## ${l10n.tr('mdFurther')}');
  b.writeln();
  b.writeln('- ${l10n.tr('baikeLink')}：$item');
  b.writeln('- ${l10n.tr('baikeSearch')}：$search');
  b.writeln();

  final d =
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  b.writeln('---');
  b.writeln('${l10n.tr('mdGeneratedBy')} · $d');

  return b.toString();
}
