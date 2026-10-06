/// 支持的植物识别引擎。
enum EngineType {
  plantId('plant_id', 'Plant.id', 'https://api.plant.id'),
  plantNet('plantnet', 'Pl@ntNet', 'https://my-api.plantnet.org'),
  kindwise('kindwise', 'Kindwise', 'https://plant.id/api'),
  customHttp('custom_http', '自建服务', ''),
  vlm('vlm', '视觉大模型', '');

  const EngineType(this.id, this.label, this.defaultEndpoint);

  final String id;
  final String label;
  final String defaultEndpoint;

  bool get needsApiKey => this != EngineType.customHttp || true;

  static EngineType fromId(String? id) {
    return EngineType.values.firstWhere(
      (e) => e.id == id,
      orElse: () => EngineType.plantId,
    );
  }
}

/// 单个候选植物。
class PlantCandidate {
  const PlantCandidate({
    required this.scientificName,
    required this.commonName,
    this.aliases = const <String>[],
    this.family,
    this.genus,
    this.confidence = 0,
    this.wikiUrl,
    this.imageUrl,
    this.description,
    this.rawScore,
  });

  /// 拉丁学名，全球唯一，用于缓存与 LLM 检索。
  final String scientificName;

  /// 中文常用名。
  final String commonName;

  final List<String> aliases;
  final String? family;
  final String? genus;

  /// 0~1 之间的置信度，不同引擎含义略有差异，仅用于排序与展示。
  final double confidence;
  final String? wikiUrl;
  final String? imageUrl;
  final String? description;

  /// 引擎返回的原始分值（百分比制），保留用于调试。
  final num? rawScore;

  String get displayName => commonName.isNotEmpty ? commonName : scientificName;

  String get familyGenus {
    final buf = <String>[];
    if (family != null && family!.isNotEmpty) buf.add(family!);
    if (genus != null && genus!.isNotEmpty) buf.add(genus!);
    return buf.join(' · ');
  }

  int get confidencePercent => (confidence * 100).round().clamp(0, 100);

  factory PlantCandidate.fromJson(Map<String, dynamic> json) {
    return PlantCandidate(
      scientificName: (json['scientificName'] as String?) ?? '',
      commonName: (json['commonName'] as String?) ?? '',
      aliases: (json['aliases'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      family: json['family'] as String?,
      genus: json['genus'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      wikiUrl: json['wikiUrl'] as String?,
      imageUrl: json['imageUrl'] as String?,
      description: json['description'] as String?,
      rawScore: json['rawScore'] as num?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'scientificName': scientificName,
        'commonName': commonName,
        'aliases': aliases,
        'family': family,
        'genus': genus,
        'confidence': confidence,
        'wikiUrl': wikiUrl,
        'imageUrl': imageUrl,
        'description': description,
        'rawScore': rawScore,
      };

  PlantCandidate copyWith({
    String? scientificName,
    String? commonName,
    List<String>? aliases,
    String? family,
    String? genus,
    double? confidence,
    String? wikiUrl,
    String? imageUrl,
    String? description,
  }) {
    return PlantCandidate(
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      aliases: aliases ?? this.aliases,
      family: family ?? this.family,
      genus: genus ?? this.genus,
      confidence: confidence ?? this.confidence,
      wikiUrl: wikiUrl ?? this.wikiUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      rawScore: rawScore,
    );
  }
}

/// 一次识别会话的完整结果。
class IdentificationResult {
  const IdentificationResult({
    required this.candidates,
    required this.engine,
    required this.identifiedAt,
    this.elapsed = Duration.zero,
    this.rawResponseHash,
    this.confirmedBy,
    this.fallbackNote,
    this.vlmConfidence,
  });

  final List<PlantCandidate> candidates;
  final EngineType engine;
  final DateTime identifiedAt;
  final Duration elapsed;

  /// 原始响应摘要，便于问题溯源（不含图片）。
  final String? rawResponseHash;

  /// 混合策略：最终为榜首结果背书的服务商。
  ///
  /// 与 [engine] 不同即表示刚做过复核（例如 engine=vlm，confirmedBy=plantId）。
  final EngineType? confirmedBy;

  /// 混合策略触发原因；null 表示本次没走回落流程。
  final String? fallbackNote;

  /// 触发回落时视觉模型给出的最高置信度，用于结果页还原判断依据。
  final double? vlmConfidence;

  PlantCandidate? get top => candidates.isEmpty ? null : candidates.first;

  bool get isEmpty => candidates.isEmpty;

  /// 是否发生过复核，且最终采信了别的引擎。
  bool get wasRevalidated =>
      confirmedBy != null && confirmedBy != engine && confirmedBy != null;

  IdentificationResult copyWith({
    List<PlantCandidate>? candidates,
    EngineType? engine,
    DateTime? identifiedAt,
    Duration? elapsed,
    String? rawResponseHash,
    EngineType? confirmedBy,
    String? fallbackNote,
    double? vlmConfidence,
    bool clearFallbackNote = false,
  }) {
    return IdentificationResult(
      candidates: candidates ?? this.candidates,
      engine: engine ?? this.engine,
      identifiedAt: identifiedAt ?? this.identifiedAt,
      elapsed: elapsed ?? this.elapsed,
      rawResponseHash: rawResponseHash ?? this.rawResponseHash,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      fallbackNote: clearFallbackNote ? null : (fallbackNote ?? this.fallbackNote),
      vlmConfidence: vlmConfidence ?? this.vlmConfidence,
    );
  }

  factory IdentificationResult.fromJson(Map<String, dynamic> json) {
    return IdentificationResult(
      candidates: (json['candidates'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => PlantCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      engine: EngineType.fromId(json['engine'] as String?),
      identifiedAt: DateTime.tryParse(json['identifiedAt'] as String? ?? '') ??
          DateTime.now(),
      elapsed: Duration(milliseconds: (json['elapsedMs'] as num?)?.toInt() ?? 0),
      rawResponseHash: json['rawResponseHash'] as String?,
      confirmedBy: _engineFromIdOrNull(json['confirmedBy'] as String?),
      fallbackNote: json['fallbackNote'] as String?,
      vlmConfidence: (json['vlmConfidence'] as num?)?.toDouble(),
    );
  }

  static EngineType? _engineFromIdOrNull(String? id) {
    if (id == null || id.isEmpty) return null;
    return EngineType.fromId(id);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'candidates': candidates.map((e) => e.toJson()).toList(),
        'engine': engine.id,
        'identifiedAt': identifiedAt.toIso8601String(),
        'elapsedMs': elapsed.inMilliseconds,
        'rawResponseHash': rawResponseHash,
        'confirmedBy': confirmedBy?.id,
        'fallbackNote': fallbackNote,
        'vlmConfidence': vlmConfidence,
      };
}
