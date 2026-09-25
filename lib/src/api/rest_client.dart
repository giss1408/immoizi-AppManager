import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:immoizi_core/immoizi_core.dart';

/// Video formats accepted by the backend (products/models.py).
const _videoTypes = {
  'mp4': 'mp4',
  'webm': 'webm',
  'mov': 'quicktime',
};

/// Largest video the backend accepts.
const maxVideoBytes = 10 * 1024 * 1024;

/// The media type for an uploaded video, or null when the backend would
/// reject the file's format.
MediaType? videoMediaType(String path) {
  final dot = path.lastIndexOf('.');
  final subtype =
      dot < 0 ? null : _videoTypes[path.substring(dot + 1).toLowerCase()];
  return subtype == null ? null : MediaType('video', subtype);
}

/// Sends a request to the backend's REST endpoints and decodes the JSON
/// answer, mapping failures to the same [ApiException]s as GraphQL calls.
Future<Map<String, dynamic>> sendRest(http.BaseRequest request,
    {Duration timeout = const Duration(minutes: 2)}) async {
  final http.Response response;
  try {
    response =
        await http.Response.fromStream(await request.send().timeout(timeout));
  } on TimeoutException {
    throw const NetworkException();
  } on http.ClientException {
    throw const NetworkException();
  }

  Map<String, dynamic>? payload;
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) payload = decoded;
  } on FormatException {
    payload = null;
  }

  if (response.statusCode == 401) throw const AuthException();
  if (response.statusCode < 200 || response.statusCode >= 300) {
    // 403 here means "not your listing", not an expired session.
    final message = payload?['error'] as String?;
    throw ServerException(
        message ?? 'Erreur du serveur (HTTP ${response.statusCode}).',
        statusCode: response.statusCode);
  }
  if (payload == null) {
    throw ServerException('Réponse inattendue du serveur.',
        statusCode: response.statusCode);
  }
  return payload;
}
