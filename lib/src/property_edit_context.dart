import 'package:flutter/material.dart';

class PropertyEditContext {
  const PropertyEditContext(
      {required this.endpoint, required this.token, required this.onUpdated});

  final String endpoint;
  final String token;
  final VoidCallback onUpdated;

  bool get canEdit => token.isNotEmpty;

  String get mediaEndpoint {
    final uri = Uri.parse(endpoint);
    return '${uri.scheme}://${uri.authority}';
  }
}
