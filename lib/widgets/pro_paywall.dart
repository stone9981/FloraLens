import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/local/settings_store.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_providers.dart';

/// 会员权益单行（勾选图标 + 文案），设置页与付费墙共用。
class ProBenefitRow extends StatelessWidget {
  const ProBenefitRow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            size: 16,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 付费墙底部弹层：列出可购商品、发起购买、提供「恢复购买」。
///
/// 是否开通由 [AppSettings.isPro] 驱动——一旦购买/恢复成功（经 IAP 回调写回），
/// 本弹层会自动关闭，外层 Pro 区随即显示「已开通」。
class ProPaywallSheet extends ConsumerStatefulWidget {
  const ProPaywallSheet({super.key});

  @override
  ConsumerState<ProPaywallSheet> createState() => _ProPaywallSheetState();
}

class _ProPaywallSheetState extends ConsumerState<ProPaywallSheet> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen(settingsProvider, (prev, next) {
        if (next.isPro && mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
    });
  }

  Future<void> _buy(ProductDetails product) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await ref.read(iapServiceProvider).buy(product);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('purchaseFailed', const <String>[''])),
        ),
      );
    }
  }

  Future<void> _restore() async {
    await ref.read(iapServiceProvider).restore();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.tr('restoreDone'))));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final iap = ref.watch(iapServiceProvider);
    final products = iap.products;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.tr('upgradePro'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.tr('adFreeTip'),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              ProBenefitRow(l10n.tr('proBenefitEngine')),
              ProBenefitRow(l10n.tr('proBenefitAdFree')),
              ProBenefitRow(l10n.tr('proBenefitCard')),
              const SizedBox(height: 16),
              if (!iap.available)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.tr('iapUnavailable'),
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                for (final p in products)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : () => _buy(p),
                        child: Text('${l10n.tr('subscribe')} · ${p.price}'),
                      ),
                    ),
                  ),
              if (iap.available && products.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _busy ? null : _restore,
                    child: Text(l10n.tr('restorePurchase')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
