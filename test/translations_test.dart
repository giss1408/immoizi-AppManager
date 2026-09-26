import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_manager/main.dart';
import 'package:immoizi_app_manager/src/i18n/manager_strings.dart';
import 'package:immoizi_core/immoizi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

Set<String> trKeys(String dir) {
  // Single- or double-quoted Dart literal; the text is group 1 or 2.
  const literal = r"""(?:'((?:[^'\\\n]|\\.)*)'|"((?:[^"\\\n]|\\.)*)")""";
  final direct = RegExp(r'(?<![\w.])tr\(\s*' + literal);
  final ternary = RegExp(
      r'(?<![\w.])tr\(\s*[^,()]*?\?\s*' + literal + r'\s*:\s*' + literal);
  String decode(String s) => s
      .replaceAllMapped(RegExp(r'\\u([0-9a-fA-F]{4})'),
          (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)))
      .replaceAll(r"\'", "'")
      .replaceAll(r'\$', r'$');
  final keys = <String>{};
  for (final file in Directory(dir).listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final source = file.readAsStringSync();
    for (final m in direct.allMatches(source)) {
      keys.add(decode(m[1] ?? m[2]!));
    }
    for (final m in ternary.allMatches(source)) {
      keys
        ..add(decode(m[1] ?? m[2]!))
        ..add(decode(m[3] ?? m[4]!));
    }
  }
  return keys;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(() {
    AppStrings.language = AppLanguage.fr;
    AppPalette.current = AppPalette.ivoire;
  });

  test('every tr() string in the manager app has an English translation', () {
    AppStrings.register(managerEnglish);
    final missing =
        trKeys('lib').where((key) => !AppStrings.hasTranslation(key)).toList();
    expect(missing, isEmpty);
  });

  testWidgets('switching language and theme from Mon espace', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = GraphQLClient(
        httpClient: MockClient((_) async => http.Response('{}', 500)));
    await tester.pumpWidget(ImmoiziManagerApp(client: client));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mon espace').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('English'), 400,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(AppStrings.language, AppLanguage.en);
    expect(find.text('My space'), findsWidgets);
    expect(find.text('Portfolio'), findsOneWidget);

    await tester.tap(find.text('Dracula'));
    await tester.pumpAndSettle();
    final theme = Theme.of(tester.element(find.text('Portfolio')));
    expect(theme.brightness, Brightness.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_language'), 'en');
    expect(prefs.getString('settings_theme'), 'dracula');
  });
}
