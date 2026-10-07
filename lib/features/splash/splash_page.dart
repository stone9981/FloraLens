import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';

/// 启动页：预热词典与历史，然后进主页。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // 预热的失败不影响进入主页。
    await Future.wait<void>(<Future<void>>[
      ref.read(plantLibraryProvider.future).then((_) {}).catchError((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 1100)),
    ]);
    if (!mounted) return;
    await Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppTheme.brandGreen,
                      AppTheme.brandGreen.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.local_florist_rounded,
                  size: 46,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.tr('appName'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.tr('appTagline'),
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
