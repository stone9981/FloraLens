import 'package:flutter/material.dart';

import 'plant.dart';

/// 界面语言选项。
///
/// - [system]：跟随系统，设备语言非中文时一律回退英文（满足「其他区域默认英文」）。
/// - [zh]：简体中文。
/// - [en]：英文。
enum AppLanguage {
  system('system'),
  zh('zh'),
  zhHant('zh-Hant'),
  en('en');

  const AppLanguage(this.id);

  final String id;

  /// 用于 [MaterialApp.locale] 的实际 Locale；system 返回 null 让 Flutter 跟随设备。
  Locale? get locale => switch (this) {
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.zhHant =>
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    AppLanguage.en => const Locale('en'),
    AppLanguage.system => null,
  };

  static AppLanguage fromId(String? id) => AppLanguage.values.firstWhere(
    (l) => l.id == id,
    orElse: () => AppLanguage.system,
  );
}

/// 置信度回落时，优先请哪一家做复核。
///
/// 只在识别引擎选了「视觉大模型」时生效：视觉模型泛化强但可能「硬编」品种，
/// 专用模型慢、贵、要注册账号，却是对物种最靠谱的裁决者。
enum HybridFallbackSource {
  auto('auto', '自动（优先 Plant.id，其次 Pl@ntNet）'),
  plantId('plant_id', 'Plant.id'),
  plantNet('plantnet', 'Pl@ntNet'),
  kindwise('kindwise', 'Kindwise'),
  customHttp('custom_http', '自建服务');

  const HybridFallbackSource(this.id, this.label);

  final String id;
  final String label;

  static List<HybridFallbackSource> get uiValues =>
      const <HybridFallbackSource>[auto, plantId, plantNet, kindwise];

  static HybridFallbackSource fromId(String? id) {
    return HybridFallbackSource.values.firstWhere(
      (s) => s.id == id,
      orElse: () => HybridFallbackSource.auto,
    );
  }
}

/// 混合策略的取值约束，避免同一个魔法数字散落各处。
class HybridSettings {
  const HybridSettings._();

  /// 默认阈值：视觉模型低于这个把握就不直接出结果，先让复核引擎判一次。
  static const double defaultThreshold = 0.65;

  static const double minThreshold = 0.3;
  static const double maxThreshold = 0.95;

  static double clampThreshold(double value) {
    final v = value.clamp(minThreshold, maxThreshold);
    // 0.05 一档，滑块读数不会拖出一长串无关小数。
    return (v * 100).round() / 100;
  }
}

/// 大模型服务商预置配置。
///
/// 统一走 OpenAI 兼容协议，因此无论是云端厂商、自建网关，
/// 还是本机跑的 Ollama / llama.cpp / LM Studio，都只需要四个字段。
class LlmPreset {
  const LlmPreset({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.hint,
    this.models = const <String>[],
    this.visionModels = const <String>[],
    this.supportsVision = false,
    this.isLocal = false,
  });

  final String id;
  final String name;
  final String baseUrl;
  final String defaultModel;
  final List<String> models;

  /// 该服务商下支持「看图」的视觉模型，识别引擎选视觉大模型时从这里挑。
  final List<String> visionModels;
  final String? hint;
  final bool supportsVision;
  final bool isLocal;

  static const String customId = 'custom';

  static List<LlmPreset> get presets => const <LlmPreset>[
    LlmPreset(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com/v1',
      defaultModel: 'deepseek-chat',
      models: <String>['deepseek-chat', 'deepseek-reasoner'],
      hint: '中文植物知识扎实，性价比最高，推荐首选',
    ),
    LlmPreset(
      id: 'agnes',
      name: 'Agnes AI（注册即免费）',
      baseUrl: 'https://apihub.agnes-ai.com/v1',
      defaultModel: 'agnes-2.5-flash',
      models: <String>[
        'agnes-2.5-flash',
        'agnes-2.0-flash',
        'agnes-image-2.1-flash',
      ],
      visionModels: <String>['agnes-2.5-flash', 'agnes-2.0-flash'],
      supportsVision: true,
      hint:
          '邮箱注册即免费、无需绑卡，识别与文案共用 agnes-2.5-flash；'
          '国内若访问慢，可把 Base URL 换成 https://apihub.agnes-ai.cn/v1',
    ),
    LlmPreset(
      id: 'qwen',
      name: '通义千问',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      defaultModel: 'qwen-plus',
      models: <String>['qwen-plus', 'qwen-turbo', 'qwen-max'],
      visionModels: <String>['qwen-vl-max', 'qwen-vl-plus'],
      supportsVision: true,
      hint: '阿里 DashScope 兼容模式，国内速度快',
    ),
    LlmPreset(
      id: 'glm',
      name: '智谱 GLM',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      defaultModel: 'glm-4-flash',
      models: <String>['glm-4-flash', 'glm-4-plus', 'glm-4-air'],
      visionModels: <String>['glm-4.5v', 'glm-4v-flash'],
      supportsVision: true,
      hint: 'glm-4-flash 长期免费',
    ),
    LlmPreset(
      id: 'moonshot',
      name: 'Kimi (Moonshot)',
      baseUrl: 'https://api.moonshot.cn/v1',
      defaultModel: 'moonshot-v1-8k',
      models: <String>['moonshot-v1-8k', 'moonshot-v1-32k'],
      visionModels: <String>['moonshot-v1-8k-vision-preview'],
      supportsVision: true,
    ),
    LlmPreset(
      id: 'doubao',
      name: '火山方舟 (豆包)',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
      defaultModel: 'doubao-pro-32k',
      models: <String>['doubao-pro-32k', 'doubao-lite-32k'],
      visionModels: <String>['doubao-vision-pro-32k', 'doubao-vision-lite-32k'],
      supportsVision: true,
    ),
    LlmPreset(
      id: 'openai',
      name: 'OpenAI',
      baseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
      models: <String>['gpt-4o-mini', 'gpt-4o'],
      visionModels: <String>['gpt-4o-mini', 'gpt-4o', 'gpt-4.1-mini'],
      supportsVision: true,
    ),
    LlmPreset(
      id: 'ollama',
      name: 'Ollama（本地/局域网）',
      baseUrl: 'http://192.168.1.100:11434/v1',
      defaultModel: 'qwen2.5:7b',
      models: <String>['qwen2.5:7b', 'llama3.1:8b', 'gemma2:9b'],
      visionModels: <String>['qwen3-vl:8b', 'llava:latest', 'internvl3:latest'],
      supportsVision: true,
      isLocal: true,
      hint: '手机请把 localhost 换成电脑的局域网 IP，并确保同一 WiFi 下',
    ),
    LlmPreset(
      id: 'llamacpp',
      name: 'llama.cpp / LM Studio',
      baseUrl: 'http://192.168.1.100:8080/v1',
      defaultModel: 'local-model',
      visionModels: <String>['vision-model'],
      supportsVision: true,
      isLocal: true,
      hint: '任何 OpenAI 兼容的本地推理服务都填这里',
    ),
    LlmPreset(
      id: customId,
      name: '自定义 OpenAI 兼容端点',
      baseUrl: '',
      defaultModel: '',
      hint: '任意实现了 /chat/completions 的网关',
    ),
  ];

  static LlmPreset byId(String id) =>
      presets.firstWhere((p) => p.id == id, orElse: () => presets.first);
}

/// 大模型连接配置。
class LlmConfig {
  const LlmConfig({
    this.presetId = 'deepseek',
    this.baseUrl = 'https://api.deepseek.com/v1',
    this.apiKey = '',
    this.model = 'deepseek-chat',
    this.temperature = 0.7,
    this.enabled = true,
    this.timeoutSeconds = 45,
  });

  final String presetId;
  final String baseUrl;
  final String apiKey;
  final String model;
  final double temperature;
  final bool enabled;
  final int timeoutSeconds;

  bool get isConfigured => baseUrl.isNotEmpty && model.isNotEmpty;

  /// 本地服务不强制要求 API Key。
  bool get requiresKey {
    final preset = LlmPreset.byId(presetId);
    return !preset.isLocal;
  }

  LlmConfig copyWith({
    String? presetId,
    String? baseUrl,
    String? apiKey,
    String? model,
    double? temperature,
    bool? enabled,
    int? timeoutSeconds,
  }) {
    return LlmConfig(
      presetId: presetId ?? this.presetId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      enabled: enabled ?? this.enabled,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
    presetId: (json['presetId'] as String?) ?? 'deepseek',
    baseUrl: (json['baseUrl'] as String?) ?? '',
    apiKey: (json['apiKey'] as String?) ?? '',
    model: (json['model'] as String?) ?? '',
    temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
    enabled: (json['enabled'] as bool?) ?? true,
    timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt() ?? 45,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'presetId': presetId,
    'baseUrl': baseUrl,
    'apiKey': apiKey,
    'model': model,
    'temperature': temperature,
    'enabled': enabled,
    'timeoutSeconds': timeoutSeconds,
  };
}

/// 分享卡片模板样式。
enum CardTemplate {
  magazine('magazine', '杂志风'),
  minimal('minimal', '极简白'),
  herbarium('herbarium', '标本馆'),
  night('night', '夜色');

  const CardTemplate(this.id, this.label);

  final String id;
  final String label;

  static CardTemplate fromId(String? id) => CardTemplate.values.firstWhere(
    (t) => t.id == id,
    orElse: () => CardTemplate.magazine,
  );
}

/// 应用全局设置。
class AppSettings {
  const AppSettings({
    this.engine = EngineType.plantId,
    this.plantIdKey = '',
    this.plantNetKey = '',
    this.kindwiseKey = '',
    this.customEndpoint = '',
    this.customApiKey = '',
    this.llm = const LlmConfig(),
    this.visionModel = '',
    this.hybridFallback = true,
    this.hybridThreshold = HybridSettings.defaultThreshold,
    this.hybridSource = HybridFallbackSource.auto,
    this.themeMode = ThemeMode.system,
    this.cardTemplate = CardTemplate.magazine,
    this.watermark = '花识 FloraLens',
    this.watermarkLocation = false,
    this.autoSaveCard = false,
    this.saveOriginalPhoto = true,
    this.hdExport = true,
    this.maxHistory = 200,
    this.onboarded = false,
    this.language = 'system',
    this.isPro = false,
    this.proExpiryMillis,
  });

  final EngineType engine;
  final String plantIdKey;
  final String plantNetKey;
  final String kindwiseKey;
  final String customEndpoint;
  final String customApiKey;
  final LlmConfig llm;

  /// 看图识别用的模型名（引擎选「视觉大模型」时生效）。
  /// 留空表示沿用文案模型的模型名。
  final String visionModel;

  /// 视觉模型置信度不足时，是否自动换用专用模型复核。
  final bool hybridFallback;

  /// 触发回落所需的置信度门槛，0~1。
  final double hybridThreshold;

  /// 复核引擎的选择策略。
  final HybridFallbackSource hybridSource;

  final ThemeMode themeMode;
  final CardTemplate cardTemplate;
  final String watermark;
  final bool watermarkLocation;
  final bool autoSaveCard;
  final bool saveOriginalPhoto;
  final bool hdExport;
  final int maxHistory;
  final bool onboarded;

  /// 界面语言：'system' / 'zh' / 'en'。默认跟随系统（非中文区域回退英文）。
  final String language;

  /// 是否已开通 FloraLens Pro 会员。
  ///
  /// Pro 会员享有：去除广告、无水印高清卡片、更详细植物档案等权益。
  /// 由内购（[IapService]）解锁后写盘，进程重启不丢。
  final bool isPro;

  /// 订阅到期时间（毫秒时间戳）。仅订阅类商品有意义：
  /// null 表示「永久有效」（如非消耗型「去广告」），或尚未购买。
  /// 由 [IapService] 写入；生产环境建议由服务端收据校验结果回写，覆盖客户端近似值。
  final int? proExpiryMillis;

  /// 当前 Pro 权益是否真正有效（含订阅有效期判断）。
  ///
  /// 已开通且无到期日 → true；已开通但当前时间晚于 [proExpiryMillis] → false
  /// （订阅过期，UI 据此自动回落为免费：恢复广告、重新加水印）。
  /// 所有读 Pro 状态的地方都应使用本 getter，而非裸 [isPro]。
  bool get isProActive {
    if (!isPro) return false;
    if (proExpiryMillis == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(proExpiryMillis!)
        .isAfter(DateTime.now());
  }

  /// 分享卡片实际显示的水印：Pro（且订阅有效）用户去水印，返回空串；
  /// 否则返回用户自定的 [watermark]。
  String get effectiveWatermark => isProActive ? '' : watermark;

  /// 当前所选引擎是否具备可用凭据。
  bool get engineReady {
    switch (engine) {
      case EngineType.plantId:
        return plantIdKey.trim().isNotEmpty;
      case EngineType.plantNet:
        return plantNetKey.trim().isNotEmpty;
      case EngineType.kindwise:
        return kindwiseKey.trim().isNotEmpty;
      case EngineType.customHttp:
        return customEndpoint.trim().isNotEmpty;
      case EngineType.vlm:
        return llm.isConfigured;
    }
  }

  /// 视觉模型实际使用的连接配置：与文案模型共用端点与 Key，只换模型名。
  LlmConfig get visionLlmConfig {
    final name = visionModel.trim();
    return llm.copyWith(model: name.isEmpty ? llm.model : name);
  }

  // ---- 混合策略 ----

  /// 挑选复核引擎的顺序：用户指定谁就只看谁，否则按可靠性依次尝试。
  List<EngineType> get fallbackCandidates {
    const preferred = <EngineType>[
      EngineType.plantId,
      EngineType.plantNet,
      EngineType.kindwise,
      EngineType.customHttp,
    ];
    List<EngineType> order;
    switch (hybridSource) {
      case HybridFallbackSource.auto:
        order = preferred;
      case HybridFallbackSource.plantId:
        order = <EngineType>[EngineType.plantId];
      case HybridFallbackSource.plantNet:
        order = <EngineType>[EngineType.plantNet];
      case HybridFallbackSource.kindwise:
        order = <EngineType>[EngineType.kindwise];
      case HybridFallbackSource.customHttp:
        order = <EngineType>[EngineType.customHttp];
    }
    return order
        .where((e) => _hasFallbackCredentials(e))
        .toList(growable: false);
  }

  bool _hasFallbackCredentials(EngineType type) {
    switch (type) {
      case EngineType.plantId:
        return plantIdKey.trim().isNotEmpty;
      case EngineType.plantNet:
        return plantNetKey.trim().isNotEmpty;
      case EngineType.kindwise:
        return kindwiseKey.trim().isNotEmpty;
      case EngineType.customHttp:
        return customEndpoint.trim().isNotEmpty;
      case EngineType.vlm:
        return false;
    }
  }

  /// 本次识别实际会用到的复核引擎；null 表示不启用回落。
  EngineType? get effectiveFallbackEngine {
    if (!hybridFallback) return null;
    if (engine != EngineType.vlm) return null;
    if (fallbackCandidates.isEmpty) return null;
    return fallbackCandidates.first;
  }

  String get currentEngineKey {
    switch (engine) {
      case EngineType.plantId:
        return plantIdKey;
      case EngineType.plantNet:
        return plantNetKey;
      case EngineType.kindwise:
        return kindwiseKey;
      case EngineType.customHttp:
        return customApiKey;
      case EngineType.vlm:
        return llm.apiKey;
    }
  }

  AppSettings copyWith({
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
    bool? isPro,
    int? proExpiryMillis,
  }) {
    return AppSettings(
      engine: engine ?? this.engine,
      plantIdKey: plantIdKey ?? this.plantIdKey,
      plantNetKey: plantNetKey ?? this.plantNetKey,
      kindwiseKey: kindwiseKey ?? this.kindwiseKey,
      customEndpoint: customEndpoint ?? this.customEndpoint,
      customApiKey: customApiKey ?? this.customApiKey,
      llm: llm ?? this.llm,
      visionModel: visionModel ?? this.visionModel,
      hybridFallback: hybridFallback ?? this.hybridFallback,
      hybridThreshold: hybridThreshold == null
          ? this.hybridThreshold
          : HybridSettings.clampThreshold(hybridThreshold),
      hybridSource: hybridSource ?? this.hybridSource,
      themeMode: themeMode ?? this.themeMode,
      cardTemplate: cardTemplate ?? this.cardTemplate,
      watermark: watermark ?? this.watermark,
      watermarkLocation: watermarkLocation ?? this.watermarkLocation,
      autoSaveCard: autoSaveCard ?? this.autoSaveCard,
      saveOriginalPhoto: saveOriginalPhoto ?? this.saveOriginalPhoto,
      hdExport: hdExport ?? this.hdExport,
      maxHistory: maxHistory ?? this.maxHistory,
      onboarded: onboarded ?? this.onboarded,
      language: language ?? this.language,
      isPro: isPro ?? this.isPro,
      proExpiryMillis: proExpiryMillis ?? this.proExpiryMillis,
    );
  }

  static ThemeMode themeModeFromId(String? id) {
    switch (id) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToId(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      default:
        return 'system';
    }
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    engine: EngineType.fromId(json['engine'] as String?),
    plantIdKey: (json['plantIdKey'] as String?) ?? '',
    plantNetKey: (json['plantNetKey'] as String?) ?? '',
    kindwiseKey: (json['kindwiseKey'] as String?) ?? '',
    customEndpoint: (json['customEndpoint'] as String?) ?? '',
    customApiKey: (json['customApiKey'] as String?) ?? '',
    llm: json['llm'] != null
        ? LlmConfig.fromJson(json['llm'] as Map<String, dynamic>)
        : const LlmConfig(),
    visionModel: (json['visionModel'] as String?) ?? '',
    hybridFallback: (json['hybridFallback'] as bool?) ?? true,
    hybridThreshold: HybridSettings.clampThreshold(
      (json['hybridThreshold'] as num?)?.toDouble() ??
          HybridSettings.defaultThreshold,
    ),
    hybridSource: HybridFallbackSource.fromId(json['hybridSource'] as String?),
    themeMode: themeModeFromId(json['themeMode'] as String?),
    cardTemplate: CardTemplate.fromId(json['cardTemplate'] as String?),
    watermark: (json['watermark'] as String?) ?? AppSettings().watermark,
    watermarkLocation: (json['watermarkLocation'] as bool?) ?? false,
    autoSaveCard: (json['autoSaveCard'] as bool?) ?? false,
    saveOriginalPhoto: (json['saveOriginalPhoto'] as bool?) ?? true,
    hdExport: (json['hdExport'] as bool?) ?? true,
    maxHistory: (json['maxHistory'] as num?)?.toInt() ?? 200,
    onboarded: (json['onboarded'] as bool?) ?? false,
    language: (json['language'] as String?) ?? 'system',
    isPro: (json['isPro'] as bool?) ?? false,
    proExpiryMillis: json['proExpiryMillis'] as int?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'engine': engine.id,
    'plantIdKey': plantIdKey,
    'plantNetKey': plantNetKey,
    'kindwiseKey': kindwiseKey,
    'customEndpoint': customEndpoint,
    'customApiKey': customApiKey,
    'llm': llm.toJson(),
    'visionModel': visionModel,
    'hybridFallback': hybridFallback,
    'hybridThreshold': hybridThreshold,
    'hybridSource': hybridSource.id,
    'themeMode': themeModeToId(themeMode),
    'cardTemplate': cardTemplate.id,
    'watermark': watermark,
    'watermarkLocation': watermarkLocation,
    'autoSaveCard': autoSaveCard,
    'saveOriginalPhoto': saveOriginalPhoto,
    'hdExport': hdExport,
    'maxHistory': maxHistory,
    'onboarded': onboarded,
    'language': language,
    'isPro': isPro,
    'proExpiryMillis': proExpiryMillis,
  };
}
