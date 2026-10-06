/// 应用内全部文案常量。
///
/// 集中放置便于后续接入多语言，也避免 UI 代码里散落硬编码字符串。
class AppStrings {
  AppStrings._();

  static const String appName = '花识 FloraLens';
  static const String appTagline = '一拍识花，一键出片';
  static const String versionPrefix = '版本';

  // 首页
  static const String homeTitle = '花识';
  static const String homeSubtitle = '拍一朵花，认识它的全部';
  static const String takePhoto = '拍照识别';
  static const String pickFromGallery = '相册选图';
  static const String myRecords = '我的记录';
  static const String settingsEntry = '设置';
  static const String recentTitle = '最近识别';
  static const String emptyRecent = '还没有识别记录\n拍下第一朵花试试';

  // 识别中
  static const String identifying = '正在识别…';
  static const String identifyingHint = 'AI 正在比对植物特征库';
  static const String enriching = '正在生成植物档案…';
  static const String enrichingHint = '大模型正在整理花语与养护建议';

  // 结果
  static const String resultUnknown = '未能确定品种';
  static const String resultUnknownHint =
      '可以换个角度、拍得更清晰一些，或在结果下方手动选择相近品种';
  static const String confidenceLabel = '置信度';
  static const String familyLabel = '科属';
  static const String aliasLabel = '别名';
  static const String bloomsLabel = '花期';
  static const String originLabel = '产地';
  static const String languageLabel = '花语';
  static const String careLabel = '养护要点';
  static const String storyLabel = '植物志';
  static const String similarLabel = '可能相近的品种';
  static const String createCard = '生成分享卡片';
  static const String regenerate = '重新生成文案';
  static const String manualSearch = '手动选择品种';

  // 卡片
  static const String cardTitle = '分享卡片';
  static const String cardTemplate = '模板';
  static const String saveToGallery = '保存到相册';
  static const String shareTo = '分享到';
  static const String shareMomentsTip = '保存后在朋友圈/小红书粘贴即可';
  static const String openBaike = '点击查看百度百科';
  static const String cannotOpenBaike = '无法打开百度百科';
  static const String watermarkLocation = '水印显示拍摄地点';
  static const String watermarkLocationDesc =
      '开启后，生成卡片会获取一次当前位置（仅到市/区），写进水印。'
      '默认关闭，避免把精确位置分享出去。';
  static const String locationUnavailable = '未能获取位置（未授权或不可用）';
  static const String savedSuccess = '已保存到相册';

  // 混合策略（置信度回落）
  static const String hybridTitle = '置信度回落复核';
  static const String hybridDesc =
      '视觉模型没把握时，自动换用 Plant.id 这类专用模型再判一次';
  static const String hybridThresholdLabel = '触发阈值';
  static const String hybridSourceLabel = '用哪家复核';
  static const String hybridNoFallback =
      '还没有可用的复核引擎。填一下上方 Plant.id 或 Pl@ntNet 的 API Key，'
      '这项就会生效；只选了视觉大模型时也可以留空，不影响使用。';
  static const String hybridConfirmed = '已用 %1 复核：%2';
  static const String hybridUnsure =
      '识别不确定，建议手动核对下方相近品种，或重新拍一张更清晰的花照';

  // 配置备份
  static const String backupSection = '配置备份与恢复';
  static const String backupDesc =
      '换手机或重装后，不用把各家的 API Key 再敲一遍：'
      '在旧设备导出一份配置，在新设备导入即可。';
  static const String exportConfig = '导出配置';
  static const String importConfig = '导入配置';
  static const String resetConfig = '恢复默认配置';
  static const String configExported = '已生成配置备份，在分享面板里选一个地方保存即可';
  static const String configImported = '配置已导入，去「识别引擎」看下有没有生效';
  static const String configExportNote =
      '花识 FloraLens 配置备份，在新设备的设置里点「导入配置」即可恢复。'
      '文件内含明文 API Key，请勿转发到公开渠道。';

  // 历史记录多选 / 导出
  static const String historySelectAll = '全选';
  static const String historyCancelSelect = '取消选择';
  static const String historyExportSelected = '导出选中';
  static const String historyExportNote =
      '花识 FloraLens 记录导出，含所选条目的品种信息与顺序索引。'
      '图片仍保留在 App 内，未包含在文件中。';
  static const String historyExported = '已生成记录导出，在分享面板里选一个地方保存即可';
  static const String historyDeleteSelected = '删除选中';
  static const String historySelectionHint = '点按可勾选 / 取消，再选「删除」或「导出」';

  // 设置
  static const String settingsTitle = '设置';
  static const String recognitionSection = '识别引擎';
  static const String modelSection = '大模型';
  static const String appearanceSection = '外观';
  static const String aboutSection = '关于';
  static const String apiKeyHint = '在这里填写你的 API Key';
  static const String testConnection = '测试连接';
  static const String connectionOk = '连接成功';
  static const String connectionFailed = '连接失败';
  static const String themeMode = '主题模式';
  static const String themeSystem = '跟随系统';
  static const String themeLight = '浅色';
  static const String themeDark = '深色';
  static const String privacyPolicy = '隐私政策';
  static const String termsOfService = '用户协议';
  static const String openSource = '开源许可';

  // 通用
  static const String cancel = '取消';
  static const String confirm = '确定';
  static const String retry = '重试';
  static const String save = '保存';
  static const String delete = '删除';
  static const String permissionDenied = '权限被拒绝';
  static const String permissionPermanentlyDenied =
      '权限被永久拒绝，请在系统设置中开启';
  static const String networkError = '网络异常，请检查网络连接';
  static const String unknownError = '出了点小问题，请稍后重试';
}
