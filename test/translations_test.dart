import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_manager/main.dart';
import 'package:immoizi_app_manager/src/i18n/manager_strings.dart';
import 'package:immoizi_core/immoizi_core.dart';
import 'package:immoizi_core/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    expect(missingTranslations('lib'), isEmpty);
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
