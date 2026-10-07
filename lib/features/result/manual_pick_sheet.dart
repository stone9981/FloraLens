import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/plant.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

/// 手动纠正品种：当识别结果明显不对时，用内置词典搜索并覆盖。
class ManualPickSheet extends ConsumerStatefulWidget {
  const ManualPickSheet({super.key, this.current, required this.onPicked});

  final PlantCandidate? current;
  final void Function(PlantCandidate candidate) onPicked;

  @override
  ConsumerState<ManualPickSheet> createState() => _ManualPickSheetState();
}

class _ManualPickSheetState extends ConsumerState<ManualPickSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final library = ref.watch(plantLibraryProvider);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
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
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: Row(
                children: <Widget>[
                  Text(
                    context.l10n.tr('pickCorrect'),
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (widget.current != null)
                    Text(
                      context.l10n.tr('currentIs', <String>[
                        widget.current!.displayName,
                      ]),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: false,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: context.l10n.tr('searchFlowerHint'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: library.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, _) =>
                    Center(child: Text(context.l10n.tr('dictLoadFailed'))),
                data: (lib) {
                  final results = lib.search(_query);
                  if (results.isEmpty) {
                    return Center(child: Text(context.l10n.tr('noMatch')));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final plant = results[index];
                      return ListTile(
                        title: Text(
                          plant.commonName,
                          style: const TextStyle(fontSize: 14.5),
                        ),
                        subtitle: Text(
                          '${plant.family}${plant.genus.isNotEmpty ? ' · ${plant.genus}' : ''}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                        ),
                        onTap: () => widget.onPicked(
                          PlantCandidate(
                            scientificName: plant.scientificName,
                            commonName: plant.commonName,
                            family: plant.family,
                            genus: plant.genus,
                            confidence: 1.0,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                context.l10n.tr('builtinCount', <String>[
                  '${ref.watch(plantLibraryProvider).valueOrNull?.count ?? 0}',
                ]),
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
