import 'dart:convert';

import 'package:http/http.dart' as http;

/// Enterprise-grade API client: connection reuse, timeouts, optional GET cache.
/// Use [ApiClient.instance] everywhere instead of raw [http.get] for faster loads.
///
/// For shared APK (friends testing): build with
///   flutter build apk --release --dart-define=API_BASE_URL=https://your-backend.com
/// so the app uses your deployed backend instead of localhost.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  static const String _defaultBaseUrl = 'http://localhost:8000';
  static String get baseUrl {
    const fromEnv = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: _defaultBaseUrl,
    );
    return fromEnv.isEmpty ? _defaultBaseUrl : fromEnv;
  }
  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration cacheTtl = Duration(seconds: 45);

  http.Client? _client;
  final Map<String, _CacheEntry> _getCache = {};

  http.Client get _clientOrCreate {
    _client ??= http.Client();
    return _client!;
  }

  /// GET with optional cache. Use [useCache: true] for list/dashboard endpoints.
  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
    bool useCache = true,
  }) async {
    final uri = queryParameters != null && queryParameters.isNotEmpty
        ? Uri.parse(baseUrl + path).replace(queryParameters: queryParameters)
        : Uri.parse(baseUrl + path);
    final key = uri.toString();

    if (useCache) {
      final cached = _getCache[key];
      if (cached != null && !cached.isExpired) {
        return http.Response(cached.body, cached.statusCode);
      }
    }

    final response = await _clientOrCreate
        .get(uri)
        .timeout(receiveTimeout);

    if (useCache && response.statusCode >= 200 && response.statusCode < 300) {
      _getCache[key] = _CacheEntry(
        body: response.body,
        statusCode: response.statusCode,
        cachedAt: DateTime.now(),
      );
    }
    return response;
  }

  /// POST; clears GET cache so next list/dashboard load is fresh.
  Future<http.Response> post(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await _clientOrCreate
        .post(Uri.parse(baseUrl + path), headers: headers, body: body, encoding: encoding)
        .timeout(receiveTimeout);
    _clearCache();
    return response;
  }

  /// PATCH; clears GET cache.
  Future<http.Response> patch(
    String path, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    final response = await _clientOrCreate
        .patch(Uri.parse(baseUrl + path), headers: headers, body: body, encoding: encoding)
        .timeout(receiveTimeout);
    _clearCache();
    return response;
  }

  /// DELETE; clears GET cache.
  Future<http.Response> delete(String path) async {
    final response = await _clientOrCreate
        .delete(Uri.parse(baseUrl + path))
        .timeout(receiveTimeout);
    _clearCache();
    return response;
  }

  void _clearCache() {
    if (_getCache.isNotEmpty) _getCache.clear();
  }

  /// Call when user explicitly refreshes (e.g. pull-to-refresh) to force fresh data.
  void invalidateCache() => _clearCache();

  /// Release the HTTP client (e.g. on app dispose).
  void close() {
    _client?.close();
    _client = null;
    _clearCache();
  }
}

class _CacheEntry {
  final String body;
  final int statusCode;
  final DateTime cachedAt;

  _CacheEntry({required this.body, required this.statusCode, required this.cachedAt});

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > ApiClient.cacheTtl;
}
