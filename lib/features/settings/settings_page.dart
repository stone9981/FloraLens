import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../data/local/config_backup.dart';
import '../../data/local/settings_store.dart';
import '../../data/llm/llm_client.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/plant.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../document/document_page.dart';

/// 设置页：识别引擎、大模型、外观与关于。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';
  bool _testing = false;
  String? _testResult;
  bool _testingVision = false;
  String? _visionResult;
  String? _backupHint;
  bool _backupBusy = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {}
  }

  Future<void> _testLlm() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final client = ref.read(llmClientProvider);
    final r = await client.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = r.when(
        ok: (text) => '${AppStrings.connectionOk}：${text.length > 20 ? '${text.substring(0, 20)}…' : text}',
        err: (e) => '${AppStrings.connectionFailed}：${e.message}',
      );
    });
  }

  /// 测试视觉端点：只探活，不发送图片。
  ///
  /// 这样能提前抓出 Base URL / Key / 模型名写错的问题，
  /// 比对首次拍照等 3~8 秒的等待更快。
  Future<void> _testVision() async {
    final settings = ref.read(settingsProvider);
    final preset = LlmPreset.byId(settings.llm.presetId);
    if (!preset.supportsVision && preset.id != LlmPreset.customId) {
      setState(() {
        _visionResult = '这个服务商的默认模型可能不支持读图，识别时会自动改用下方「识别模型」里填的模型';
      });
    }

    setState(() {
      _testingVision = true;
      _visionResult = null;
    });
    final r = await LlmClient(settings.visionLlmConfig).testConnection();
    if (!mounted) return;
    setState(() {
      _testingVision = false;
      _visionResult = r.when(
        ok: (text) =>
            '${AppStrings.connectionOk}：识别模型 ${settings.visionLlmConfig.model} 可用',
        err: (e) => '连接失败：${e.message}',
      );
    });
  }

  String _visionHelp(AppSettings settings) {
    final preset = LlmPreset.byId(settings.llm.presetId);
    String text;
    if (preset.isLocal) {
      text = '本地视觉模型（如 Ollama 的 qwen3-vl:8b）无需联网，但首次加载权重较慢。'
          '识别用后会接着用文案模型写介绍，两者可以在下方配成不同模型。';
    } else if (preset.id == LlmPreset.customId) {
      text = '这里填任意支持读图的模型名。Base URL 与 Key 复用下方「大模型」的配置。'
          'DeepSeek 官方模型没有视觉能力，不能直接当识别引擎用。';
    } else {
      text = '端点与 Key 复用下方「大模型」的配置，这里只换模型名。'
          '建议识别用 ${preset.visionModels.isEmpty ? preset.defaultModel : preset.visionModels.first}，'
          '文案仍用 ${preset.defaultModel}，两者分工最划算。';
    }

    if (!settings.hybridFallback) return text;
    final fb = settings.effectiveFallbackEngine;
    return '$text；把握不足 ${(settings.hybridThreshold * 100).round()}% 时，'
        '${fb == null ? '没有可用的复核引擎，回落这项暂不生效' : '会自动请 $fb 复核'}。';
  }

  /// 把当前设置打包成一个 JSON 文件，交给系统分享面板。
  ///
  /// 走分享面板而不是直接写文件，是因为 Android 10+ 的分区存储不让 App 随便
  /// 往「下载」目录里写；而分享面板可以让用户自己挑微信、邮件、网盘存下来。
  Future<void> _exportConfig() async {
    setState(() {
      _backupBusy = true;
      _backupHint = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final text = ConfigBackup.encode(
        ref.read(settingsProvider),
        appVersion: '${info.version} (${info.buildNumber})',
      );
      final path = await ConfigBackup.writeToTemp(
        text,
        ConfigBackup.fileNameFor(DateTime.now()),
      );
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: 'application/json')],
          subject: '花识 FloraLens 配置备份',
          text: AppStrings.configExportNote,
        ),
      );
      if (!mounted) return;
      setState(() => _backupHint = AppStrings.configExported);
    } catch (e) {
      if (!mounted) return;
      setState(() => _backupHint = '导出失败：$e');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  /// 从 JSON 文件恢复配置。
  Future<void> _importConfig() async {
    setState(() {
      _backupBusy = true;
      _backupHint = null;
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>[ConfigBackup.fileExtension],
      );
      final path = picked.isEmpty ? null : picked.first.path;
      if (path == null) return;
      if (!mounted) return;

      final decoded = ConfigBackup.decode(await File(path).readAsString());
      final settings = decoded.settings;
      if (settings == null) {
        setState(() => _backupHint = decoded.error);
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入这份配置？'),
          content: const Text(
            '会覆盖当前所有设置，包括各引擎的 API Key。'
            '建议先导出一份当前配置备用。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.importConfig),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;

      await ref.read(settingsProvider.notifier).update(settings);
      if (!mounted) return;
      setState(() => _backupHint = AppStrings.configImported);
    } catch (e) {
      if (!mounted) return;
      setState(() => _backupHint = '导入失败：$e');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _resetConfig() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复默认配置？'),
        content: const Text('所有 API Key 与外观设置都会被清空。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.resetConfig),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).reset();
    if (!mounted) return;
    setState(() => _backupHint = '已恢复默认配置');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: <Widget>[
            SectionTitle(AppStrings.recognitionSection),
            _buildEngineSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(AppStrings.modelSection),
            _buildLlmSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(AppStrings.appearanceSection),
            _buildAppearance(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(AppStrings.backupSection),
            _buildBackupSection(),
            const SizedBox(height: 26),
            SectionTitle('分享卡片'),
            _buildCardSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(AppStrings.aboutSection),
            _buildAbout(),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineSection(AppSettings settings, SettingsController controller) {
    final preset = LlmPreset.byId(settings.llm.presetId);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...EngineType.values.map(
            (engine) => RadioListTile<EngineType>(
              value: engine,
              groupValue: settings.engine,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(engine.label,
                  style: const TextStyle(fontSize: 14.5)),
              subtitle: Text(_engineDesc(engine),
                  style: const TextStyle(fontSize: 11.5)),
              onChanged: (v) {
                if (v != null) controller.setEngine(v);
              },
            ),
          ),
          const Divider(),
          const SizedBox(height: 8),
          if (settings.engine == EngineType.vlm) ...<Widget>[
            TextField(
              controller: TextEditingController(text: settings.visionModel),
              key: ValueKey('vlm_${settings.visionModel}'),
              decoration: const InputDecoration(
                labelText: '识别模型名',
                hintText: 'qwen-vl-plus',
              ),
              onChanged: (v) => controller.setVisionModel(v),
            ),
            const SizedBox(height: 10),
            if (preset.visionModels.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: 6,
                children: preset.visionModels
                    .map((m) => ActionChip(
                          label: Text(m, style: const TextStyle(fontSize: 11.5)),
                          onPressed: () => controller.setVisionModel(m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              _visionHelp(settings),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: AppStrings.testConnection,
                    outlined: true,
                    loading: _testingVision,
                    onPressed: _testingVision ? null : _testVision,
                  ),
                ),
              ],
            ),
            if (_visionResult != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _visionResult!,
                style: TextStyle(
                  fontSize: 12,
                  color: _visionResult!.startsWith(AppStrings.connectionOk)
                      ? AppTheme.brandGreen
                      : AppTheme.accentClay,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildHybridSubSection(settings, controller),
          ] else if (settings.engine == EngineType.customHttp) ...<Widget>[
            TextField(
              controller: TextEditingController(text: settings.customEndpoint),
              key: ValueKey('ep_${settings.customEndpoint}'),
              decoration: const InputDecoration(
                labelText: '服务地址',
                hintText: 'http://192.168.1.100:8000/identify',
              ),
              onChanged: (v) => controller.patch(customEndpoint: v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: settings.customApiKey),
              key: ValueKey('ck_${settings.customApiKey}'),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key（可留空）',
              ),
              onChanged: (v) => controller.patch(customApiKey: v),
            ),
            const SizedBox(height: 10),
            const Text(
              '自建服务协议：POST JSON {"image": "<base64>", "topk": 6}，'
              '返回 {"results":[{"scientificName","commonName","family","genus","confidence"}]}',
              style: TextStyle(fontSize: 11.5, height: 1.6),
            ),
          ] else ...<Widget>[
            TextField(
              controller:
                  TextEditingController(text: settings.currentEngineKey),
              key: ValueKey('k_${settings.engine.id}_${settings.currentEngineKey}'),
              obscureText: true,
              decoration: InputDecoration(
                labelText: '${settings.engine.label} API Key',
                hintText: AppStrings.apiKeyHint,
              ),
              onChanged: (v) {
                switch (settings.engine) {
                  case EngineType.plantId:
                    controller.patch(plantIdKey: v);
                    break;
                  case EngineType.plantNet:
                    controller.patch(plantNetKey: v);
                    break;
                  case EngineType.kindwise:
                    controller.patch(kindwiseKey: v);
                    break;
                  case EngineType.customHttp:
                    controller.patch(customApiKey: v);
                    break;
                  case EngineType.vlm:
                    // 视觉模型复用大模型配置，这里没有单独的 Key 要填。
                    break;
                }
              },
            ),
            const SizedBox(height: 10),
            Text(
              _engineHelp(settings.engine),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 视觉模型置信度不足时，自动换用专用模型复核。
  Widget _buildHybridSubSection(
    AppSettings settings,
    SettingsController controller,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final source = settings.hybridSource;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SwitchListTile(
          value: settings.hybridFallback,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title:
              const Text(AppStrings.hybridTitle, style: TextStyle(fontSize: 14)),
          subtitle: const Text(AppStrings.hybridDesc,
              style: TextStyle(fontSize: 11.5)),
          onChanged: (v) => controller.setHybrid(enabled: v),
        ),
        if (settings.hybridFallback) ...<Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                '${AppStrings.hybridThresholdLabel} ${(settings.hybridThreshold * 100).round()}%',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
          SizedBox(
            width: double.infinity,
            child: Slider(
              value: settings.hybridThreshold,
              min: HybridSettings.minThreshold,
              max: HybridSettings.maxThreshold,
              divisions: 13,
              label: '${(settings.hybridThreshold * 100).round()}%',
              onChanged: (v) => controller.setHybrid(
                threshold: HybridSettings.clampThreshold(v),
              ),
            ),
          ),
          Text(
            '视觉模型的把握低于这个数时，自动换用复核引擎再判一次。'
            '调低更省事，调高更准。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<HybridFallbackSource>(
            initialValue: source,
            decoration: const InputDecoration(labelText: AppStrings.hybridSourceLabel),
            items: HybridFallbackSource.uiValues
                .map(
                  (s) => DropdownMenuItem<HybridFallbackSource>(
                    value: s,
                    child: Text(s.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) controller.setHybrid(source: v);
            },
          ),
          const SizedBox(height: 10),
          Text(
            settings.effectiveFallbackEngine == null
                ? AppStrings.hybridNoFallback
                : '当前会用 ${settings.effectiveFallbackEngine!.label} 复核。'
                    '没配 Key 的引擎会自动跳过，全都没配这项就不生效。',
            style: TextStyle(fontSize: 11.5, height: 1.6, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  String _engineDesc(EngineType engine) {
    switch (engine) {
      case EngineType.plantId:
        return '覆盖最广、字段最全的商业识别服务';
      case EngineType.plantNet:
        return '科研机构维护，免费额度友好';
      case EngineType.kindwise:
        return '企业级接口，独立额度与账单';
      case EngineType.customHttp:
        return '接你自己的模型服务，图片不出内网';
      case EngineType.vlm:
        return '直接用能读图的大模型识别，不用另配植物服务';
    }
  }

  String _engineHelp(EngineType engine) {
    switch (engine) {
      case EngineType.plantId:
        return '在 plant.id 官网注册后即可拿到 API Key，新账号通常带免费试用额度。'
            'Key 只保存在本机，不会上传。';
      case EngineType.plantNet:
        return '到 my-api.plantnet.org 注册账户即可获取免费 API Key，'
            '注意接口按项目（weurope 等）区分，本 App 默认走观赏植物项目。';
      case EngineType.kindwise:
        return 'Kindwise 提供植物识别与健康诊断 API，注册后在控制台创建 key。';
      case EngineType.customHttp:
        return '把地址指向你自己的推理服务即可，支持局域网 http。';
      case EngineType.vlm:
        return '复用下方「大模型」里的 Base URL 与 Key，只需把识别模型名换成支持读图'
            '的型号；文案模型仍可保持原样。';
    }
  }

  Widget _buildLlmSection(AppSettings settings, SettingsController controller) {
    final llm = settings.llm;
    final preset = LlmPreset.byId(llm.presetId);

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SwitchListTile(
            value: llm.enabled,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('启用大模型生成介绍',
                style: TextStyle(fontSize: 14.5)),
            subtitle: const Text('关闭后只使用内置词典',
                style: TextStyle(fontSize: 11.5)),
            onChanged: (v) => controller.setLlm(llm.copyWith(enabled: v)),
          ),
          const Divider(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: llm.presetId,
            decoration: const InputDecoration(labelText: '服务商 / 端点'),
            items: LlmPreset.presets
                .map((p) => DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final p = LlmPreset.byId(v);
              controller.setLlm(llm.copyWith(
                presetId: v,
                baseUrl: p.baseUrl,
                model: p.defaultModel,
              ));
            },
          ),
          if (preset.hint != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              preset.hint!,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (preset.id == 'agnes') ...<Widget>[
            const SizedBox(height: 12),
            _buildAgnesGuide(settings, preset, controller),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: llm.baseUrl),
            key: ValueKey('base_${llm.baseUrl}'),
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://api.deepseek.com/v1',
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(baseUrl: v)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: llm.model),
            key: ValueKey('model_${llm.model}'),
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: 'deepseek-chat',
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(model: v)),
          ),
          if (preset.models.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: preset.models
                  .map((m) => ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () =>
                            controller.setLlm(llm.copyWith(model: m)),
                      ))
                  .toList(),
            ),
          ],
          if (settings.engine == EngineType.vlm) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '当前识别引擎是「视觉大模型」，上面这个模型名只用于写介绍文案；'
              '识别用的模型名请在上方「识别引擎」里填。',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: llm.apiKey),
            key: ValueKey('llmkey_${llm.apiKey.hashCode}'),
            obscureText: true,
            decoration: InputDecoration(
              labelText: preset.isLocal ? 'API Key（本地服务可留空）' : 'API Key',
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(apiKey: v)),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: AppStrings.testConnection,
                  outlined: true,
                  loading: _testing,
                  onPressed: _testing ? null : _testLlm,
                ),
              ),
            ],
          ),
          if (_testResult != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _testResult!,
              style: TextStyle(
                fontSize: 12,
                color: _testResult!.startsWith(AppStrings.connectionOk)
                    ? AppTheme.brandGreen
                    : AppTheme.accentClay,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppearance(AppSettings settings, SettingsController controller) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              value: mode,
              groupValue: settings.themeMode,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_themeLabel(mode),
                  style: const TextStyle(fontSize: 14.5)),
              onChanged: (v) {
                if (v != null) controller.setThemeMode(v);
              },
            ),
        ],
      ),
    );
  }

  /// Agnes 的「注册到能用」最短路径。
  ///
  /// Agnes 没有开放程序化注册接口 —— 注册必须走网页、密钥必须人工点出来，
  /// 所以这里能做的自动化只有两步：一键打开注册页、一键把剪贴板里的 Key 粘进来。
  Widget _buildAgnesGuide(
    AppSettings settings,
    LlmPreset preset,
    SettingsController controller,
  ) {
    Future<void> openPlatform() async {
      final url = Uri.parse('https://platform.agnes-ai.com/');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打不开浏览器，请手动访问 platform.agnes-ai.com')),
        );
      }
    }

    Future<void> pasteKey() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final key = (data?.text ?? '').trim();
      if (key.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('剪贴板里没有内容，请先在 Agnes 控制台复制 Key')),
        );
        return;
      }
      await controller.setLlm(settings.llm.copyWith(apiKey: key));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Key 已填入，点上方「测试连接」确认可用')),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.volunteer_activism_rounded, size: 16),
              const SizedBox(width: 6),
              Text(
                '3 分钟拿到免费 Key',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Agnes 没有开放「程序化注册」接口：账号要在网页上注册，'
            'Key 也要在控制台点出来。这里替你省掉复制网址和粘贴 Key 两步，'
            '剩下的两步仍然需要你亲自点一下。',
            style: TextStyle(fontSize: 11.5, height: 1.65),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: '打开注册页',
                  icon: Icons.open_in_browser_rounded,
                  outlined: true,
                  expand: false,
                  onPressed: openPlatform,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: '粘贴 Key',
                  icon: Icons.content_paste_rounded,
                  expand: false,
                  onPressed: pasteKey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (settings.engine != EngineType.vlm)
            TextButton.icon(
              onPressed: () => controller.setEngine(EngineType.vlm),
              icon: const Icon(Icons.auto_awesome_rounded, size: 17),
              label: const Text('顺手把识别引擎也切到「视觉大模型」'),
            ),
        ],
      ),
    );
  }

  /// 配置备份与恢复：换设备时不用把 Key 再敲一遍。
  Widget _buildBackupSection() {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(AppStrings.backupDesc,
              style: TextStyle(fontSize: 12.5, height: 1.7)),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: AppStrings.exportConfig,
                  icon: Icons.ios_share_rounded,
                  outlined: true,
                  expand: false,
                  loading: _backupBusy,
                  onPressed: _backupBusy ? null : _exportConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: AppStrings.importConfig,
                  icon: Icons.file_upload_outlined,
                  expand: false,
                  loading: _backupBusy,
                  onPressed: _backupBusy ? null : _importConfig,
                ),
              ),
            ],
          ),
          if (_backupHint != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _backupHint!,
              style: TextStyle(
                fontSize: 12,
                color: _backupHint!.startsWith(AppStrings.configExported) ||
                        _backupHint!.startsWith(AppStrings.configImported)
                    ? AppTheme.brandGreen
                    : AppTheme.accentClay,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetConfig,
              icon: const Icon(Icons.restore_rounded, size: 18),
              label: const Text(AppStrings.resetConfig),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '备份文件里是明文 API Key，导出后请自行决定发到哪里，'
            '不要丢进公开群或公开仓库。',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: scheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return AppStrings.themeLight;
      case ThemeMode.dark:
        return AppStrings.themeDark;
      default:
        return AppStrings.themeSystem;
    }
  }

  Widget _buildCardSection(AppSettings settings, SettingsController controller) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('默认模板',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: CardTemplate.values
                .map((t) => ChoiceChip(
                      label: Text(t.label),
                      selected: settings.cardTemplate == t,
                      onSelected: (_) => controller.setCardTemplate(t),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: TextEditingController(text: settings.watermark),
            key: ValueKey('wm_${settings.watermark}'),
            decoration: const InputDecoration(labelText: '卡片水印署名'),
            onChanged: (v) => controller.patch(watermark: v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.watermarkLocation,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(AppStrings.watermarkLocation,
                style: TextStyle(fontSize: 14)),
            subtitle: const Text(AppStrings.watermarkLocationDesc,
                style: TextStyle(fontSize: 11.5)),
            onChanged: (v) => controller.patch(watermarkLocation: v),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: settings.hdExport,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('高清导出（3x，约 1080px 宽）',
                style: TextStyle(fontSize: 14)),
            onChanged: (v) => controller.patch(hdExport: v),
          ),
        ],
      ),
    );
  }

  Widget _buildAbout() {
    final scheme = Theme.of(context).colorScheme;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('版本'),
            trailing: Text(_version.isEmpty ? '—' : _version,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(AppStrings.privacyPolicy),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.document,
              arguments: DocumentPageArgs(
                title: AppStrings.privacyPolicy,
                content: _privacyText,
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(AppStrings.termsOfService),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.document,
              arguments: DocumentPageArgs(
                title: AppStrings.termsOfService,
                content: _termsText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const String _privacyText = '''
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
''';

const String _termsText = '''
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
''';
