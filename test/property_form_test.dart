import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_manager/src/models/dashboard.dart';
import 'package:immoizi_app_manager/src/pages/property_form_page.dart';
import 'package:immoizi_app_manager/src/property_edit_context.dart';
import 'package:immoizi_core/immoizi_core.dart';

Map<String, dynamic> _savedProperty(Map<String, dynamic> variables) => {
      'id': variables['propertyId'] ?? '42',
      'title': variables['title'],
      'city': variables['city'],
      'district': variables['district'],
      'rooms': variables['rooms'],
      'surfaceM2': variables['surfaceM2'],
      'price': variables['price'],
      'listingStatus': (variables['listingStatus'] as String).toUpperCase(),
      'category': {'title': 'Business'},
      'description': variables['description'],
    };

void main() {
  late List<Map<String, dynamic>> requests;
  late Property? popped;

  PropertyEditContext editContext() => PropertyEditContext(
        endpoint: 'http://backend.test/graphql',
        token: 'tok',
        onUpdated: () {},
        categories: const [
          CategoryOption('1', 'Residence'),
          CategoryOption('2', 'Business'),
        ],
        client: GraphQLClient(httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          final variables = body['variables'] as Map<String, dynamic>;
          final key = variables.containsKey('propertyId')
              ? 'updatePropertyListing'
              : 'createPropertyListing';
          return http.Response(
              jsonEncode({
                'data': {
                  key: {'property': _savedProperty(variables)}
                }
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        })),
      );

  Future<void> openForm(WidgetTester tester, {Property? property}) async {
    // Phone-sized screen so the whole form is laid out.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.of(context).push<Property>(
                  MaterialPageRoute(
                      builder: (_) => PropertyFormPage(
                          editContext: editContext(), property: property)));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), value);
  }

  setUp(() {
    requests = [];
    popped = null;
  });

  testWidgets('creating a listing validates, then sends every field',
      (tester) async {
    await openForm(tester);
    expect(find.text('Ajouter un bien'), findsOneWidget);

    await tester.tap(find.text('Créer le bien'));
    await tester.pumpAndSettle();
    expect(find.text('Champ obligatoire'), findsWidgets);
    expect(requests, isEmpty);

    await fill(tester, 'Titre de l’annonce', 'Bureaux Plateau');
    await fill(tester, 'Quartier', 'Plateau');
    await fill(tester, 'Pièces', '6');
    await fill(tester, 'Surface', '210');
    await fill(tester, 'Loyer mensuel', '980000');
    await fill(tester, 'Description', 'Open space climatisé');
    await tester.tap(find.text('Residence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Business').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Créer le bien'));
    await tester.tap(find.text('Créer le bien'));
    await tester.pumpAndSettle();

    final variables = requests.single['variables'] as Map<String, dynamic>;
    expect(requests.single['query'], contains('createPropertyListing'));
    expect(variables, {
      'title': 'Bureaux Plateau',
      'categoryId': '2',
      'city': 'Abidjan',
      'district': 'Plateau',
      'rooms': 6,
      'surfaceM2': 210,
      'price': 980000,
      'description': 'Open space climatisé',
      'listingStatus': 'available',
    });
    expect(popped?.id, '42');
    expect(popped?.title, 'Bureaux Plateau');
  });

  testWidgets('editing prefills the form and updates the listing',
      (tester) async {
    final property = Property(
        'Villa Cocody', 'Residence', 'Abidjan', 'Cocody', 5, 220, 920000,
        id: '7', status: 'RENTED', description: 'Piscine');
    await openForm(tester, property: property);

    expect(find.text('Modifier les informations'), findsOneWidget);
    expect(find.text('Villa Cocody'), findsOneWidget);
    expect(find.text('Loué'), findsOneWidget);

    await fill(tester, 'Loyer mensuel', '950000');
    await tester.ensureVisible(find.text('Enregistrer'));
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final variables = requests.single['variables'] as Map<String, dynamic>;
    expect(requests.single['query'], contains('updatePropertyListing'));
    expect(variables['propertyId'], '7');
    expect(variables['price'], 950000);
    expect(variables['categoryId'], '1');
    expect(variables['listingStatus'], 'rented');
    expect(popped?.price, 950000);
  });

  test('listing statuses have French labels', () {
    expect(listingStatusLabel('AVAILABLE'), 'Disponible');
    expect(listingStatusLabel('rented'), 'Loué');
    expect(listingStatusLabel('Disponible'), 'Disponible');
  });
}
