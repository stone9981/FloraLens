import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/local/config_backup.dart';
import '../../data/local/history_backup.dart';
import '../../data/models/history_item.dart';
import '../../data/models/plant_profile.dart';
import '../../data/local/settings_store.dart';
import '../../providers/history_provider.dart';
import '../../widgets/common.dart';
import '../result/card_templates.dart';
import '../result/share_card_sheet.dart';

/// 我的记录：网格浏览、多选、删除（带确认）、以及随时重新出卡片。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// 是否处于多选模式（长按某条进入）。
  bool _selectionMode = false;

  /// 已勾选的记录 id。
  final Set<String> _selected = {};

  void _enterSelection(String id) {
    setState(() {
      _selectionMode = true;
      _selected.add(id);
    });
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
      if (_selected.isEmpty) _selectionMode = false;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelectAll(List<HistoryItem> items) {
    setState(() {
      if (_selected.length == items.length) {
        _selected.clear();
        _selectionMode = false;
      } else {
        _selected.addAll(items.map((e) => e.id));
      }
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部记录？'),
        content: const Text('已保存的图片与卡片也会一并删除，此操作不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(historyProvider.notifier).clear();
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除选中的 $n 项？'),
        content: const Text('这些记录与图片会一并删除，此操作不可恢复。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      final ids = List<String>.from(_selected);
      for (final id in ids) {
        await ref.read(historyProvider.notifier).remove(id);
      }
      _exitSelection();
    }
  }

  Future<void> _exportSelected(List<HistoryItem> items) async {
    // 保持列表中的先后顺序，这样每条导出的 index 与界面一致。
    final chosen = items
        .where((e) => _selected.contains(e.id))
        .toList(growable: false);
    if (chosen.isEmpty) return;

    final info = await PackageInfo.fromPlatform();
    final text = HistoryBackup.encode(
      chosen,
      appVersion: info.version,
    );
    final path = await ConfigBackup.writeToTemp(
      text,
      HistoryBackup.fileNameFor(DateTime.now()),
    );
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(path, mimeType: 'application/json')],
        subject: '花识 FloraLens 记录导出',
        text: AppStrings.historyExportNote,
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(AppStrings.historyExported)));
    }
  }

  void _openCard(HistoryItem item) {
    final settings = ref.read(settingsProvider);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardSheet(
        historyId: item.id,
        data: ShareCardData(
          imagePath: item.imagePath,
          candidate: item.candidate,
          profile: item.profile ??
              PlantProfile.offline(
                scientificName: item.candidate.scientificName,
                title: item.candidate.displayName,
              ),
          watermark: settings.watermark,
          date: item.createdAt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final items = history.valueOrNull ?? const <HistoryItem>[];

    return Scaffold(
      appBar: AppBar(
        title: _selectionMode
            ? Text('已选 ${_selected.length} 项')
            : const Text(AppStrings.myRecords),
        leading: _selectionMode
            ? IconButton(
                onPressed: _exitSelection,
                icon: const Icon(Icons.close),
                tooltip: AppStrings.historyCancelSelect,
              )
            : null,
        actions: <Widget>[
          if (_selectionMode) ...<Widget>[
            IconButton(
              onPressed: () => _toggleSelectAll(items),
              icon: Icon(
                _selected.length == items.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              tooltip: AppStrings.historySelectAll,
            ),
            IconButton(
              onPressed:
                  _selected.isEmpty ? null : () => _exportSelected(items),
              icon: const Icon(Icons.upload_outlined),
              tooltip: AppStrings.historyExportSelected,
            ),
            IconButton(
              onPressed:
                  _selected.isEmpty ? null : _confirmDeleteSelected,
              icon: const Icon(Icons.delete_outline),
              tooltip: AppStrings.historyDeleteSelected,
            ),
          ] else ...<Widget>[
            IconButton(
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空',
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: history.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => const EmptyState(message: '读取记录失败'),
          data: (data) {
            if (data.isEmpty) {
              return const EmptyState(
                message: AppStrings.emptyRecent,
                icon: Icons.photo_album_outlined,
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(historyProvider.notifier).refresh(),
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  final selected = _selectionMode && _selected.contains(item.id);
                  return _HistoryTile(
                    item: item,
                    position: index,
                    selectionMode: _selectionMode,
                    selected: selected,
                    onTap: () {
                      if (_selectionMode) {
                        _toggle(item.id);
                      } else {
                        _openCard(item);
                      }
                    },
                    onLongPress: () {
                      if (_selectionMode) {
                        _toggle(item.id);
                      } else {
                        _enterSelection(item.id);
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.position,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final HistoryItem item;
  final int position;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outline,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: LocalImage(
                    path: item.imagePath,
                    radius: 0,
                    width: double.infinity,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.profile?.title.isNotEmpty == true
                            ? item.profile!.title
                            : item.candidate.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              '${item.createdAt.year}.${item.createdAt.month.toString().padLeft(2, '0')}.${item.createdAt.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                  fontSize: 11, color: scheme.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Icon(
                            item.source == IdentifySource.gallery
                                ? Icons.photo_library_outlined
                                : Icons.camera_alt_outlined,
                            size: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                          Text(
                            item.source.label,
                            style: TextStyle(
                                fontSize: 10.5,
                                color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (selectionMode)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${position + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          if (selectionMode)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : scheme.surface,
                  border: Border.all(
                    color: selected ? scheme.primary : scheme.outline,
                    width: 2,
                  ),
                ),
                child: Icon(
                  selected ? Icons.check : null,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
