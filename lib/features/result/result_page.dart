import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/baike.dart';
import '../../core/theme.dart';
import '../../data/local/settings_store.dart';
import '../../data/models/history_item.dart';
import '../../data/models/plant.dart';
import '../../data/models/plant_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../providers/identification_provider.dart';
import '../../services/ad_service.dart';
import '../../services/result_markdown.dart';
import '../../widgets/common.dart';
import 'share_card_sheet.dart';
import 'card_templates.dart';
import 'manual_pick_sheet.dart';

/// 结果页参数：一张本地图片路径，以及它的来源。
class ResultPageArgs {
  const ResultPageArgs({
    required this.imagePath,
    this.source = IdentifySource.camera,
  });

  final String imagePath;
  final IdentifySource source;
}

/// 识别结果页：展示品种、档案，并提供出卡片入口。
class ResultPage extends ConsumerStatefulWidget {
  const ResultPage({super.key, required this.args});

  final ResultPageArgs args;

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  @override
  void initState() {
    super.initState();
    // 记录一次识别，供首页返回时按阈值（每 3 次）弹插屏。
    ref.read(adServiceProvider).recordIdentify();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(identificationProvider);
      if (state.imagePath != widget.args.imagePath ||
          state.phase == IdentifyPhase.idle) {
        ref
            .read(identificationProvider.notifier)
            .identify(widget.args.imagePath, source: widget.args.source);
      }
    });
  }

  void _openCard(IdentifyState state) {
    final candidate = state.top;
    final id = state.historyId;
    if (candidate == null || id == null) return;
    final settings = ref.read(settingsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(
        historyId: id,
        data: ShareCardData(
          imagePath: state.imagePath ?? widget.args.imagePath,
          candidate: candidate,
          profile:
              state.profile ??
              PlantProfile.offline(
                scientificName: candidate.scientificName,
                title: candidate.displayName,
              ),
          watermark: settings.watermark,
          date: DateTime.now(),
        ),
      ),
    );
  }

  void _openManualPick() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualPickSheet(
        current: ref.read(identificationProvider).top,
        onPicked: (candidate) {
          Navigator.of(context).pop();
          ref.read(identificationProvider.notifier).applyCandidate(candidate);
        },
      ),
    );
  }

  /// 花名点击：App 内浏览器打开百度百科，看完关闭即回到本页。
  Future<void> _openBaike(IdentifyState state) async {
    final candidate = state.top;
    if (candidate == null) return;
    final uri = Baike.itemUrl(Baike.bestName(candidate, state.profile));
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!ok && mounted) _toast(context.l10n.tr('cannotOpenBaike'));
    } catch (_) {
      if (mounted) _toast(context.l10n.tr('cannotOpenBaike'));
    }
  }

  /// 把整页识别结果复制为 Markdown（含百科链接，便于核对）。
  Future<void> _copyMarkdown(IdentifyState state) async {
    final candidate = state.top;
    if (candidate == null) return;
    final md = buildResultMarkdown(
      l10n: context.l10n,
      candidate: candidate,
      profile: state.profile,
      source: state.source,
      date: DateTime.now(),
    );
    try {
      await Clipboard.setData(ClipboardData(text: md));
      if (mounted) _toast(context.l10n.tr('copiedMarkdown'));
    } catch (_) {
      if (mounted) _toast(context.l10n.tr('copyMarkdownFailed'));
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(identificationProvider);
    final imagePath = state.imagePath ?? widget.args.imagePath;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          state.phase == IdentifyPhase.success
              ? (state.profile?.title ?? context.l10n.tr('resultTitle'))
              : context.l10n.tr('identifying'),
        ),
        actions: state.phase == IdentifyPhase.success
            ? <Widget>[
                IconButton(
                  onPressed: () => _copyMarkdown(state),
                  icon: const Icon(Icons.copy_all_rounded),
                  tooltip: context.l10n.tr('copyMarkdown'),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: switch (state.phase) {
          IdentifyPhase.idle || IdentifyPhase.identifying => _Progress(
            message: context.l10n.tr('identifying'),
            hint: context.l10n.tr('identifyingHint'),
            imagePath: imagePath,
          ),
          IdentifyPhase.enriching => _Progress(
            message: context.l10n.tr('enriching'),
            hint: context.l10n.tr('enrichingHint'),
            imagePath: imagePath,
          ),
          IdentifyPhase.failure => _Failure(
            message: state.errorMessage ?? context.l10n.tr('unknownError'),
            imagePath: imagePath,
            onRetry: () => ref
                .read(identificationProvider.notifier)
                .identify(widget.args.imagePath, source: widget.args.source),
            onManual: _openManualPick,
          ),
          IdentifyPhase.success => _Success(
            state: state,
            imagePath: imagePath,
            isPro: ref.watch(settingsProvider).isPro,
            onCard: () => _openCard(state),
            onNameTap: () => _openBaike(state),
            onRegenerate: () =>
                ref.read(identificationProvider.notifier).regenerateProfile(),
            onManual: _openManualPick,
          ),
        },
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.message,
    required this.hint,
    required this.imagePath,
  });

  final String message;
  final String hint;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        const Spacer(),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: LocalImage(
            path: imagePath,
            width: MediaQuery.of(context).size.width - 72,
            height: 280,
            radius: AppTheme.radiusLg,
          ),
        ),
        const SizedBox(height: 28),
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
        const SizedBox(height: 18),
        Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          hint,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
      ],
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.message,
    required this.imagePath,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final String imagePath;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          LocalImage(
            path: imagePath,
            height: 220,
            width: double.infinity,
            radius: AppTheme.radiusLg,
          ),
          const SizedBox(height: 20),
          ErrorBanner(message: message, onRetry: onRetry),
          const SizedBox(height: 14),
          Text(
            context.l10n.tr('resultUnknownHint'),
            style: const TextStyle(fontSize: 12.5, height: 1.6),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: context.l10n.tr('manualSearch'),
            icon: Icons.search_rounded,
            outlined: true,
            onPressed: onManual,
          ),
        ],
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({
    required this.state,
    required this.imagePath,
    this.isPro = false,
    required this.onCard,
    required this.onNameTap,
    required this.onRegenerate,
    required this.onManual,
  });

  final IdentifyState state;
  final String imagePath;
  final bool isPro;
  final VoidCallback onCard;
  final VoidCallback onNameTap;
  final VoidCallback onRegenerate;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final candidate = state.top as PlantCandidate;
    final profile = state.profile;
    final result = state.result;
    final note = result?.fallbackNote;
    final revalidated = result?.wasRevalidated ?? false;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                child: LocalImage(
                  path: imagePath,
                  height: 250,
                  width: double.infinity,
                  radius: AppTheme.radiusLg,
                ),
              ),
              const SizedBox(height: 18),
              _TitleBlock(
                candidate: candidate,
                profile: profile,
                onNameTap: onNameTap,
              ),
              const SizedBox(height: 14),
              _MetaRow(candidate: candidate, profile: profile),
              if (state.profileFromCache)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TagChip(
                    context.l10n.tr('offlineData'),
                    icon: Icons.cloud_off_outlined,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TagChip(
                  context.l10n.tr('savedToRecords', <String>[
                    context.l10n.source(state.source.id),
                  ]),
                  icon: Icons.bookmark_outline_rounded,
                ),
              ),
              if (note != null && note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _FallbackBanner(
                  note: note,
                  revalidated: revalidated,
                  confirmedLabel: result?.confirmedBy != null
                      ? context.l10n.engine(result!.confirmedBy!.id)
                      : null,
                  uncertain: candidate.confidencePercent < 60,
                ),
              ],
              if (profile != null && profile.summary.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                SectionTitle(context.l10n.tr('storyLabel')),
                Text(
                  profile.story.isNotEmpty ? profile.story : profile.summary,
                  style: const TextStyle(fontSize: 14, height: 1.85),
                ),
              ],
              if (profile != null && profile.careTips.isNotEmpty) ...<Widget>[
                const SizedBox(height: 18),
                SectionTitle(context.l10n.tr('careLabel')),
                ...profile.careTips.map(
                  (tip) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.circle,
                            size: 5,
                            color: AppTheme.brandGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tip,
                            style: const TextStyle(fontSize: 13.5, height: 1.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (profile != null && profile.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: profile.tags.map((t) => TagChip(t)).toList(),
                ),
              ],
              if (state.result != null &&
                  state.result!.candidates.length > 1) ...<Widget>[
                const SizedBox(height: 20),
                SectionTitle(context.l10n.tr('similarLabel')),
                _SimilarList(
                  candidates: state.result!.candidates.skip(1).take(4).toList(),
                ),
              ],
              // Pro 用户不展示广告；免费用户结果内容后插一张广告卡。
              if (!isPro)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: AdInlineCard(),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        _BottomBar(
          onCard: onCard,
          onRegenerate: onRegenerate,
          onManual: onManual,
        ),
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.candidate,
    required this.profile,
    this.onNameTap,
  });

  final PlantCandidate candidate;
  final PlantProfile? profile;
  final VoidCallback? onNameTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = (profile?.title.isNotEmpty ?? false)
        ? profile!.title
        : candidate.displayName;
    final titleStyle = const TextStyle(
      fontSize: 27,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
    );
    final titleWidget = onNameTap == null
        ? Text(title, style: titleStyle)
        : GestureDetector(
            onTap: onNameTap,
            child: Tooltip(
              message: context.l10n.tr('openBaike'),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Flexible(child: Text(title, style: titleStyle)),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: titleWidget),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${context.l10n.tr('confidenceLabel')} ${candidate.confidencePercent}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        if (candidate.scientificName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              candidate.scientificName,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// 混合策略提示条：说明这次为什么换了引擎、或为什么结果不确定。
class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner({
    required this.note,
    required this.revalidated,
    required this.uncertain,
    this.confirmedLabel,
  });

  final String note;
  final bool revalidated;
  final bool uncertain;
  final String? confirmedLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tone = revalidated ? scheme.primary : scheme.tertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                revalidated
                    ? Icons.verified_outlined
                    : Icons.help_outline_rounded,
                size: 15,
                color: tone,
              ),
              const SizedBox(width: 6),
              Text(
                revalidated
                    ? context.l10n.tr('revalidated')
                    : context.l10n.tr('uncertain'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: tone,
                ),
              ),
              if (revalidated && confirmedLabel != null) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  '· $confirmedLabel',
                  style: TextStyle(fontSize: 12, color: tone),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(note, style: const TextStyle(fontSize: 12.5, height: 1.6)),
          if (uncertain && !revalidated) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              context.l10n.tr('hybridUnsure'),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.candidate, required this.profile});

  final PlantCandidate candidate;
  final PlantProfile? profile;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      if (candidate.familyGenus.isNotEmpty)
        MapEntry(context.l10n.tr('familyLabel'), candidate.familyGenus),
      if (profile?.bloomTime.isNotEmpty ?? false)
        MapEntry(context.l10n.tr('bloomsLabel'), profile!.bloomTime),
      if (profile?.origin.isNotEmpty ?? false)
        MapEntry(context.l10n.tr('originLabel'), profile!.origin),
      if (profile?.language.isNotEmpty ?? false)
        MapEntry(context.l10n.tr('languageLabel'), profile!.language),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: rows
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: 52,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _SimilarList extends ConsumerWidget {
  const _SimilarList({required this.candidates});

  final List<PlantCandidate> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: candidates
          .map(
            (c) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(c.displayName, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                c.scientificName,
                style: const TextStyle(fontSize: 11.5),
              ),
              trailing: Text('${c.confidencePercent}%'),
              onTap: () =>
                  ref.read(identificationProvider.notifier).applyCandidate(c),
            ),
          )
          .toList(),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.onCard,
    required this.onRegenerate,
    required this.onManual,
  });

  final VoidCallback onCard;
  final VoidCallback onRegenerate;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PrimaryButton(
              label: context.l10n.tr('createCard'),
              icon: Icons.auto_awesome_rounded,
              onPressed: onCard,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: PrimaryButton(
                    label: context.l10n.tr('regenerate'),
                    outlined: true,
                    expand: false,
                    onPressed: onRegenerate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: context.l10n.tr('manualSearch'),
                    outlined: true,
                    expand: false,
                    onPressed: onManual,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
