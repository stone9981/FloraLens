import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/history_repository.dart';
import '../data/local/settings_store.dart';
import '../data/models/history_item.dart';

/// 历史记录列表。
///
/// 用 StateNotifier 而非 FutureProvider，是为了在保存/删除后能立刻刷新 UI，
/// 而不用到处 ref.invalidate。
class HistoryController
    extends StateNotifier<AsyncValue<List<HistoryItem>>> {
  HistoryController(this._ref)
      : super(const AsyncValue<List<HistoryItem>>.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue<List<HistoryItem>>.loading();
    try {
      final repo = await _ref.read(historyRepositoryProvider.future);
      final items = await repo.all();
      state = AsyncValue<List<HistoryItem>>.data(items);
    } catch (e, s) {
      state = AsyncValue<List<HistoryItem>>.error(e, s);
    }
  }

  Future<void> save(HistoryItem item) async {
    try {
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.save(item);
      await trimIfNeeded();
      await refresh();
    } catch (e, s) {
      // 现在只是记日志：写失败时不该把整条识别流程打断，但要留痕便于排查。
      debugPrint('[HistoryController] 写入历史失败: $e\n$s');
    }
  }

  Future<void> updateCardPath(String id, String cardPath) async {
    try {
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.update(id, (item) => item.copyWith(cardPath: cardPath));
      await refresh();
    } catch (_) {}
  }

  Future<void> remove(String id) async {
    try {
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.remove(id);
      await refresh();
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.clear();
      await refresh();
    } catch (_) {}
  }

  /// 超过用户设定的上限时，自动淘汰最旧的记录。
  Future<void> trimIfNeeded() async {
    try {
      final max = _ref.read(settingsProvider).maxHistory;
      final repo = await _ref.read(historyRepositoryProvider.future);
      await repo.trimTo(max);
    } catch (_) {}
  }
}

final historyProvider =
    StateNotifierProvider<HistoryController, AsyncValue<List<HistoryItem>>>(
  (ref) => HistoryController(ref),
);
