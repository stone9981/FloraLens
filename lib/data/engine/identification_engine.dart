import 'dart:convert';
import 'dart:typed_data';

import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import '../models/app_settings.dart';
import '../models/plant.dart';
import 'engines.dart';
import 'hybrid_engine.dart';

/// 识别引擎统一抽象。
///
/// 新增一家服务商时，只需要实现这个接口并注册进 [EngineFactory]，
/// UI 与其它业务逻辑完全不需要改动。
abstract class IdentificationEngine {
  const IdentificationEngine();

  EngineType get type;

  /// 入参是已经压缩好的 JPEG 字节，引擎不关心图片从哪来。
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  });
}

/// 引擎构造参数：从设置里取出对应凭据。
class EngineCredentials {
  const EngineCredentials({required this.apiKey, this.endpoint});

  final String apiKey;
  final String? endpoint;

  bool get isEmpty => apiKey.trim().isEmpty && (endpoint ?? '').trim().isEmpty;
}

/// 按当前设置创建引擎实例。
class EngineFactory {
  EngineFactory._();

  static IdentificationEngine create(
    AppSettings settings,
    AppLocalizations l10n,
  ) {
    final base = _createRaw(settings, l10n);

    // 视觉大模型可能「硬编」品种，置信度不够时让专用模型复核一次。
    final fallbackType = settings.effectiveFallbackEngine;
    final fallback = fallbackType == null
        ? null
        : _createFallback(settings, fallbackType, l10n);
    if (fallback == null) return base;

    return HybridEngine(
      primary: base,
      fallback: fallback,
      threshold: settings.hybridThreshold,
      l10n: l10n,
    );
  }

  static IdentificationEngine _createRaw(AppSettings settings, AppLocalizations l10n) {
    switch (settings.engine) {
      case EngineType.plantId:
        return PlantIdEngine(apiKey: settings.plantIdKey);
      case EngineType.plantNet:
        return PlantNetEngine(apiKey: settings.plantNetKey);
      case EngineType.kindwise:
        return KindwiseEngine(apiKey: settings.kindwiseKey);
      case EngineType.customHttp:
        return CustomHttpEngine(
          endpoint: settings.customEndpoint,
          apiKey: settings.customApiKey,
        );
      case EngineType.vlm:
        // 视觉模型与文案模型共用端点与 Key，只是模型名不同。
        return VlmEngine(config: settings.visionLlmConfig, l10n: l10n);
    }
  }

  /// 按类型构造复核引擎；[EngineType.vlm] 不能给自己复核，返回 null。
  static IdentificationEngine? _createFallback(
    AppSettings settings,
    EngineType type,
    AppLocalizations l10n,
  ) {
    switch (type) {
      case EngineType.plantId:
        return PlantIdEngine(apiKey: settings.plantIdKey);
      case EngineType.plantNet:
        return PlantNetEngine(apiKey: settings.plantNetKey);
      case EngineType.kindwise:
        return KindwiseEngine(apiKey: settings.kindwiseKey);
      case EngineType.customHttp:
        return CustomHttpEngine(
          endpoint: settings.customEndpoint,
          apiKey: settings.customApiKey,
        );
      case EngineType.vlm:
        return null;
    }
  }
}

/// 各引擎共用的小工具。
mixin EngineParsing {
  /// 生成 Plant.id / Kindwise 需要的 data URI。
  String toDataUri(Uint8List bytes) =>
      'data:image/jpeg;base64,${base64Encode(bytes)}';

  /// 归一化置信度：不同服务商有的给 0~1，有的给 0~100。
  double normalizeConfidence(num? value) {
    if (value == null) return 0;
    final v = value.toDouble();
    if (v > 1) {
      return (v / 100).clamp(0.0, 1.0);
    }
    return v.clamp(0.0, 1.0);
  }

  List<String> toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(8)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return <String>[value.trim()];
    }
    return const <String>[];
  }

  String? firstString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is List && value.isNotEmpty) return value.first.toString().trim();
    if (value is Map) {
      final n = value['name'] ?? value['scientificName'] ?? value['value'];
      if (n != null) return n.toString().trim();
    }
    return null;
  }
}
