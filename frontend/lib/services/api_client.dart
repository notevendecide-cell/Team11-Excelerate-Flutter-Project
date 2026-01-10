import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? status;
  final String message;

  const ApiException(this.message, {this.status});

  @override
  String toString() => 'ApiException(status: $status, message: $message)';
}

class ApiClient {
  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  final http.Client _client;

  ApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers({required bool auth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (auth) {
      final token = await tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String path, {bool auth = true, Map<String, String>? query}) async {
    try {
      final res = await _client.get(_uri(path, query), headers: await _headers(auth: auth));
      return _decode(res);
    } on SocketException {
      throw const ApiException('Network unavailable');
    }
  }

  Future<dynamic> post(String path, {bool auth = true, Object? body}) async {
    try {
      final res = await _client.post(
        _uri(path),
        headers: await _headers(auth: auth),
        body: jsonEncode(body ?? {}),
      );
      return _decode(res);
    } on SocketException {
      throw const ApiException('Network unavailable');
    }
  }

  dynamic _decode(http.Response res) {
    final status = res.statusCode;
    final text = res.body;

    dynamic payload;
    if (text.isNotEmpty) {
      try {
        payload = jsonDecode(text);
      } catch (_) {
        payload = null;
      }
    }

    if (status >= 200 && status < 300) {
      return payload;
    }

    final message =
        (payload is Map && payload['error'] is Map && (payload['error']['message'] is String))
            ? payload['error']['message'] as String
            : 'Request failed';

    throw ApiException(message, status: status);
  }
}
