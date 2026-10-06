/// 大模型生成的植物档案。
///
/// 这一层刻意与识别引擎解耦：
/// 识别只负责给出拉丁学名，文案、花语、养护建议全部由大模型二次加工，
/// 好处是任何引擎都能得到统一水准的中文内容。
class PlantProfile {
  const PlantProfile({
    required this.scientificName,
    required this.title,
    this.latinName,
    this.summary = '',
    this.story = '',
    this.language = '',
    this.bloomTime = '',
    this.origin = '',
    this.careTips = const <String>[],
    this.tags = const <String>[],
    this.toxicityNote,
    this.poemLine,
    this.generatedBy = '',
    this.generatedAt,
    this.isOffline = false,
  });

  final String scientificName;
  final String title;
  final String? latinName;
  final String summary;
  final String story;
  final String language;
  final String bloomTime;
  final String origin;
  final List<String> careTips;
  final List<String> tags;
  final String? toxicityNote;

  /// 一句适配的古诗词，用于分享卡片增加质感。
  final String? poemLine;

  final String generatedBy;
  final DateTime? generatedAt;

  /// 是否来自本地兜底数据（未联网时的降级内容）。
  final bool isOffline;

  bool get isEmpty => summary.isEmpty && story.isEmpty && careTips.isEmpty;

  PlantProfile copyWith({
    String? summary,
    String? story,
    String? poemLine,
  }) {
    return PlantProfile(
      scientificName: scientificName,
      title: title,
      latinName: latinName,
      summary: summary ?? this.summary,
      story: story ?? this.story,
      language: language,
      bloomTime: bloomTime,
      origin: origin,
      careTips: careTips,
      tags: tags,
      toxicityNote: toxicityNote,
      poemLine: poemLine ?? this.poemLine,
      generatedBy: generatedBy,
      generatedAt: generatedAt ?? DateTime.now(),
      isOffline: isOffline,
    );
  }

  factory PlantProfile.fromJson(Map<String, dynamic> json) {
    return PlantProfile(
      scientificName: (json['scientificName'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      latinName: json['latinName'] as String?,
      summary: (json['summary'] as String?) ?? '',
      story: (json['story'] as String?) ?? '',
      language: (json['language'] as String?) ?? '',
      bloomTime: (json['bloomTime'] as String?) ?? '',
      origin: (json['origin'] as String?) ?? '',
      careTips: (json['careTips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const <String>[],
      toxicityNote: json['toxicityNote'] as String?,
      poemLine: json['poemLine'] as String?,
      generatedBy: (json['generatedBy'] as String?) ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String)
          : null,
      isOffline: (json['isOffline'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scientificName': scientificName,
        'title': title,
        'latinName': latinName,
        'summary': summary,
        'story': story,
        'language': language,
        'bloomTime': bloomTime,
        'origin': origin,
        'careTips': careTips,
        'tags': tags,
        'toxicityNote': toxicityNote,
        'poemLine': poemLine,
        'generatedBy': generatedBy,
        'generatedAt': generatedAt?.toIso8601String(),
        'isOffline': isOffline,
      };

  /// 离线兜底档案：没有任何 API 时也能保证用户拿得到内容。
  factory PlantProfile.offline({
    required String scientificName,
    required String title,
    String? summary,
  }) {
    return PlantProfile(
      scientificName: scientificName,
      title: title,
      summary: summary ?? '暂无在线资料，以下为本地基础档案。',
      story: '',
      generatedBy: 'offline',
      generatedAt: DateTime.now(),
      isOffline: true,
    );
  }
}
