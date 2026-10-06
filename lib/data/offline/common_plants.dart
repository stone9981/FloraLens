import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/plant_profile.dart';

/// 内置常见花卉基础档案。
///
/// 两个用途：
/// 1. 网络/额度都不可用时的降级内容，保证 App 永远"有话说"；
/// 2. 识别结果不对时，用户可以手动检索并纠正品种。
class CommonPlant {
  const CommonPlant({
    required this.scientificName,
    required this.commonName,
    this.family = '',
    this.genus = '',
    this.language = '',
    this.intro = '',
    this.bloom = '',
    this.origin = '',
    this.poem = '',
    this.tags = const <String>[],
  });

  final String scientificName;
  final String commonName;
  final String family;
  final String genus;
  final String language;
  final String intro;
  final String bloom;
  final String origin;
  final String poem;
  final List<String> tags;

  bool matches(String query) {
    if (query.trim().isEmpty) return false;
    final q = query.toLowerCase();
    return scientificName.toLowerCase().contains(q) ||
        commonName.toLowerCase().contains(q) ||
        family.toLowerCase().contains(q) ||
        genus.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q));
  }

  PlantProfile toProfile() {
    return PlantProfile(
      scientificName: scientificName,
      title: commonName,
      latinName: scientificName,
      summary: intro.isNotEmpty ? intro : '暂无更多资料',
      story: intro,
      language: language,
      bloomTime: bloom,
      origin: origin,
      careTips: const <String>[],
      tags: tags,
      poemLine: poem.isEmpty ? null : poem,
      generatedBy: '内置词典',
      generatedAt: DateTime.now(),
      isOffline: true,
    );
  }

  factory CommonPlant.fromJson(Map<String, dynamic> json) => CommonPlant(
        scientificName: (json['s'] as String?) ?? '',
        commonName: (json['c'] as String?) ?? '',
        family: (json['f'] as String?) ?? '',
        genus: (json['g'] as String?) ?? '',
        language: (json['l'] as String?) ?? '',
        intro: (json['d'] as String?) ?? '',
        bloom: (json['b'] as String?) ?? '',
        origin: (json['o'] as String?) ?? '',
        poem: (json['p'] as String?) ?? '',
        tags: (json['t'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const <String>[],
      );
}

/// 单例词典，App 启动时异步预热一次即可。
class CommonPlantLibrary {
  CommonPlantLibrary._(this._plants);

  static const String _asset = 'assets/data/common_plants.json';

  final List<CommonPlant> _plants;

  static CommonPlantLibrary? _instance;

  static Future<CommonPlantLibrary> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString(_asset);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = (map['plants'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(CommonPlant.fromJson)
          .where((p) => p.scientificName.isNotEmpty)
          .toList();
      return _instance = CommonPlantLibrary._(list);
    } catch (e) {
      debugPrint('[CommonPlantLibrary] 载入失败: $e');
      return _instance = CommonPlantLibrary._(const <CommonPlant>[]);
    }
  }

  int get count => _plants.length;

  /// 按中文名/学名/科属/标签做模糊检索。
  List<CommonPlant> search(String query) {
    if (query.trim().isEmpty) return List<CommonPlant>.unmodifiable(_plants);
    final hits = _plants.where((p) => p.matches(query)).toList();
    hits.sort((a, b) {
      final aq = a.commonName.contains(query) ? 0 : 1;
      final bq = b.commonName.contains(query) ? 0 : 1;
      return aq.compareTo(bq);
    });
    return List<CommonPlant>.unmodifiable(hits);
  }

  /// 按学名精确命中，用于离线兜底。
  CommonPlant? byScientificName(String scientificName) {
    final target = scientificName.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final p in _plants) {
      if (p.scientificName.toLowerCase() == target) return p;
    }
    return null;
  }

  /// 按中文名命中。
  CommonPlant? byCommonName(String name) {
    final target = name.trim().toLowerCase();
    if (target.isEmpty) return null;
    for (final p in _plants) {
      if (p.commonName.toLowerCase() == target) return p;
    }
    return null;
  }
}
