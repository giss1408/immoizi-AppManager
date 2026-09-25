import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'models/dashboard.dart';

class PropertyEditContext {
  const PropertyEditContext(
      {required this.endpoint,
      required this.token,
      required this.onUpdated,
      this.categories = const [],
      GraphQLClient? client})
      : _client = client;

  final String endpoint;
  final String token;
  final VoidCallback onUpdated;
  final List<CategoryOption> categories;
  final GraphQLClient? _client;

  /// The app's shared client (injectable in tests).
  GraphQLClient get client => _client ?? GraphQLClient();

  bool get canEdit => token.isNotEmpty;

  String get mediaEndpoint {
    final uri = Uri.parse(endpoint);
    return '${uri.scheme}://${uri.authority}';
  }
}
