import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme.dart';
import '../../data/local/config_backup.dart';
import '../../data/local/settings_store.dart';
import '../../data/llm/llm_client.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/plant.dart';
import '../../providers/app_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/pro_paywall.dart';
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
    final settings = ref.read(settingsProvider);
    final client = ref.read(llmClientProvider);
    final r = await client.testConnection();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = r.when(
        ok: (_) =>
            '${context.l10n.tr('connectionOk')}：${context.l10n.tr('modelLabel')} ${settings.llm.model} ${context.l10n.tr('modelAvailable')}',
        err: (e) => '${context.l10n.tr('connectionFailed')}：${e.message}',
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
        _visionResult = context.l10n.tr('visionMaybeUnsupported');
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
            '${context.l10n.tr('connectionOk')}：${context.l10n.tr('visionModelLabel')} ${settings.visionLlmConfig.model} ${context.l10n.tr('modelAvailable')}',
        err: (e) => '${context.l10n.tr('connectionFailed')}：${e.message}',
      );
    });
  }

  String _visionHelp(AppSettings settings) {
    final l10n = context.l10n;
    final preset = LlmPreset.byId(settings.llm.presetId);
    String text;
    if (preset.isLocal) {
      text = l10n.tr('localVisionNote');
    } else if (preset.id == LlmPreset.customId) {
      text = l10n.tr('customVisionNote');
    } else {
      text = l10n.tr('visionPresetNote', <String>[
        preset.visionModels.isEmpty
            ? preset.defaultModel
            : preset.visionModels.first,
        preset.defaultModel,
      ]);
    }

    if (!settings.hybridFallback) return text;
    final fb = settings.effectiveFallbackEngine;
    final tail = fb == null
        ? l10n.tr('hybridNoFallback')
        : l10n.tr('hybridCurrent', <String>[l10n.engine(fb.id)]);
    return '${text}；${tail}';
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
          subject: context.l10n.tr('configBackupSubject'),
          text: context.l10n.tr('configExportNote'),
        ),
      );
      if (!mounted) return;
      setState(() => _backupHint = context.l10n.tr('configExported'));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _backupHint = context.l10n.tr('exportFailed', <String>['$e']),
      );
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

      final decoded = ConfigBackup.decode(
        await File(path).readAsString(),
        l10n: context.l10n,
      );
      final settings = decoded.settings;
      if (settings == null) {
        setState(() => _backupHint = decoded.error);
        return;
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.tr('importConfirmTitle')),
          content: Text(context.l10n.tr('importConfirmBody')),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.tr('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.tr('importConfig')),
            ),
          ],
        ),
      );
      if (ok != true) return;
      if (!mounted) return;

      await ref.read(settingsProvider.notifier).update(settings);
      if (!mounted) return;
      setState(() => _backupHint = context.l10n.tr('configImported'));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _backupHint = context.l10n.tr('importFailed', <String>['$e']),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _resetConfig() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tr('resetConfirmTitle')),
        content: Text(context.l10n.tr('resetWarn')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.tr('resetConfig')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).reset();
    if (!mounted) return;
    setState(() => _backupHint = context.l10n.tr('resetDone'));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('settingsTitle'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: <Widget>[
            _buildProSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('recognitionSection')),
            _buildEngineSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('modelSection')),
            _buildLlmSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('appearanceSection')),
            _buildAppearance(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('languageSection')),
            _buildLanguageSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('backupSection')),
            _buildBackupSection(),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('cardSection')),
            _buildCardSection(settings, controller),
            const SizedBox(height: 26),
            SectionTitle(context.l10n.tr('aboutSection')),
            _buildAbout(),
          ],
        ),
      ),
    );
  }

  // ---- 会员 / 内购 ----

  Widget _buildProSection(AppSettings settings, SettingsController controller) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final isPro = settings.isPro;

    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.workspace_premium_rounded,
                color: scheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.tr('proSection'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isPro
                      ? scheme.primary.withValues(alpha: 0.12)
                      : scheme.outline.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPro ? l10n.tr('proActive') : l10n.tr('proInactive'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isPro ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (!isPro) ...<Widget>[
            const SizedBox(height: 10),
            ProBenefitRow(l10n.tr('proBenefitEngine')),
            ProBenefitRow(l10n.tr('proBenefitAdFree')),
            ProBenefitRow(l10n.tr('proBenefitCard')),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openPaywall,
                icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                label: Text(l10n.tr('upgradePro')),
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _restore,
                child: Text(l10n.tr('restorePurchase')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPaywall() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProPaywallSheet(),
    );
  }

  Future<void> _restore() async {
    await ref.read(iapServiceProvider).restore();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.tr('restoreDone'))));
  }

  Widget _buildEngineSection(
    AppSettings settings,
    SettingsController controller,
  ) {
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
              title: Text(
                context.l10n.engine(engine.id),
                style: const TextStyle(fontSize: 14.5),
              ),
              subtitle: Text(
                _engineDesc(engine),
                style: const TextStyle(fontSize: 11.5),
              ),
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
              decoration: InputDecoration(
                labelText: context.l10n.tr('visionModelLabel'),
                hintText: 'qwen-vl-plus',
              ),
              onChanged: (v) => controller.setVisionModel(v),
            ),
            const SizedBox(height: 10),
            if (preset.visionModels.isNotEmpty) ...<Widget>[
              Wrap(
                spacing: 6,
                children: preset.visionModels
                    .map(
                      (m) => ActionChip(
                        label: Text(m, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () => controller.setVisionModel(m),
                      ),
                    )
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
                    label: context.l10n.tr('testConnection'),
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
                  color:
                      _visionResult!.startsWith(context.l10n.tr('connectionOk'))
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
              decoration: InputDecoration(
                labelText: context.l10n.tr('serverUrl'),
                hintText: 'http://192.168.1.100:8000/identify',
              ),
              onChanged: (v) => controller.patch(customEndpoint: v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: TextEditingController(text: settings.customApiKey),
              key: ValueKey('ck_${settings.customApiKey}'),
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.l10n.tr('apiKeyOptional'),
              ),
              onChanged: (v) => controller.patch(customApiKey: v),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.tr('customProto'),
              style: const TextStyle(fontSize: 11.5, height: 1.6),
            ),
          ] else ...<Widget>[
            TextField(
              controller: TextEditingController(
                text: settings.currentEngineKey,
              ),
              key: ValueKey(
                'k_${settings.engine.id}_${settings.currentEngineKey}',
              ),
              obscureText: true,
              decoration: InputDecoration(
                labelText: '${context.l10n.engine(settings.engine.id)} API Key',
                hintText: context.l10n.tr('apiKeyHint'),
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
          title: Text(
            context.l10n.tr('hybridTitle'),
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            context.l10n.tr('hybridDesc'),
            style: const TextStyle(fontSize: 11.5),
          ),
          onChanged: (v) => controller.setHybrid(enabled: v),
        ),
        if (settings.hybridFallback) ...<Widget>[
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                '${context.l10n.tr('hybridThresholdLabel')} ${(settings.hybridThreshold * 100).round()}%',
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
            context.l10n.tr('hybridThresholdHint'),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<HybridFallbackSource>(
            initialValue: source,
            decoration: InputDecoration(
              labelText: context.l10n.tr('hybridSourceLabel'),
            ),
            items: HybridFallbackSource.uiValues
                .map(
                  (s) => DropdownMenuItem<HybridFallbackSource>(
                    value: s,
                    child: Text(
                      context.l10n.hybrid(s.id),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5),
                    ),
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
                ? context.l10n.tr('hybridNoFallback')
                : context.l10n.tr('hybridCurrent', <String>[
                    context.l10n.engine(settings.effectiveFallbackEngine!.id),
                  ]),
            style: TextStyle(
              fontSize: 11.5,
              height: 1.6,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _engineDesc(EngineType engine) => context.l10n.engineDesc(engine.id);

  String _engineHelp(EngineType engine) => context.l10n.engineHelp(engine.id);

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
            title: Text(
              context.l10n.tr('enableLlm'),
              style: const TextStyle(fontSize: 14.5),
            ),
            subtitle: Text(
              context.l10n.tr('llmOffHint'),
              style: const TextStyle(fontSize: 11.5),
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(enabled: v)),
          ),
          const Divider(),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: llm.presetId,
            decoration: InputDecoration(
              labelText: context.l10n.tr('providerLabel'),
            ),
            items: LlmPreset.presets
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p.id,
                    child: Text(
                      context.l10n.tr('presetName_${p.id}'),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final p = LlmPreset.byId(v);
              controller.setLlm(
                llm.copyWith(
                  presetId: v,
                  baseUrl: p.baseUrl,
                  model: p.defaultModel,
                ),
              );
            },
          ),
          if (preset.hint != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('presetHint_${preset.id}'),
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
            decoration: InputDecoration(
              labelText: context.l10n.tr('baseUrlLabel'),
              hintText: 'https://api.deepseek.com/v1',
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(baseUrl: v)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: TextEditingController(text: llm.model),
            key: ValueKey('model_${llm.model}'),
            decoration: InputDecoration(
              labelText: context.l10n.tr('modelLabel'),
              hintText: 'deepseek-chat',
            ),
            onChanged: (v) => controller.setLlm(llm.copyWith(model: v)),
          ),
          if (preset.models.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: preset.models
                  .map(
                    (m) => ActionChip(
                      label: Text(m, style: const TextStyle(fontSize: 11.5)),
                      onPressed: () =>
                          controller.setLlm(llm.copyWith(model: m)),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (settings.engine == EngineType.vlm) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              context.l10n.tr('vlmModelNote'),
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
                  label: context.l10n.tr('testConnection'),
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
                color: _testResult!.startsWith(context.l10n.tr('connectionOk'))
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
              title: Text(
                _themeLabel(mode),
                style: const TextStyle(fontSize: 14.5),
              ),
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
          SnackBar(content: Text(context.l10n.tr('openBrowserFailed'))),
        );
      }
    }

    Future<void> pasteKey() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final key = (data?.text ?? '').trim();
      if (key.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.tr('clipboardEmpty'))),
        );
        return;
      }
      await controller.setLlm(settings.llm.copyWith(apiKey: key));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.tr('keyPasted'))));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
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
                context.l10n.tr('agnesGuideTitle'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.tr('agnesGuideBody'),
            style: const TextStyle(fontSize: 11.5, height: 1.65),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: context.l10n.tr('openRegister'),
                  icon: Icons.open_in_browser_rounded,
                  outlined: true,
                  expand: false,
                  onPressed: openPlatform,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: context.l10n.tr('pasteKey'),
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
              label: Text(context.l10n.tr('switchToVlm')),
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
          Text(
            context.l10n.tr('backupDesc'),
            style: const TextStyle(fontSize: 12.5, height: 1.7),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PrimaryButton(
                  label: context.l10n.tr('exportConfig'),
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
                  label: context.l10n.tr('importConfig'),
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
                color:
                    _backupHint!.startsWith(
                          context.l10n.tr('configExported'),
                        ) ||
                        _backupHint!.startsWith(
                          context.l10n.tr('configImported'),
                        )
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
              label: Text(context.l10n.tr('resetConfig')),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tr('backupWarn'),
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
        return context.l10n.tr('themeLight');
      case ThemeMode.dark:
        return context.l10n.tr('themeDark');
      default:
        return context.l10n.tr('themeSystem');
    }
  }

  /// 界面语言：跟随系统 / 简体中文 / English。
  ///
  /// 跟随系统时按设备语言解析，非中文一律回退英文（见 [AppLanguage]）。
  Widget _buildLanguageSection(
    AppSettings settings,
    SettingsController controller,
  ) {
    final l10n = context.l10n;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          for (final lang in AppLanguage.values)
            RadioListTile<AppLanguage>(
              value: lang,
              groupValue: AppLanguage.fromId(settings.language),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.languageName(lang.id),
                style: const TextStyle(fontSize: 14.5),
              ),
              onChanged: (v) {
                if (v != null) controller.patch(language: v.id);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCardSection(
    AppSettings settings,
    SettingsController controller,
  ) {
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.tr('defaultTemplate'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: CardTemplate.values
                .map(
                  (t) => ChoiceChip(
                    label: Text(context.l10n.cardTpl(t.id)),
                    selected: settings.cardTemplate == t,
                    onSelected: (_) => controller.setCardTemplate(t),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: TextEditingController(text: settings.watermark),
            key: ValueKey('wm_${settings.watermark}'),
            decoration: InputDecoration(
              labelText: context.l10n.tr('watermarkLabel'),
            ),
            onChanged: (v) => controller.patch(watermark: v),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: settings.watermarkLocation,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              context.l10n.tr('watermarkLocation'),
              style: const TextStyle(fontSize: 14),
            ),
            subtitle: Text(
              context.l10n.tr('watermarkLocationDesc'),
              style: const TextStyle(fontSize: 11.5),
            ),
            onChanged: (v) => controller.patch(watermarkLocation: v),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: settings.hdExport,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              context.l10n.tr('hdExportLabel'),
              style: const TextStyle(fontSize: 14),
            ),
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
            title: Text(context.l10n.tr('versionPrefix')),
            trailing: Text(
              _version.isEmpty ? '—' : _version,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.l10n.tr('privacyPolicy')),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.document,
              arguments: DocumentPageArgs(
                title: context.l10n.tr('privacyPolicy'),
                content: context.l10n.tr('privacyBody'),
              ),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.l10n.tr('termsOfService')),
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.document,
              arguments: DocumentPageArgs(
                title: context.l10n.tr('termsOfService'),
                content: context.l10n.tr('termsBody'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
