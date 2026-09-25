import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'src/home_page.dart';

void main() => runApp(const ImmoiziManagerApp());

class ImmoiziManagerApp extends StatelessWidget {
  const ImmoiziManagerApp({this.client, super.key});

  final GraphQLClient? client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Immoizi Manager',
      theme: AppTheme.light(),
      home: ManagerHomePage(client: client),
    );
  }
}
