import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../core/result.dart';
import '../models/plant.dart';
import 'identification_engine.dart';

/// 混合策略引擎：先跑主引擎，置信度不够时再让复核引擎判一次。
///
/// 目前只在主引擎是视觉大模型时启用 —— 视觉模型泛化强、不用注册别的账号，
/// 但会「硬编」一个品种；Plant.id 这类专用模型慢且要花钱，却是更可靠的物种裁决者。
/// 两者互补：视觉模型负责快，专用模型负责准，用置信度阈值决定把票权转交给后者。
///
/// 复核引擎不可用时（没填 Key / 网络失败 / 超时）都不会让整次识别失败，
/// 只会保留主引擎结果并附一条说明，用户仍能看到相近品种手动核对。
class HybridEngine extends IdentificationEngine {
  const HybridEngine({
    required this.primary,
    required this.fallback,
    this.threshold = 0.65,
  });

  /// 主引擎，负责先给一个答案。
  final IdentificationEngine primary;

  /// 复核引擎，只在主引擎置信度低于 [threshold] 时被调用。
  final IdentificationEngine fallback;

  /// 触发回落所需的置信度门槛，0~1。
  final double threshold;

  @override
  EngineType get type => primary.type;

  /// 复核环节的最长等待时间。超过就放弃回落，别让用户干等。
  static const Duration fallbackTimeout = Duration(seconds: 15);

  @override
  Future<Result<IdentificationResult>> identify(
    Uint8List imageBytes, {
    String? fileName,
  }) async {
    final r = await primary.identify(imageBytes, fileName: fileName);
    if (r.isErr) return r;

    final result = r.value as IdentificationResult;
    if (result.candidates.isEmpty) return r;

    final top = result.candidates.first;
    if (top.confidence >= threshold) {
      return r;
    }

    debugPrint(
      '[HybridEngine] ${primary.type.label} 置信度 ${top.confidencePercent}% '
      '< ${(threshold * 100).round()}%，转交 ${fallback.type.label} 复核',
    );

    final fr = await fallback
        .identify(imageBytes, fileName: fileName)
        .timeout(
          fallbackTimeout,
          onTimeout: () => Result.err(AppException.timeout()),
        );

    // 复核失败绝不拖垮整次识别，保留原结果并说明原因。
    if (fr.isErr) {
      final e = fr.error;
      final reason = e is AppException ? e.message : '未知原因';
      debugPrint('[HybridEngine] 复核失败：$reason');
      return Result.ok(
        result.copyWith(
          fallbackNote:
              '${primary.type.label}置信度只有 ${top.confidencePercent}%，'
              '${fallback.type.label}复核未成功（$reason），结果仅供参考',
          vlmConfidence: top.confidence,
        ),
      );
    }

    final fallbackResult = fr.value as IdentificationResult;
    if (fallbackResult.candidates.isEmpty) {
      return Result.ok(
        result.copyWith(
          fallbackNote:
              '${primary.type.label}置信度只有 ${top.confidencePercent}%，'
              '${fallback.type.label}没能给出有效结果，仍以原判定为准',
          vlmConfidence: top.confidence,
        ),
      );
    }

    final fallbackTop = fallbackResult.candidates.first;
    final adopted = fallbackTop.confidence > top.confidence;

    final merged = <PlantCandidate>[];
    final seen = <String>{};
    void push(PlantCandidate c) {
      final key = c.scientificName.toLowerCase();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      merged.add(c);
    }

    // 复核结果整体在前，主引擎的候选作为备选跟在后面，
    // 这样结果页「可能相近的品种」里仍能看到视觉模型原本的想法。
    for (final c in fallbackResult.candidates) {
      push(c);
    }
    for (final c in result.candidates) {
      push(c);
    }

    final note = adopted
        ? '${primary.type.label}只给出 ${top.confidencePercent}%，'
            '已改用${fallback.type.label}的判定：${fallbackTop.displayName}'
            '（${fallbackTop.confidencePercent}%）'
        : '${primary.type.label}给出 ${top.confidencePercent}%，'
            '${fallback.type.label}复核后把握反而更低'
            '（${fallbackTop.confidencePercent}%），仍以${primary.type.label}结果为准';

    return Result.ok(
      result.copyWith(
        candidates: merged,
        confirmedBy: adopted ? fallback.type : null,
        fallbackNote: note,
        vlmConfidence: top.confidence,
        elapsed: result.elapsed + fallbackResult.elapsed,
      ),
    );
  }
}
