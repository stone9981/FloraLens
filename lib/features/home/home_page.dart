import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/routes.dart';
import '../../core/route_observer.dart';
import '../../core/theme.dart';
import '../../data/models/app_settings.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/history_item.dart';
import '../../data/models/picked_photo.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../providers/history_provider.dart';
import '../../providers/identification_provider.dart';
import '../../services/ad_service.dart';
import '../../widgets/common.dart';
import '../../widgets/pro_paywall.dart';
import '../result/result_page.dart';

/// 主页：两个主入口 + 最近识别。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with RouteAware {
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// 从结果页返回首页时，按计数阈值弹一次插屏（Pro 用户不弹）。
  @override
  void didPopNext() {
    final settings = ref.read(settingsProvider);
    if (!settings.isProActive) {
      ref.read(adServiceProvider).showInterstitial();
    }
  }

  Future<void> _pickFromGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 2600,
      );
      if (picked == null) return;
      if (!mounted) return;
      await _openResult(picked.path, source: IdentifySource.gallery);
    } catch (e) {
      _toast('选图失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 拍摄页回传 [PickedPhoto]，自研相机里选的相册图也是 [PickedPhoto]。
  Future<void> _takePhoto() async {
    if (!mounted) return;
    final picked = await Navigator.of(context).pushNamed(AppRoutes.capture);
    if (picked is! PickedPhoto || !mounted) return;
    if (picked.path.isEmpty) return;
    await _openResult(picked.path, source: picked.source);
  }

  Future<void> _openResult(
    String imagePath, {
    IdentifySource source = IdentifySource.camera,
  }) async {
    await Navigator.of(context).pushNamed(
      AppRoutes.result,
      arguments: ResultPageArgs(imagePath: imagePath, source: source),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 未配置引擎时，直接弹付费墙引导开通 Pro（去除广告与水印）。
  Future<void> _openPaywall() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProPaywallSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // iPad / 大屏：内容居中并限制最大宽度，避免被拉伸得过于稀疏
            constraints: const BoxConstraints(maxWidth: 760),
            child: RefreshIndicator(
              onRefresh: () => ref.read(historyProvider.notifier).refresh(),
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverToBoxAdapter(child: _buildHeader(settings)),
                  SliverToBoxAdapter(child: _buildActions()),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),
                  SliverToBoxAdapter(child: _buildStatusCard(settings)),
                  const SliverToBoxAdapter(child: SizedBox(height: 26)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: SectionTitle(
                        context.l10n.tr('recentTitle'),
                        trailing: Text(
                          context.l10n.tr('all'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () =>
                            Navigator.of(context).pushNamed(AppRoutes.history),
                      ),
                    ),
                  ),
                  _buildRecent(history),
                  if (!settings.isProActive)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: AdBannerWidget(),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppSettings settings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.local_florist_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.tr('homeTitle'),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.tr('homeSubtitle'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.history),
            icon: const Icon(Icons.history_rounded),
            tooltip: context.l10n.tr('myRecords'),
          ),
          IconButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: context.l10n.tr('settingsEntry'),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: <Widget>[
          // 主入口：拍照
          GestureDetector(
            onTap: _takePhoto,
            child: Container(
              height: 172,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                gradient: LinearGradient(
                  colors: <Color>[AppTheme.brandGreen, AppTheme.brandGreenDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.brandGreen.withValues(alpha: 0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: -18,
                    bottom: -26,
                    child: Icon(
                      Icons.local_florist_rounded,
                      size: 150,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              context.l10n.tr('takePhoto'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              context.l10n.tr('aimFlower'),
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              context.l10n.tr('shootNow'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
          ),
          const SizedBox(height: 14),
          // 次入口：相册
          GestureDetector(
            onTap: _busy ? null : _pickFromGallery,
            child: Container(
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: scheme.outline),
              ),
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 20),
                  Icon(
                    Icons.photo_library_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      context.l10n.tr('pickFromGallery'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 引擎/模型的就绪状态提示，避免用户拍完才发现没配 Key。
  Widget _buildStatusCard(AppSettings settings) {
    final engineOk = settings.engineReady;
    final llmOk = settings.llm.enabled && settings.llm.isConfigured;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: <Widget>[
            _StatusRow(
              label: context.l10n.tr('recogEngine'),
              value: context.l10n.engine(settings.engine.id),
              ok: engineOk,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: context.l10n.tr('contentGen'),
              value: llmOk
                  ? settings.llm.model
                  : context.l10n.tr('notConfiguredUseBuiltin'),
              ok: llmOk,
            ),
            if (!engineOk || !llmOk) ...<Widget>[
              const SizedBox(height: 10),
              // 已开通 Pro 后不再展示「去开通」按钮，仅保留「去配置」入口；
              // 因为 Pro 不会自动配置引擎（BYOK 架构），仍需用户自备 Key。
              if (!settings.isProActive)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openPaywall,
                    icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                    label: Text(context.l10n.tr('goProCta')),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(context.l10n.tr('goConfig')),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecent(AsyncValue<List<HistoryItem>> history) {
    return history.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
      data: (items) {
        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EmptyState(message: context.l10n.tr('emptyRecent')),
            ),
          );
        }
        final shown = items.take(8).toList();
        return SliverToBoxAdapter(
          child: SizedBox(
            height: 132,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: shown.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = shown[index];
                final path = item.imagePath;
                final name = item.candidate.displayName;
                return _RecentTile(
                  imagePath: path,
                  name: name,
                  onTap: () {
                    ref.read(identificationProvider.notifier).reset();
                    Navigator.of(context).pushNamed(AppRoutes.history);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    required this.ok,
  });

  final String label;
  final String value;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: ok ? AppTheme.brandGreen : AppTheme.accentClay,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.imagePath,
    required this.name,
    required this.onTap,
  });

  final String imagePath;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 104,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LocalImage(path: imagePath, width: 104, height: 92, radius: 14),
            const SizedBox(height: 7),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
