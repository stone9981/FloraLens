import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/result.dart';
import '../data/local/history_repository.dart';
import '../data/local/settings_store.dart';
import '../data/models/history_item.dart';
import '../data/models/plant.dart';
import '../data/models/plant_profile.dart';
import '../services/image_service.dart';
import 'app_providers.dart';
import 'history_provider.dart';

/// 识别流程所处阶段。
enum IdentifyPhase { idle, identifying, enriching, success, failure }

/// 一次识别会话的完整状态。
class IdentifyState {
  const IdentifyState({
    this.phase = IdentifyPhase.idle,
    this.imagePath,
    this.result,
    this.profile,
    this.errorMessage,
    this.historyId,
    this.profileFromCache = false,
    this.source = IdentifySource.camera,
  });

  final IdentifyPhase phase;
  final String? imagePath;
  final IdentificationResult? result;
  final PlantProfile? profile;
  final String? errorMessage;
  final String? historyId;
  final IdentifySource source;

  /// 档案是否为离线兜底内容（用于 UI 上提示"当前为离线资料"）。
  final bool profileFromCache;

  bool get isBusy =>
      phase == IdentifyPhase.identifying || phase == IdentifyPhase.enriching;

  PlantCandidate? get top => result?.top;

  IdentifyState copyWith({
    IdentifyPhase? phase,
    String? imagePath,
    IdentificationResult? result,
    PlantProfile? profile,
    String? errorMessage,
    String? historyId,
    bool? profileFromCache,
    IdentifySource? source,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return IdentifyState(
      phase: phase ?? this.phase,
      imagePath: imagePath ?? this.imagePath,
      result: result ?? this.result,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      historyId: historyId ?? this.historyId,
      profileFromCache: profileFromCache ?? this.profileFromCache,
      source: source ?? this.source,
    );
  }
}

/// 识别主流程编排：压缩 → 识别 → 生成档案 → 落历史。
class IdentificationController extends StateNotifier<IdentifyState> {
  IdentificationController(this._ref) : super(const IdentifyState());

  final Ref _ref;

  /// 入口：传入本地图片路径，走完整流程。
  ///
  /// [source] 记进历史条目，方便在「我的记录」里分清拍照与相册选图。
  Future<void> identify(
    String imagePath, {
    IdentifySource source = IdentifySource.camera,
  }) async {
    final settings = _ref.read(settingsProvider);
    final l = _ref.read(appLocalizationsProvider);
    if (!settings.engineReady) {
      state = state.copyWith(
        phase: IdentifyPhase.failure,
        imagePath: imagePath,
        errorMessage: l.tr('engineNotConfigured'),
      );
      return;
    }

    state = state.copyWith(
      phase: IdentifyPhase.identifying,
      imagePath: imagePath,
      source: source,
      clearError: true,
      clearProfile: true,
      profileFromCache: false,
    );

    // 1) 压缩后上传
    final rawBytes = await ImageService.readBytes(imagePath);
    final uploadBytes = await ImageService.compressForUpload(rawBytes);

    final engine = _ref.read(identificationEngineProvider);
    final r = await engine.identify(uploadBytes, fileName: 'flower.jpg');

    final err = r.error;
    if (err != null) {
      state = state.copyWith(
        phase: IdentifyPhase.failure,
        errorMessage: err is AppException ? err.message : l.tr('recogFailed'),
      );
      return;
    }

    final result = r.value as IdentificationResult;
    if (result.candidates.isEmpty) {
      state = state.copyWith(
        phase: IdentifyPhase.failure,
        errorMessage: l.tr('noFlower'),
      );
      return;
    }

    // 2) 图片落盘到受管目录，避免被系统清理掉相册那一路的外部路径
    final historyId = ImageService.newId();
    final storedPath = await _persistImage(imagePath, historyId);

    state = state.copyWith(
      result: result,
      historyId: historyId,
      imagePath: storedPath,
      phase: IdentifyPhase.enriching,
    );

    final item = HistoryItem(
      id: historyId,
      createdAt: DateTime.now(),
      imagePath: storedPath,
      candidate: result.top as PlantCandidate,
      engineId: result.engine.id,
      source: source,
    );
    await _ref.read(historyProvider.notifier).save(item);

    // 3) 生成植物档案（失败不影响主流程）
    await _generateProfile(item);
  }

  /// 把原始图片搬到应用自带的目录，并返回一个长期有效的路径。
  ///
  /// 相册选图给的路径在系统缓存里，随时可能被回收，历史缩略图就变成黑块；
  /// 所以这里优先按「读字节再写文件」处理，任何可读的来源都能落盘成功。
  Future<String> _persistImage(String sourcePath, String id) async {
    try {
      final bytes = await ImageService.readBytes(sourcePath);
      final target = await ImageService.writeManaged(id, bytes);
      if (target != null) return target;
    } catch (e) {
      debugPrint('[IdentificationController] 按字节落盘失败，改用复制：$e');
    }
    final stored = await ImageService.copyToDocs(
      sourcePath,
      fileName: '$id.jpg',
    );
    if (stored.isOk) return stored.value as String;
    debugPrint('[IdentificationController] 图片落盘失败，历史将引用原路径');
    return sourcePath;
  }

  /// 只用大模型/内置词典重算档案，不重新识别。
  Future<void> regenerateProfile() async {
    final current = state;
    final id = current.historyId;
    final candidate = current.top;
    if (id == null || candidate == null) return;

    state = state.copyWith(phase: IdentifyPhase.enriching, clearError: true);
    final item = HistoryItem(
      id: id,
      createdAt: DateTime.now(),
      imagePath: current.imagePath ?? '',
      candidate: candidate,
    );
    await _generateProfile(item);
  }

  /// 用户手动纠正品种：切换主候选并重新生成档案。
  Future<void> applyCandidate(PlantCandidate candidate) async {
    final current = state;
    final result = current.result;
    final id = current.historyId;
    if (result == null || id == null) return;

    final nextCandidates = <PlantCandidate>[candidate];
    for (final c in result.candidates) {
      if (c.scientificName != candidate.scientificName) {
        nextCandidates.add(c);
      }
    }
    final nextResult = IdentificationResult(
      candidates: nextCandidates,
      engine: result.engine,
      identifiedAt: result.identifiedAt,
      elapsed: result.elapsed,
    );

    state = state.copyWith(
      result: nextResult,
      phase: IdentifyPhase.enriching,
      clearProfile: true,
      clearError: true,
    );

    {
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.update(
        id,
        (old) => HistoryItem(
          id: old.id,
          createdAt: old.createdAt,
          imagePath: old.imagePath,
          candidate: candidate,
          engineId: old.engineId,
          source: old.source,
        ),
      );
    }

    final item = HistoryItem(
      id: id,
      createdAt: DateTime.now(),
      imagePath: current.imagePath ?? '',
      candidate: candidate,
    );
    await _generateProfile(item);
  }

  Future<void> _generateProfile(HistoryItem item) async {
    final settings = _ref.read(settingsProvider);
    PlantProfile? profile;
    bool fromCache = false;

    final canUseLlm = settings.llm.enabled && settings.llm.isConfigured;
    if (canUseLlm) {
      final generator = _ref.read(profileGeneratorProvider);
      final r = await generator.generate(item.candidate);
      profile = r.value;
      if (r.isErr) {
        final e = r.error;
        debugPrint(
          '[IdentificationController] 大模型生成失败: '
          '${e is AppException ? e.message : e}',
        );
      }
    }

    // 降级：内置词典
    profile ??= await _offlineProfile(item.candidate);
    if (profile != null && canUseLlm == false) {
      fromCache = true;
    } else if (profile != null && profile.isOffline) {
      fromCache = true;
    }

    // 兜底：即使词典也没有，也要给出一张可分享的卡片
    profile ??= PlantProfile.offline(
      scientificName: item.candidate.scientificName,
      title: item.candidate.displayName,
      summary: item.candidate.familyGenus.isNotEmpty
          ? '${item.candidate.familyGenus}，识别置信度 ${item.candidate.confidencePercent}%'
          : '识别置信度 ${item.candidate.confidencePercent}%',
    );

    state = state.copyWith(
      phase: IdentifyPhase.success,
      profile: profile,
      profileFromCache: fromCache,
    );

    final repo = await _ref.read(historyRepositoryProvider.future);
    await repo.update(item.id, (old) => old.copyWith(profile: profile));
    await _ref.read(historyProvider.notifier).refresh();
  }

  Future<PlantProfile?> _offlineProfile(PlantCandidate candidate) async {
    try {
      final library = await _ref.read(plantLibraryProvider.future);
      final hit =
          library.byScientificName(candidate.scientificName) ??
          library.byCommonName(candidate.commonName);
      return hit?.toProfile();
    } catch (_) {
      return null;
    }
  }

  void reset() => state = const IdentifyState();
}

final identificationProvider =
    StateNotifierProvider<IdentificationController, IdentifyState>(
      (ref) => IdentificationController(ref),
    );
