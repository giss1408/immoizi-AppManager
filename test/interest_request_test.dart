import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_manager/src/models/dashboard.dart';
import 'package:immoizi_app_manager/src/pages/interest_request_page.dart';
import 'package:immoizi_app_manager/src/property_edit_context.dart';
import 'package:immoizi_core/immoizi_core.dart';

void main() {
  testWidgets('landlord accepts a request with a note', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final requests = <Map<String, dynamic>>[];
    var refreshed = false;
    final editContext = PropertyEditContext(
      endpoint: 'http://backend.test/graphql',
      token: 'tok',
      onUpdated: () => refreshed = true,
      client: GraphQLClient(httpClient: MockClient((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'data': {
                'respondToPropertyInterest': {
                  'interestRequest': {'id': '5', 'status': 'ACCEPTED'}
                }
              }
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      })),
    );
    final request = InterestRequestItem(
        '5',
        'Villa Cocody',
        'PENDING',
        'Fonctionnaire',
        '300 000 - 500 000 FCFA',
        '',
        2,
        '2026-11-01',
        'Bonjour',
        applicantName: 'Nadia Diallo');

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: InterestRequestPage(request: request, editContext: editContext),
    ));

    expect(find.text('Nadia Diallo'), findsOneWidget);
    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Proposer une visite'), findsOneWidget);

    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(find.text('Accepter la demande ?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Visite samedi ?');
    await tester.tap(find.widgetWithText(FilledButton, 'Accepter').last);
    await tester.pumpAndSettle();

    expect(requests.single['variables'],
        {'id': '5', 'accept': true, 'message': 'Visite samedi ?'});
    expect(find.text('Acceptée'), findsOneWidget);
    expect(find.text('Refuser'), findsNothing,
        reason: 'answered requests hide the accept/refuse buttons');
    expect(refreshed, isTrue);
  });
}
