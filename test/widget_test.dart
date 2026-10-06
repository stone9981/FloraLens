import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flora_lens/main.dart';
import 'package:flora_lens/data/local/settings_store.dart';

void main() {
  testWidgets('FloraLensApp 能正常启动', (WidgetTester tester) async {
    // 与 main.dart 一致：先准备好 SharedPreferences，再套 ProviderScope。
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const FloraLensApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 应用入口应是单个 MaterialApp。
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
