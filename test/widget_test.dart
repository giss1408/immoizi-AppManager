import 'package:flutter_test/flutter_test.dart';

import 'package:immoizi_app_manager/main.dart';

void main() {
  testWidgets('renders manager dashboard shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ImmoiziManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('Immoizi Manager'), findsOneWidget);
    expect(find.text('Portefeuille bailleur'), findsOneWidget);
    expect(find.text('Charger le portefeuille'), findsOneWidget);
  });
}
