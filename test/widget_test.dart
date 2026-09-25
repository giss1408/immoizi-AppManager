import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:immoizi_app_manager/main.dart';
import 'package:immoizi_app_manager/src/api/rest_client.dart';
import 'package:immoizi_core/immoizi_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200,
    headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _dashboard({List<Map<String, dynamic>>? notifications}) =>
    {
      'myLandlordProperties': [
        {
          'id': '9',
          'title': 'Immeuble Plateau',
          'city': 'Abidjan',
          'district': 'Plateau',
          'rooms': 12,
          'surfaceM2': 900,
          'price': 4500000,
          'listingStatus': 'Disponible',
          'category': {'title': 'Business'},
        }
      ],
      'leases': [],
      'propertyDocuments': [],
      'rentPayments': [],
      'maintenanceRequests': [],
      'notifications': notifications ?? [],
      'propertyInterestRequests': [],
    };

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('signed out: shows the demo portfolio without calling the API',
      (tester) async {
    final requests = <http.Request>[];
    final client = GraphQLClient(httpClient: MockClient((request) async {
      requests.add(request);
      return _json({'data': _dashboard()});
    }));
    await tester.pumpWidget(ImmoiziManagerApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('Immoizi Manager'), findsOneWidget);
    expect(find.text('Portefeuille bailleur'), findsOneWidget);
    expect(find.byTooltip('Charger le portefeuille'), findsOneWidget);
    expect(find.text('Villa de prestige'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('restores the session and loads the real portfolio',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'manager_token': 'tok'});
    final client = GraphQLClient(
        httpClient: MockClient((_) async => _json({'data': _dashboard()})));
    await tester.pumpWidget(ImmoiziManagerApp(client: client));
    await tester.pumpAndSettle();

    expect(find.text('Immeuble Plateau'), findsOneWidget);
    expect(find.text('4 500 000 FCFA'), findsOneWidget);
  });

  testWidgets('polling reloads the dashboard only when notifications change',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({'manager_token': 'tok'});
    var dashboardLoads = 0;
    var polls = 0;
    var notifications = <Map<String, dynamic>>[];
    final client = GraphQLClient(httpClient: MockClient((request) async {
      final query = (jsonDecode(request.body) as Map)['query'] as String;
      if (query.contains('NotificationsPoll')) {
        polls++;
        return _json({
          'data': {'notifications': notifications}
        });
      }
      dashboardLoads++;
      return _json({'data': _dashboard(notifications: notifications)});
    }));
    await tester.pumpWidget(ImmoiziManagerApp(client: client));
    await tester.pumpAndSettle();
    expect(dashboardLoads, 1);

    await tester.pump(DashboardSession.pollInterval);
    await tester.pumpAndSettle();
    expect(polls, 1);
    expect(dashboardLoads, 1, reason: 'nothing changed, no full reload');

    notifications = [
      {'id': '5', 'isRead': false, 'title': 'Nouvelle demande'}
    ];
    await tester.pump(DashboardSession.pollInterval);
    await tester.pumpAndSettle();
    expect(polls, 2);
    expect(dashboardLoads, 2);
  });

  test('videoMediaType follows the backend whitelist', () {
    expect(videoMediaType('/tmp/clip.MP4')?.mimeType, 'video/mp4');
    expect(videoMediaType('/tmp/clip.mov')?.mimeType, 'video/quicktime');
    expect(videoMediaType('/tmp/clip.webm')?.mimeType, 'video/webm');
    expect(videoMediaType('/tmp/clip.avi'), isNull);
    expect(videoMediaType('/tmp/noextension'), isNull);
  });
}
