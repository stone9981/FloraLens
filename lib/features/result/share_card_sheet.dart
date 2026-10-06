import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/result.dart';
import '../../data/models/app_settings.dart';
import '../../data/local/settings_store.dart';
import '../../providers/history_provider.dart';
import '../../services/card_capture_service.dart';
import '../../services/share_service.dart';
import '../../widgets/common.dart';
import '../../services/location_service.dart';
import 'card_templates.dart';

/// 分享卡片弹层：选模板 → 预览 → 保存/分享。
class ShareCardSheet extends ConsumerStatefulWidget {
  const ShareCardSheet({
    super.key,
    required this.data,
    required this.historyId,
  });

  final ShareCardData data;
  final String historyId;

  @override
  ConsumerState<ShareCardSheet> createState() => _ShareCardSheetState();
}

class _ShareCardSheetState extends ConsumerState<ShareCardSheet> {
  final GlobalKey _cardKey = GlobalKey();
  late CardTemplate _template;
  bool _busy = false;
  String? _lastPath;

  /// 地理定位水印：开启后异步取一次位置，落到水印文本里。
  String? _locationLabel;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _template = ref.read(settingsProvider).cardTemplate;
    if (ref.read(settingsProvider).watermarkLocation) {
      _loadLocation();
    }
  }

  Future<void> _loadLocation() async {
    setState(() => _locating = true);
    final label = await LocationService.placeLabel();
    if (!mounted) return;
    setState(() {
      _locationLabel = label;
      _locating = false;
    });
    if (label == null && ref.read(settingsProvider).watermarkLocation) {
      _toast(AppStrings.locationUnavailable);
    }
  }

  /// 花名点击：用 App 内浏览器打开百度百科词条，点关闭即可回到卡片。
  Future<void> _openBaike() async {
    final name = widget.data.candidate.displayName.isNotEmpty
        ? widget.data.candidate.displayName
        : widget.data.profile.title;
    if (name.isEmpty) return;
    final uri = Uri.https(
      'baike.baidu.com',
      '/item/${Uri.encodeComponent(name)}',
      <String, String>{'fromModule': 'lemma_search-box'},
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!ok && mounted) _toast(AppStrings.cannotOpenBaike);
    } catch (_) {
      if (mounted) _toast(AppStrings.cannotOpenBaike);
    }
  }

  Future<void> _switchTemplate(CardTemplate next) async {
    setState(() => _template = next);
    await ref.read(settingsProvider.notifier).setCardTemplate(next);
  }

  /// 导出 → 记入历史 → 存相册 / 调起分享。
  Future<String?> _export() async {
    setState(() => _busy = true);
    try {
      final r = await CardCaptureService.captureToFile(
        _cardKey,
        pixelRatio: 3,
      );
      final path = r.value;
      if (path == null) {
        final err = r.error;
        _toast(err is AppException ? err.message : '导出失败');
        return null;
      }
      _lastPath = path;
      await ref
          .read(historyProvider.notifier)
          .updateCardPath(widget.historyId, path);
      return path;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final path = _lastPath ?? await _export();
    if (path == null) return;
    final r = await ShareService.saveToGallery(path);
    r.when(
      ok: (_) => _toast(AppStrings.savedSuccess),
      err: (e) => _toast(e.message),
    );
  }

  Future<void> _share() async {
    final path = _lastPath ?? await _export();
    if (path == null) return;
    final text = '${widget.data.profile.title}｜${widget.data.profile.summary}';
    await ShareService.shareImage(path, text: text);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _effectiveWatermark(String base, String? loc) {
    if (loc == null || loc.isEmpty) return base;
    return '$base · 📍$loc';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final width = MediaQuery.of(context).size.width;
    final scale = ((width - 56) / cardWidth).clamp(0.5, 1.15);
    final data = widget.data.copyWith(
      watermark: _effectiveWatermark(settings.watermark, _locationLabel),
    );

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.86,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outline.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    AppStrings.cardTitle,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: CardTemplate.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final t = CardTemplate.values[index];
                  final selected = t == _template;
                  return ChoiceChip(
                    label: Text(t.label),
                    selected: selected,
                    onSelected: (_) => _switchTemplate(t),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topCenter,
                child: RepaintBoundary(
                  key: _cardKey,
                  child: buildShareCard(_template, data, onNameTap: _openBaike),
                ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                children: <Widget>[
                  Text(
                    AppStrings.shareMomentsTip,
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  if (settings.watermarkLocation && _locating)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: 6),
                          Text('正在获取定位…',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PrimaryButton(
                          label: AppStrings.saveToGallery,
                          icon: Icons.download_rounded,
                          outlined: true,
                          loading: _busy,
                          onPressed: _busy ? null : _save,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: AppStrings.shareTo,
                          icon: Icons.ios_share_rounded,
                          loading: _busy,
                          onPressed: _busy ? null : _share,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
