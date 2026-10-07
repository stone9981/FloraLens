import 'package:flutter/material.dart';

/// 应用内多语言支持。
///
/// 当前支持简体中文（zh）与英文（en）。字符串集中放在 [_zh] / [_en] 两张表里，
/// 用稳定的 key 索引；UI 通过 [AppLocalizations.of] 或 [BuildContext.l10n] 取用，
/// 切换语言时整个 widget 树会随 [MaterialApp.locale] 一起重建。
class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// 应用实际支持的语言。
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// 语言解析：显式 zh/en 直接采用；跟随系统时，设备语言不是中文一律回退英文。
  ///
  /// 这样满足「其他区域来的默认都用英文」——只有中文设备才会拿到中文。
  static Locale resolve(Locale? locale) {
    final code = locale?.languageCode.toLowerCase() ?? '';
    return code.startsWith('zh') ? const Locale('zh') : const Locale('en');
  }

  String get _code =>
      locale.languageCode.toLowerCase().startsWith('zh') ? 'zh' : 'en';

  String _raw(String key) {
    final table = _code == 'zh' ? _zh : _en;
    return table[key] ?? _en[key] ?? key;
  }

  /// 取翻译；[args] 按 `%1` `%2` … 顺序替换。
  String tr(String key, [List<String>? args]) {
    var s = _raw(key);
    if (args != null) {
      for (var i = 0; i < args.length; i++) {
        s = s.replaceAll('%${i + 1}', args[i]);
      }
    }
    return s;
  }

  // ---- 枚举标签 ----

  String engine(String id) => tr('engine_$id');
  String source(String id) => tr('src_$id');
  String hybrid(String id) => tr('hybrid_$id');
  String cardTpl(String id) => tr('tpl_$id');
  String languageName(String id) => tr('lang_$id');

  String engineDesc(String id) => tr('engineDesc_$id');
  String engineHelp(String id) => tr('engineHelp_$id');
}

/// BuildContext 扩展，方便在 widget 里写 `context.l10n.tr('key')`。
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'zh' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(AppLocalizations.resolve(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

// ---------------------------------------------------------------------------
// 简体中文
// ---------------------------------------------------------------------------
const Map<String, String> _zh = <String, String>{
  // 品牌 / 通用
  'appName': '花识 FloraLens',
  'appTagline': '一拍识花，一键出片',
  'versionPrefix': '版本',

  // 首页
  'homeTitle': '花识',
  'homeSubtitle': '拍一朵花，认识它的全部',
  'takePhoto': '拍照识别',
  'pickFromGallery': '相册选图',
  'myRecords': '我的记录',
  'settingsEntry': '设置',
  'recentTitle': '最近识别',
  'emptyRecent': '还没有识别记录\n拍下第一朵花试试',
  'all': '全部',
  'aimFlower': '对准花朵，让花占满取景框',
  'shootNow': '立即拍摄',
  'recogEngine': '识别引擎',
  'contentGen': '内容生成',
  'notConfiguredUseBuiltin': '未配置，将使用内置词典',
  'goConfig': '去配置',

  // 识别中
  'identifying': '正在识别…',
  'identifyingHint': 'AI 正在比对植物特征库',
  'enriching': '正在生成植物档案…',
  'enrichingHint': '大模型正在整理花语与养护建议',
  'resultTitle': '识别结果',

  // 结果
  'resultUnknown': '未能确定品种',
  'resultUnknownHint': '可以换个角度、拍得更清晰一些，或在结果下方手动选择相近品种',
  'confidenceLabel': '置信度',
  'familyLabel': '科属',
  'aliasLabel': '别名',
  'bloomsLabel': '花期',
  'originLabel': '产地',
  'languageLabel': '花语',
  'careLabel': '养护要点',
  'storyLabel': '植物志',
  'similarLabel': '可能相近的品种',
  'createCard': '生成分享卡片',
  'regenerate': '重新生成文案',
  'manualSearch': '手动选择品种',
  'revalidated': '已交叉复核',
  'uncertain': '识别存疑',
  'offlineData': '离线资料',
  'savedToRecords': '已存入我的记录 · %1',

  // 卡片
  'cardTitle': '分享卡片',
  'cardTemplate': '模板',
  'cardSection': '分享卡片',
  'defaultTemplate': '默认模板',
  'saveToGallery': '保存到相册',
  'shareTo': '分享到',
  'shareMomentsTip': '保存后在朋友圈/小红书粘贴即可',
  'openBaike': '点击查看百度百科',
  'cannotOpenBaike': '无法打开百度百科',
  'copyMarkdown': '复制为 Markdown',
  'copiedMarkdown': '已复制为 Markdown，可粘贴到备忘录 / 公众号',
  'copyMarkdownFailed': '复制失败',
  'watermarkLabel': '卡片水印署名',
  'watermarkLocation': '水印显示拍摄地点',
  'watermarkLocationDesc':
      '开启后，生成卡片会获取一次当前位置（仅到市/区），写进水印。'
      '默认关闭，避免把精确位置分享出去。',
  'hdExportLabel': '高清导出（3x，约 1080px 宽）',
  'locationUnavailable': '未能获取位置（未授权或不可用）',
  'locating': '正在获取定位…',
  'savedSuccess': '已保存到相册',

  // 定位错误
  'locationServiceOff': '定位服务未开启，请在系统设置里打开定位后重试',
  'locationPermissionDenied': '未授予定位权限，无法获取位置',
  'locationNoFix': '暂时获取不到位置，请换个开阔地方稍后再试',

  // 混合策略
  'hybridTitle': '置信度回落复核',
  'hybridDesc': '视觉模型没把握时，自动换用 Plant.id 这类专用模型再判一次',
  'hybridThresholdLabel': '触发阈值',
  'hybridThresholdHint':
      '视觉模型的把握低于这个数时，自动换用复核引擎再判一次。'
      '调低更省事，调高更准。',
  'hybridSourceLabel': '用哪家复核',
  'hybridNoFallback':
      '还没有可用的复核引擎。填一下上方 Plant.id 或 Pl@ntNet 的'
      ' API Key，这项就会生效；只选了视觉大模型时也可以留空，不影响使用。',
  'hybridConfirmed': '已用 %1 复核：%2',
  'hybridUnsure': '识别不确定，建议手动核对下方相近品种，或重新拍一张更清晰的花照',
  'hybridCurrent':
      '当前会用 %1 复核。没配 Key 的引擎会自动跳过，'
      '全都没配这项就不生效。',
  'hybridNoteFailed': '%1 置信度只有 %2%，%3 复核未成功（%4），结果仅供参考',
  'hybridNoteNoResult': '%1 置信度只有 %2%，%3 没能给出有效结果，仍以原判定为准',
  'hybridNoteAdopted': '%1 只给出 %2%，已改用 %3 的判定：%4（%5）',
  'hybridNoteKept': '%1 给出 %2%，%3 复核后把握反而更低（%4%），仍以 %1 结果为准',

  // 配置备份
  'backupSection': '配置备份与恢复',
  'backupDesc':
      '换手机或重装后，不用把各家的 API Key 再敲一遍：'
      '在旧设备导出一份配置，在新设备导入即可。',
  'backupWarn':
      '备份文件里是明文 API Key，导出后请自行决定发到哪里，'
      '不要丢进公开群或公开仓库。',
  'exportConfig': '导出配置',
  'importConfig': '导入配置',
  'resetConfig': '恢复默认配置',
  'configExported': '已生成配置备份，在分享面板里选一个地方保存即可',
  'configImported': '配置已导入，去「识别引擎」看下有没有生效',
  'configExportNote':
      '花识 FloraLens 配置备份，在新设备的设置里点「导入配置」'
      '即可恢复。文件内含明文 API Key，请勿转发到公开渠道。',
  'importConfirmTitle': '导入这份配置？',
  'importConfirmBody':
      '会覆盖当前所有设置，包括各引擎的 API Key。'
      '建议先导出一份当前配置备用。',
  'resetConfirmTitle': '恢复默认配置？',
  'resetWarn': '所有 API Key 与外观设置都会被清空。',

  // 历史记录
  'historySelectAll': '全选',
  'historyCancelSelect': '取消选择',
  'historyExportSelected': '导出选中',
  'historyExportNote':
      '花识 FloraLens 记录导出，含所选条目的品种信息与顺序索引。'
      '图片仍保留在 App 内，未包含在文件中。',
  'historyExported': '已生成记录导出，在分享面板里选一个地方保存即可',
  'historyDeleteSelected': '删除选中',
  'historySelectionHint': '点按可勾选 / 取消，再选「删除」或「导出」',
  'clearAllTitle': '清空全部记录？',
  'clearAllBody': '已保存的图片与卡片也会一并删除，此操作不可恢复。',
  'deleteSelectedTitle': '删除选中的 %1 项？',
  'deleteSelectedBody': '这些记录与图片会一并删除，此操作不可恢复。',
  'clearAll': '清空',
  'selectedCount': '已选 %1 项',
  'readHistoryFailed': '读取记录失败',

  // 设置
  'settingsTitle': '设置',
  'recognitionSection': '识别引擎',
  'modelSection': '大模型',
  'appearanceSection': '外观',
  'languageSection': '语言',
  'aboutSection': '关于',
  'apiKeyHint': '在这里填写你的 API Key',
  'apiKeyOptional': 'API Key（可留空）',
  'testConnection': '测试连接',
  'connectionOk': '连接成功',
  'connectionFailed': '连接失败',
  'modelAvailable': '可用',
  'themeMode': '主题模式',
  'themeSystem': '跟随系统',
  'themeLight': '浅色',
  'themeDark': '深色',
  'privacyPolicy': '隐私政策',
  'termsOfService': '用户协议',
  'openSource': '开源许可',
  'lang_system': '跟随系统',
  'lang_zh': '简体中文',
  'lang_en': 'English',

  // 通用
  'cancel': '取消',
  'confirm': '确定',
  'retry': '重试',
  'save': '保存',
  'delete': '删除',
  'permissionDenied': '权限被拒绝',
  'permissionPermanentlyDenied': '权限被永久拒绝，请在系统设置中开启',
  'networkError': '网络异常，请检查网络连接',
  'unknownError': '出了点小问题，请稍后重试',
  'engineNotConfigured': '识别引擎还没配置，请先到「设置」里填写所需信息',
  'recogFailed': '识别失败，请稍后重试',
  'noFlower': '这张照片里没有找到明显的花朵，可以走近一点、让花占满画面再拍一张',

  // 设置内联
  'enableLlm': '启用大模型生成介绍',
  'llmOffHint': '关闭后只使用内置词典',
  'providerLabel': '服务商 / 端点',
  'baseUrlLabel': 'Base URL',
  'modelLabel': '模型名',
  'visionModelLabel': '识别模型名',
  'presetName_deepseek': 'DeepSeek',
  'presetName_agnes': 'Agnes AI（注册即免费）',
  'presetName_qwen': '通义千问',
  'presetName_glm': '智谱 GLM',
  'presetName_moonshot': 'Kimi (Moonshot)',
  'presetName_doubao': '火山方舟 (豆包)',
  'presetName_openai': 'OpenAI',
  'presetName_ollama': 'Ollama（本地/局域网）',
  'presetName_llamacpp': 'llama.cpp / LM Studio',
  'presetName_custom': '自定义 OpenAI 兼容端点',
  'presetHint_deepseek': '中文植物知识扎实，性价比最高，推荐首选',
  'presetHint_agnes': '邮箱注册即免费、无需绑卡，识别与文案共用 agnes-2.5-flash；国内若访问慢，可把 Base URL 换成 https://apihub.agnes-ai.cn/v1',
  'presetHint_qwen': '阿里 DashScope 兼容模式，国内速度快',
  'presetHint_glm': 'glm-4-flash 长期免费',
  'presetHint_ollama': '手机请把 localhost 换成电脑的局域网 IP，并确保同一 WiFi 下',
  'presetHint_llamacpp': '任何 OpenAI 兼容的本地推理服务都填这里',
  'presetHint_custom': '任意实现了 /chat/completions 的网关',
  'serverUrl': '服务地址',
  'customProto':
      '自建服务协议：POST JSON {"image": "<base64>", "topk": 6}，'
      '返回 {"results":[{"scientificName","commonName","family","genus","confidence"}]}',
  'vlmNoKey': '视觉模型复用大模型配置，这里没有单独的 Key 要填。',
  'visionMaybeUnsupported':
      '这个服务商的默认模型可能不支持读图，'
      '识别时会自动改用下方「识别模型」里填的模型',
  'localVisionNote':
      '本地视觉模型（如 Ollama 的 qwen3-vl:8b）无需联网，'
      '但首次加载权重较慢。识别用后会接着用文案模型写介绍，两者可以在下方配成不同模型。',
  'customVisionNote':
      '这里填任意支持读图的模型名。Base URL 与 Key 复用下方'
      '「大模型」的配置。DeepSeek 官方模型没有视觉能力，不能直接当识别引擎用。',
  'visionPresetNote':
      '端点与 Key 复用下方「大模型」的配置，这里只换模型名。'
      '建议识别用 %1，文案仍用 %2，两者分工最划算。',
  'vlmModelNote':
      '当前识别引擎是「视觉大模型」，上面这个模型名只用于写介绍文案；'
      '识别用的模型名请在上方「识别引擎」里填。',
  'agnesGuideTitle': '3 分钟拿到免费 Key',
  'agnesGuideBody':
      'Agnes 没有开放「程序化注册」接口：账号要在网页上注册，'
      'Key 也要在控制台点出来。这里替你省掉复制网址和粘贴 Key 两步，'
      '剩下的两步仍然需要你亲自点一下。',
  'openRegister': '打开注册页',
  'pasteKey': '粘贴 Key',
  'switchToVlm': '顺手把识别引擎也切到「视觉大模型」',
  'openBrowserFailed': '打不开浏览器，请手动访问 platform.agnes-ai.com',
  'clipboardEmpty': '剪贴板里没有内容，请先在 Agnes 控制台复制 Key',
  'keyPasted': 'Key 已填入，点上方「测试连接」确认可用',
  'exportFailed': '导出失败：%1',
  'importFailed': '导入失败：%1',
  'resetDone': '已恢复默认配置',

  // 拍摄
  'noCamera': '这台设备没有可用的摄像头',
  'cameraStartFailed': '相机启动失败：%1',
  'captureFailed': '拍照失败，请重试',
  'openSystemSettings': '去系统设置',
  'frameHint': '把花朵放进框内，尽量充满画面',

  // 手动选择
  'pickCorrect': '选择正确品种',
  'currentIs': '当前：%1',
  'searchFlowerHint': '搜索花名，如「月季」「樱花」',
  'dictLoadFailed': '词典加载失败',
  'noMatch': '没有匹配的品种',
  'builtinCount': '内置 %1 种常见花卉，选中后会重新生成介绍',

  // 引擎 / 来源 / 模板 / 复核源 枚举
  'engine_plant_id': 'Plant.id',
  'engine_plantnet': 'Pl@ntNet',
  'engine_kindwise': 'Kindwise',
  'engine_custom_http': '自建服务',
  'engine_vlm': '视觉大模型',
  'src_camera': '拍照',
  'src_gallery': '相册',
  'hybrid_auto': '自动（优先 Plant.id，其次 Pl@ntNet）',
  'hybrid_plant_id': 'Plant.id',
  'hybrid_plantnet': 'Pl@ntNet',
  'hybrid_kindwise': 'Kindwise',
  'hybrid_custom_http': '自建服务',
  'tpl_magazine': '杂志风',
  'tpl_minimal': '极简白',
  'tpl_herbarium': '标本馆',
  'tpl_night': '夜色',

  // 长文：隐私政策 / 用户协议
  'privacyBody': '''
## 我们收集什么
- 你拍摄或从相册选择的照片：仅用于植物识别，默认在识别完成后保留在本地历史记录中。
- 你填写的 API Key：只保存在本机 SharedPreferences 中，不会上传到任何服务器。

## 照片去了哪里
- 识别时，照片会经过压缩后发送给你自己选择的服务商（Plant.id / Pl@ntNet / Kindwise / 自建服务）。
- 如果你使用自建服务且地址是局域网内网地址，照片不会离开你的局域网。
- 如果你开启了大模型介绍，发送给大模型的只有植物学名等文本信息，不含照片。
- 只有当识别引擎选了「视觉大模型」时，压缩后的照片才会随识别请求发给你配置的那个视觉模型，且同样只发给你自己选择的服务商。
- 如果开了「置信度回落复核」，且视觉模型的把握低于你设的阈值，同一张照片还会再发一次给你指定的那家复核引擎（默认 Plant.id）。未被采信的那一方不会收到请求。

## 你的权利
- 可以随时在「我的记录」中删除任意一条历史，或一键清空。
- 可以在「配置备份与恢复」里导出全部设置做备份，换设备时导入即可，无需重新填写。
  导出的文件包含明文 API Key，请自行保管，避免转发到公开渠道。
- 卸载应用会连同本地图片与配置一起删除。

## Agnes 注册说明
本应用不代理任何账号注册。Agnes 未开放程序化注册接口，账号与 API Key 必须由你在其官网
（platform.agnes-ai.com）自行完成。应用内只提供「打开注册页」与「粘贴 Key」两步辅助，
不会替你创建账号，也不会把 Key 上传到任何第三方服务器。

## 第三方服务
本应用本身不提供识别与生成能力，需要你自行配置第三方服务并遵守其条款。请勿在你不信任的服务中上传敏感照片。

## 联系我们
如果你对隐私政策有疑问，请在应用商店页面留言。
''',
  'termsBody': '''
## 服务说明
花识 FloraLens 是一个工具型应用，识别与文案生成能力来自用户自行配置的第三方服务。你不配置任何服务时，应用仍可使用内置离线词典，但功能会受限。

## 免责声明
- 识别结果由算法给出，可能存在误差，仅供参考，不应作为食用、药用或专业园艺操作的依据。
- 涉及有毒植物、入侵物种、受保护物种的判断，请以权威机构发布的信息为准。
- 大模型生成的内容可能存在事实性错误，请自行甄别。

## 账号与费用
- 使用第三方服务产生的费用由其服务商收取，与本应用无关。
- 请妥善保管自己的 API Key，因泄露造成的损失由你自行承担。

## 知识产权
应用生成的分享卡片内容归你所有，你可以自由分享到任何平台。
''',

  // 引擎选择说明 / 帮助
  'engineDesc_plant_id': '覆盖最广、字段最全的商业识别服务',
  'engineDesc_plantnet': '科研机构维护，免费额度友好',
  'engineDesc_kindwise': '企业级接口，独立额度与账单',
  'engineDesc_custom_http': '接你自己的模型服务，图片不出内网',
  'engineDesc_vlm': '直接用能读图的大模型识别，不用另配植物服务',
  'engineHelp_plant_id':
      '在 plant.id 官网注册后即可拿到 API Key，新账号通常带免费试用额度。Key 只保存在本机，不会上传。',
  'engineHelp_plantnet':
      '到 my-api.plantnet.org 注册账户即可获取免费 API Key，'
      '注意接口按项目（weurope 等）区分，本 App 默认走观赏植物项目。',
  'engineHelp_kindwise': 'Kindwise 提供植物识别与健康诊断 API，注册后在控制台创建 key。',
  'engineHelp_custom_http': '把地址指向你自己的推理服务即可，支持局域网 http。',
  'engineHelp_vlm': '复用下方「大模型」里的 Base URL 与 Key，只需把识别模型名换成支持读图的型号；文案模型仍可保持原样。',
  'configBackupSubject': '花识 FloraLens 配置备份',

  // Markdown 导出
  'mdConfidence': '置信度',
  'mdSource': '来源',
  'mdIntro': '简介',
  'mdFlowerLanguage': '花语',
  'mdCare': '养护要点',
  'mdFacts': '资料卡',
  'mdFurther': '延伸阅读',
  'mdAlias': '别名',
  'mdBloom': '花期',
  'mdOrigin': '产地',
  'mdFamily': '科属',
  'mdGeneratedBy': '由 FloraLens 生成',

  // 配置导入错误
  'configEmpty': '文件内容是空的',
  'configNotJson': '不是合法的 JSON 文件',
  'configBadFormat': '文件格式不对，这不是花识导出的配置',
  'configWrongApp': '这不是花识的配置备份文件',
  'configNewerVersion': '这个备份来自更新版本的花识（v%1），当前版本可能不认识',
  'configMissingBody': '备份里缺少配置内容',
  'configParseFailed': '配置解析失败：%1',

  // Markdown 导出：百科链接
  'baikeLink': '百度百科',
  'baikeSearch': '百科搜索（词条缺失时用）',

  // ---- 变现：会员 / 广告 ----
  'proSection': '会员',
  'proActive': 'FloraLens Pro 已开通',
  'proInactive': '未开通 Pro',
  'upgradePro': '升级 Pro',
  'restorePurchase': '恢复购买',
  'goProCta': '开通 Pro，免配置立即识别',
  'proBenefitEngine': '托管识别引擎，免配置即拍即识',
  'proBenefitAdFree': '去除全部广告',
  'proBenefitCard': '无水印高清分享卡片',
  'subscribe': '订阅',
  'purchaseSuccess': '已开通 Pro，感谢支持！',
  'purchaseFailed': '开通失败：%1',
  'purchaseCancelled': '已取消',
  'restoreDone': '已恢复购买',
  'restoreNone': '没有可恢复的内购',
  'iapUnavailable': '暂时无法连接商店，请稍后再试',
  'iapLoading': '正在连接商店…',
  'removeAds': '移除广告',
  'adFreeTip': '升级 Pro 即可去除全部广告',
  'adLabel': '广告',
};

// ---------------------------------------------------------------------------
// English
// ---------------------------------------------------------------------------
const Map<String, String> _en = <String, String>{
  'appName': 'FloraLens',
  'appTagline': 'Snap a flower, know it all',
  'versionPrefix': 'Version',

  'homeTitle': 'FloraLens',
  'homeSubtitle': 'Photograph a flower and learn everything about it',
  'takePhoto': 'Identify by Camera',
  'pickFromGallery': 'Pick from Gallery',
  'myRecords': 'My Records',
  'settingsEntry': 'Settings',
  'recentTitle': 'Recent',
  'emptyRecent': 'No identifications yet\nSnap your first flower to try',
  'all': 'All',
  'aimFlower': 'Aim at the flower and fill the frame',
  'shootNow': 'Take Photo',
  'recogEngine': 'Engine',
  'contentGen': 'Content',
  'notConfiguredUseBuiltin': 'Not set — built-in dictionary will be used',
  'goConfig': 'Configure',

  'identifying': 'Identifying…',
  'identifyingHint': 'AI is matching against the plant feature library',
  'enriching': 'Building plant profile…',
  'enrichingHint': 'The model is organizing flower language and care tips',
  'resultTitle': 'Result',

  'resultUnknown': 'Could not determine the species',
  'resultUnknownHint':
      'Try a different angle or a clearer shot, or pick a close match below',
  'confidenceLabel': 'Confidence',
  'familyLabel': 'Family',
  'aliasLabel': 'Alias',
  'bloomsLabel': 'Bloom',
  'originLabel': 'Origin',
  'languageLabel': 'Flower Language',
  'careLabel': 'Care Tips',
  'storyLabel': 'Profile',
  'similarLabel': 'Similar Species',
  'createCard': 'Create Share Card',
  'regenerate': 'Regenerate Text',
  'manualSearch': 'Pick Species Manually',
  'revalidated': 'Cross-checked',
  'uncertain': 'Uncertain',
  'offlineData': 'Offline data',
  'savedToRecords': 'Saved to My Records · %1',

  'cardTitle': 'Share Card',
  'cardTemplate': 'Template',
  'cardSection': 'Share Card',
  'defaultTemplate': 'Default Template',
  'saveToGallery': 'Save to Gallery',
  'shareTo': 'Share',
  'shareMomentsTip': 'After saving, paste it into Moments / Xiaohongshu',
  'openBaike': 'Tap to view Baidu Baike',
  'cannotOpenBaike': 'Could not open Baidu Baike',
  'copyMarkdown': 'Copy as Markdown',
  'copiedMarkdown': 'Copied as Markdown — paste into Notes / WeChat',
  'copyMarkdownFailed': 'Copy failed',
  'watermarkLabel': 'Card watermark name',
  'watermarkLocation': 'Show capture location in watermark',
  'watermarkLocationDesc':
      'When on, the card reads your current location '
      '(city/district only) once for the watermark. Off by default to avoid '
      'sharing precise location.',
  'hdExportLabel': 'HD export (3x, ~1080px wide)',
  'locationUnavailable': 'Location unavailable (not authorized or unavailable)',
  'locating': 'Locating…',
  'savedSuccess': 'Saved to gallery',

  'locationServiceOff':
      'Location service is off. Please enable it in system settings and retry',
  'locationPermissionDenied': 'Location permission not granted',
  'locationNoFix': 'Cannot get a fix right now. Try an open area and retry',

  'hybridTitle': 'Confidence fallback review',
  'hybridDesc':
      'When the vision model is unsure, automatically re-check with '
      'a dedicated model like Plant.id',
  'hybridThresholdLabel': 'Trigger threshold',
  'hybridThresholdHint':
      'When the vision model\'s confidence is below this, '
      'it auto-rechecks with a review engine. Lower = easier, higher = more accurate.',
  'hybridSourceLabel': 'Review with',
  'hybridNoFallback':
      'No review engine available yet. Fill in the API Key for '
      'Plant.id or Pl@ntNet above and this takes effect; leaving it empty is '
      'fine when only the vision model is selected.',
  'hybridConfirmed': 'Re-checked with %1: %2',
  'hybridUnsure':
      'Result is uncertain. Check the close matches below, '
      'or take a clearer photo.',
  'hybridCurrent':
      'Currently reviewing with %1. Engines without a key are '
      'skipped; if none are configured this does nothing.',
  'hybridNoteFailed': '%1 confidence only %2%; %3 recheck failed (%4) — result for reference only',
  'hybridNoteNoResult': '%1 confidence only %2%; %3 returned no valid result, original decision stands',
  'hybridNoteAdopted': '%1 gave only %2%; adopted %3: %4 (%5)',
  'hybridNoteKept':
      '%1 gave %2%; %3 recheck was less confident (%4%), keeping %1 result',

  'backupSection': 'Backup & Restore',
  'backupDesc':
      'When switching phones or reinstalling, no need to retype each '
      'provider\'s API Key: export a config on the old device and import it on the new one.',
  'backupWarn':
      'Backup files contain API Keys in plain text. Decide where to '
      'send it yourself; do not post to public groups or repos.',
  'exportConfig': 'Export Config',
  'importConfig': 'Import Config',
  'resetConfig': 'Reset to Defaults',
  'configExported': 'Backup created — pick a destination in the share sheet',
  'configImported': 'Config imported — check "Recognition Engine" for effect',
  'configExportNote':
      'FloraLens config backup. Tap "Import Config" in Settings '
      'on the new device to restore. File contains plain-text API Keys; do not forward.',
  'importConfirmTitle': 'Import this config?',
  'importConfirmBody':
      'This overwrites all current settings, including each '
      'engine\'s API Key. Export the current config first as a backup.',
  'resetConfirmTitle': 'Reset to defaults?',
  'resetWarn': 'All API Keys and appearance settings will be cleared.',

  'historySelectAll': 'Select All',
  'historyCancelSelect': 'Cancel Selection',
  'historyExportSelected': 'Export Selected',
  'historyExportNote':
      'FloraLens records export, with species info and order '
      'index of the selected items. Images stay in the app and are not included.',
  'historyExported': 'Records exported — pick a destination in the share sheet',
  'historyDeleteSelected': 'Delete Selected',
  'historySelectionHint': 'Tap to check/uncheck, then choose Delete or Export',
  'clearAllTitle': 'Clear all records?',
  'clearAllBody':
      'Saved images and cards will also be deleted. This cannot be undone.',
  'deleteSelectedTitle': 'Delete the selected %1 item(s)?',
  'deleteSelectedBody':
      'These records and images will also be deleted. This cannot be undone.',
  'clearAll': 'Clear',
  'selectedCount': 'Selected %1',
  'readHistoryFailed': 'Failed to read records',

  'settingsTitle': 'Settings',
  'recognitionSection': 'Recognition Engine',
  'modelSection': 'AI Model',
  'appearanceSection': 'Appearance',
  'languageSection': 'Language',
  'aboutSection': 'About',
  'apiKeyHint': 'Fill in your API Key here',
  'apiKeyOptional': 'API Key (optional)',
  'testConnection': 'Test Connection',
  'connectionOk': 'Connected',
  'connectionFailed': 'Connection failed',
  'modelAvailable': 'available',
  'themeMode': 'Theme',
  'themeSystem': 'System',
  'themeLight': 'Light',
  'themeDark': 'Dark',
  'privacyPolicy': 'Privacy Policy',
  'termsOfService': 'Terms of Service',
  'openSource': 'Open Source Licenses',
  'lang_system': 'System',
  'lang_zh': '简体中文',
  'lang_en': 'English',

  'cancel': 'Cancel',
  'confirm': 'OK',
  'retry': 'Retry',
  'save': 'Save',
  'delete': 'Delete',
  'permissionDenied': 'Permission denied',
  'permissionPermanentlyDenied':
      'Permission permanently denied. Please enable it in system settings',
  'networkError': 'Network error, please check your connection',
  'unknownError': 'Something went wrong, please try again later',
  'engineNotConfigured': 'The recognition engine is not configured. Fill in the required info in Settings',
  'recogFailed': 'Identification failed, please try again later',
  'noFlower':
      'No clear flower found in this photo. Move closer and fill the '
      'frame, then take another shot',

  'enableLlm': 'Generate descriptions with AI model',
  'llmOffHint': 'Off — built-in dictionary only',
  'providerLabel': 'Provider / Endpoint',
  'baseUrlLabel': 'Base URL',
  'modelLabel': 'Model name',
  'visionModelLabel': 'Vision model name',
  'presetName_deepseek': 'DeepSeek',
  'presetName_agnes': 'Agnes AI (free on sign-up)',
  'presetName_qwen': 'Qwen (DashScope)',
  'presetName_glm': 'Zhipu GLM',
  'presetName_moonshot': 'Kimi (Moonshot)',
  'presetName_doubao': 'Volcano (Doubao)',
  'presetName_openai': 'OpenAI',
  'presetName_ollama': 'Ollama (local/LAN)',
  'presetName_llamacpp': 'llama.cpp / LM Studio',
  'presetName_custom': 'Custom OpenAI-compatible endpoint',
  'presetHint_deepseek': 'Strong Chinese botanical knowledge, best value — recommended first choice',
  'presetHint_agnes': 'Free on email sign-up, no card needed; identification and text share agnes-2.5-flash; if slow in China, switch Base URL to https://apihub.agnes-ai.cn/v1',
  'presetHint_qwen': 'Alibaba DashScope compatible mode, fast in China',
  'presetHint_glm': 'glm-4-flash is free long-term',
  'presetHint_ollama': 'On phone, replace localhost with your computer\'s LAN IP and use the same Wi-Fi',
  'presetHint_llamacpp': 'Any OpenAI-compatible local inference service goes here',
  'presetHint_custom': 'Any gateway implementing /chat/completions',
  'serverUrl': 'Server URL',
  'customProto':
      'Self-hosted protocol: POST JSON {"image": "<base64>", "topk": 6}, '
      'returns {"results":[{"scientificName","commonName","family","genus","confidence"}]}',
  'vlmNoKey':
      'The vision model reuses the AI model config; no separate Key here.',
  'visionMaybeUnsupported':
      'This provider\'s default model may not support '
      'vision; identification will auto-use the model filled in "Vision model" below',
  'localVisionNote':
      'Local vision models (e.g. Ollama qwen3-vl:8b) need no '
      'network but load weights slowly on first use. After identification it '
      'reuses the text model for the description; both can be set separately below.',
  'customVisionNote':
      'Fill any vision-capable model name here. Base URL and Key '
      'reuse the "AI Model" config below. DeepSeek\'s official models have no '
      'vision ability and cannot be used directly as the recognition engine.',
  'visionPresetNote':
      'Endpoint and Key reuse the "AI Model" config; only the '
      'model name differs here. Recommended: recognition uses %1, text uses %2 '
      '— a good split.',
  'vlmModelNote':
      'The recognition engine is the "Vision Model"; the model name '
      'above is only for the description text. Fill the recognition model name '
      'in "Recognition Engine" above.',
  'agnesGuideTitle': 'Get a free Key in 3 minutes',
  'agnesGuideBody':
      'Agnes has no programmatic sign-up: the account is created on '
      'the website and the Key is generated in the console. We save you the two '
      'steps of copying the URL and pasting the Key; the remaining two steps are yours.',
  'openRegister': 'Open Sign-up',
  'pasteKey': 'Paste Key',
  'switchToVlm': 'Also switch the engine to "Vision Model"',
  'openBrowserFailed':
      'Cannot open browser. Visit platform.agnes-ai.com manually',
  'clipboardEmpty':
      'Clipboard is empty. Copy the Key from the Agnes console first',
  'keyPasted': 'Key filled in. Tap "Test Connection" above to verify',
  'exportFailed': 'Export failed: %1',
  'importFailed': 'Import failed: %1',
  'resetDone': 'Reset to defaults',

  'noCamera': 'This device has no available camera',
  'cameraStartFailed': 'Camera failed to start: %1',
  'captureFailed': 'Capture failed, please retry',
  'openSystemSettings': 'Open System Settings',
  'frameHint': 'Place the flower inside the frame and fill it',

  'pickCorrect': 'Pick the correct species',
  'currentIs': 'Current: %1',
  'searchFlowerHint': 'Search a flower name, e.g. "Rose", "Cherry Blossom"',
  'dictLoadFailed': 'Failed to load dictionary',
  'noMatch': 'No matching species',
  'builtinCount':
      'Built-in %1 common flowers; picking one regenerates the description',

  'engine_plant_id': 'Plant.id',
  'engine_plantnet': 'Pl@ntNet',
  'engine_kindwise': 'Kindwise',
  'engine_custom_http': 'Self-hosted',
  'engine_vlm': 'Vision Model',
  'src_camera': 'Camera',
  'src_gallery': 'Gallery',
  'hybrid_auto': 'Auto (Plant.id first, then Pl@ntNet)',
  'hybrid_plant_id': 'Plant.id',
  'hybrid_plantnet': 'Pl@ntNet',
  'hybrid_kindwise': 'Kindwise',
  'hybrid_custom_http': 'Self-hosted',
  'tpl_magazine': 'Magazine',
  'tpl_minimal': 'Minimal',
  'tpl_herbarium': 'Herbarium',
  'tpl_night': 'Night',

  'privacyBody': '''
## What we collect
- Photos you take or pick from the gallery: used only for plant identification, kept in local history by default after identification.
- API Keys you enter: stored only in the device\'s SharedPreferences, never uploaded to any server.

## Where photos go
- During identification, photos are compressed and sent to the provider you choose (Plant.id / Pl@ntNet / Kindwise / self-hosted).
- If you use a self-hosted service on a local network, photos never leave your LAN.
- If AI descriptions are enabled, only text like the scientific name is sent to the model — no photos.
- Only when the engine is the "Vision Model" does the compressed photo go with the request to the vision model you configured, and only to the provider you chose.
- If "confidence fallback review" is on and the vision model\'s confidence is below your threshold, the same photo is sent once more to your chosen review engine (Plant.id by default). The side not adopted receives no request.

## Your rights
- Delete any history entry anytime in "My Records", or clear all at once.
- Export all settings as a backup in "Backup & Restore" and import on a new device — no retyping.
  Backup files contain plain-text API Keys; keep them safe and do not forward publicly.
- Uninstalling the app deletes local images and config together.

## About Agnes sign-up
This app proxies no account registration. Agnes has no programmatic sign-up; the account and API Key must be created by you on its site
(platform.agnes-ai.com). The app only assists with "Open Sign-up" and "Paste Key";
it never creates an account for you nor uploads your Key to any third party.

## Third-party services
This app provides no identification or generation by itself; you must configure third-party services and follow their terms. Do not upload sensitive photos to services you do not trust.

## Contact
If you have questions about this privacy policy, leave a message on the app store page.
''',
  'termsBody': '''
## Service description
FloraLens is a utility app; identification and text generation come from third-party services you configure. Without any service, the built-in offline dictionary still works, but with limited features.

## Disclaimer
- Results are algorithm-generated and may be inaccurate; for reference only, not a basis for eating, medicinal use, or professional horticulture.
- For toxic, invasive, or protected species, rely on information from authoritative bodies.
- Content generated by AI models may contain factual errors; please verify yourself.

## Accounts & fees
- Fees from third-party services are charged by the provider, not this app.
- Keep your API Key safe; losses from leakage are your responsibility.

## Intellectual property
Share-card content generated by the app belongs to you; feel free to share anywhere.
''',

  // Engine selection descriptions / help
  'engineDesc_plant_id':
      'The most comprehensive commercial service, with the fullest fields',
  'engineDesc_plantnet':
      'Maintained by a research institute; generous free quota',
  'engineDesc_kindwise': 'Enterprise-grade API with separate quota and billing',
  'engineDesc_custom_http':
      'Bring your own model service; images stay on your LAN',
  'engineDesc_vlm': 'Identify directly with a vision-capable model — no separate plant service',
  'engineHelp_plant_id': 'Sign up at plant.id to get an API Key; new accounts usually include a free trial quota. The Key is stored only on device, never uploaded.',
  'engineHelp_plantnet': 'Register at my-api.plantnet.org for a free API Key. The API is organized by project (weurope, etc.); this app uses the ornamental-plants project by default.',
  'engineHelp_kindwise': 'Kindwise offers plant identification and health diagnostics APIs; create a key in the console after sign-up.',
  'engineHelp_custom_http':
      'Point the URL at your own inference service; LAN http is supported.',
  'engineHelp_vlm': 'Reuses the Base URL and Key from the "AI Model" section below; just set the recognition model to a vision-capable one. The text model can stay as-is.',
  'configBackupSubject': 'FloraLens Config Backup',

  // Markdown export
  'mdConfidence': 'Confidence',
  'mdSource': 'Source',
  'mdIntro': 'Summary',
  'mdFlowerLanguage': 'Flower Language',
  'mdCare': 'Care Tips',
  'mdFacts': 'Facts',
  'mdFurther': 'Learn More',
  'mdAlias': 'Alias',
  'mdBloom': 'Bloom',
  'mdOrigin': 'Origin',
  'mdFamily': 'Family',
  'mdGeneratedBy': 'Generated by FloraLens',

  'configEmpty': 'The file is empty',
  'configNotJson': 'Not a valid JSON file',
  'configBadFormat': 'Wrong format — this is not a FloraLens config backup',
  'configWrongApp': 'This is not a FloraLens config backup',
  'configNewerVersion': 'This backup is from a newer FloraLens (v%1); this version may not understand it',
  'configMissingBody': 'The backup is missing configuration content',
  'configParseFailed': 'Failed to parse config: %1',

  'baikeLink': 'Baidu Baike',
  'baikeSearch': 'Baidu search (if the entry is missing)',

  // ---- Monetization: membership / ads ----
  'proSection': 'Membership',
  'proActive': 'FloraLens Pro active',
  'proInactive': 'Not a Pro member',
  'upgradePro': 'Upgrade to Pro',
  'restorePurchase': 'Restore Purchase',
  'goProCta': 'Go Pro for zero-config identify',
  'proBenefitEngine': 'Managed engine, snap & identify instantly',
  'proBenefitAdFree': 'Remove all ads',
  'proBenefitCard': 'Watermark-free HD share cards',
  'subscribe': 'Subscribe',
  'purchaseSuccess': 'Pro unlocked. Thank you!',
  'purchaseFailed': 'Purchase failed: %1',
  'purchaseCancelled': 'Cancelled',
  'restoreDone': 'Purchases restored',
  'restoreNone': 'No purchases to restore',
  'iapUnavailable': 'Store unavailable, please try later',
  'iapLoading': 'Connecting to store…',
  'removeAds': 'Remove ads',
  'adFreeTip': 'Upgrade to Pro to remove all ads',
  'adLabel': 'Ad',
};
