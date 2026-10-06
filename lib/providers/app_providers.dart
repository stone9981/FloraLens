import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/engine/identification_engine.dart';
import '../data/llm/llm_client.dart';
import '../data/local/settings_store.dart';
import '../data/offline/common_plants.dart';

/// 内置植物词典（懒加载一次）。
final plantLibraryProvider = FutureProvider<CommonPlantLibrary>((ref) async {
  return CommonPlantLibrary.load();
});

/// 按当前设置构造的大模型客户端。
final llmClientProvider = Provider<LlmClient>((ref) {
  final settings = ref.watch(settingsProvider);
  return LlmClient(settings.llm);
});

/// 档案生成器。
final profileGeneratorProvider = Provider<PlantProfileGenerator>((ref) {
  final settings = ref.watch(settingsProvider);
  final client = ref.watch(llmClientProvider);
  return PlantProfileGenerator(
    client,
    modelLabel: settings.llm.model.isEmpty ? '大模型' : settings.llm.model,
  );
});

/// 按当前设置构造的识别引擎。
final identificationEngineProvider = Provider<IdentificationEngine>((ref) {
  final settings = ref.watch(settingsProvider);
  return EngineFactory.create(settings);
});
