import 'package:flutter/material.dart';

/// 文档页参数。
class DocumentPageArgs {
  const DocumentPageArgs({required this.title, required this.content});

  final String title;
  final String content;
}

/// 应用内长文页（隐私政策、用户协议等）。
///
/// 不引 WebView，纯本地渲染，既省包体积也避免远程内容不可控。
class DocumentPage extends StatelessWidget {
  const DocumentPage({super.key, required this.args});

  final DocumentPageArgs args;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final blocks = args.content.trim().split('\n');

    return Scaffold(
      appBar: AppBar(title: Text(args.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: blocks.map((line) {
              final text = line.trimRight();
              if (text.isEmpty) return const SizedBox(height: 10);
              if (text.startsWith('## ')) {
                return Padding(
                  padding: const EdgeInsets.only(top: 18, bottom: 8),
                  child: Text(
                    text.substring(3),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }
              if (text.startsWith('- ')) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('•  '),
                      Expanded(
                        child: Text(
                          text.substring(2),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.7,
                            color: scheme.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.8,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
