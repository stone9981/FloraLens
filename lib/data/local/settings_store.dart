import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/plant.dart';

/// 底层 SharedPreferences 实例，在 main() 中初始化后注入。
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences 未初始化');
});

/// 全局设置状态。
///
/// 任何字段变更后立刻落盘，保证进程被系统杀掉也不丢配置。
final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsController(prefs);
  },
);

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._prefs) : super(_load(_prefs));

  static const String _key = 'app_settings_v1';
  final SharedPreferences _prefs;

  static AppSettings _load(SharedPreferences prefs) {
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_key, jsonEncode(state.toJson()));
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await _persist();
  }

  Future<void> patch({
    EngineType? engine,
    String? plantIdKey,
    String? plantNetKey,
    String? kindwiseKey,
    String? customEndpoint,
    String? customApiKey,
    LlmConfig? llm,
    String? visionModel,
    bool? hybridFallback,
    double? hybridThreshold,
    HybridFallbackSource? hybridSource,
    ThemeMode? themeMode,
    CardTemplate? cardTemplate,
    String? watermark,
    bool? watermarkLocation,
    bool? autoSaveCard,
    bool? saveOriginalPhoto,
    bool? hdExport,
    int? maxHistory,
    bool? onboarded,
    String? language,
  }) async {
    state = state.copyWith(
      engine: engine,
      plantIdKey: plantIdKey,
      plantNetKey: plantNetKey,
      kindwiseKey: kindwiseKey,
      customEndpoint: customEndpoint,
      customApiKey: customApiKey,
      llm: llm,
      visionModel: visionModel,
      hybridFallback: hybridFallback,
      hybridThreshold: hybridThreshold,
      hybridSource: hybridSource,
      themeMode: themeMode,
      cardTemplate: cardTemplate,
      watermark: watermark,
      watermarkLocation: watermarkLocation,
      autoSaveCard: autoSaveCard,
      saveOriginalPhoto: saveOriginalPhoto,
      hdExport: hdExport,
      maxHistory: maxHistory,
      onboarded: onboarded,
      language: language,
    );
    await _persist();
  }

  Future<void> setEngine(EngineType engine) => patch(engine: engine);

  Future<void> setLlm(LlmConfig llm) => patch(llm: llm);

  Future<void> setVisionModel(String model) => patch(visionModel: model);

  /// 混合策略三项一次改完，避免滑块拖动时每帧都触发一次落盘。
  Future<void> setHybrid({
    bool? enabled,
    double? threshold,
    HybridFallbackSource? source,
  }) async {
    state = state.copyWith(
      hybridFallback: enabled,
      hybridThreshold: threshold,
      hybridSource: source,
    );
    await _persist();
  }

  Future<void> setThemeMode(ThemeMode mode) => patch(themeMode: mode);

  Future<void> setCardTemplate(CardTemplate template) =>
      patch(cardTemplate: template);

  Future<void> setLanguage(String language) => patch(language: language);

  Future<void> completeOnboarding() => patch(onboarded: true);

  Future<void> reset() async {
    state = const AppSettings();
    await _persist();
  }
}
