import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'src/home_page.dart';
import 'src/i18n/manager_strings.dart';

Future<void> main() => runImmoiziApp(const ImmoiziManagerApp());

class ImmoiziManagerApp extends StatelessWidget {
  const ImmoiziManagerApp({this.client, super.key});

  final GraphQLClient? client;

  @override
  Widget build(BuildContext context) => ImmoiziApp(
        title: 'Immoizi Manager',
        translations: managerEnglish,
        home: (_) => ManagerHomePage(client: client),
      );
}
