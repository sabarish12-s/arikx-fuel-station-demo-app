import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rk_fuels/services/api_client.dart';
import 'package:rk_fuels/services/api_response_cache.dart';
import 'package:rk_fuels/services/auth_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token-1',
      'auth_user': jsonEncode({
        'id': 'user-1',
        'name': 'Tester',
        'email': 'tester@example.com',
        'role': 'sales',
        'status': 'approved',
        'stationId': 'station-1',
      }),
    });
  });

  test(
    'cached GET returns cached body immediately and refreshes in background',
    () async {
      final authService = AuthService();
      final cacheKey = await ApiResponseCache.scopedKey(
        authService: authService,
        path: '/sales/dashboard',
      );
      expect(cacheKey, isNotNull);
      await ApiResponseCache.write(
        key: cacheKey!,
        path: '/sales/dashboard',
        statusCode: 200,
        body: '{"source":"cache"}',
        headers: const {'content-type': 'application/json'},
      );

      final client = _FakeHttpClient([
        http.Response('{"source":"network"}', 200),
      ]);
      final apiClient = ApiClient(authService, httpClient: client);

      final response = await apiClient.get('/sales/dashboard', useCache: true);

      expect(response.body, '{"source":"cache"}');
      expect(response.headers['x-rk-cache'], 'hit');

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final updated = await ApiResponseCache.read(cacheKey);
      expect(updated?.body, '{"source":"network"}');
      expect(client.requests, hasLength(1));
    },
  );

  test('forceRefresh bypasses cache and updates cached body', () async {
    final authService = AuthService();
    final cacheKey = await ApiResponseCache.scopedKey(
      authService: authService,
      path: '/inventory/dashboard',
    );
    expect(cacheKey, isNotNull);
    await ApiResponseCache.write(
      key: cacheKey!,
      path: '/inventory/dashboard',
      statusCode: 200,
      body: '{"source":"old"}',
      headers: const {},
    );

    final client = _FakeHttpClient([http.Response('{"source":"fresh"}', 200)]);
    final apiClient = ApiClient(authService, httpClient: client);

    final response = await apiClient.get(
      '/inventory/dashboard',
      useCache: true,
      forceRefresh: true,
    );

    expect(response.body, '{"source":"fresh"}');
    final updated = await ApiResponseCache.read(cacheKey);
    expect(updated?.body, '{"source":"fresh"}');
    expect(client.requests, hasLength(1));
  });

  test(
    'networkFirst cache policy returns fresh entries instead of stale cache',
    () async {
      final authService = AuthService();
      final cacheKey = await ApiResponseCache.scopedKey(
        authService: authService,
        path: '/sales/entries',
      );
      expect(cacheKey, isNotNull);
      await ApiResponseCache.write(
        key: cacheKey!,
        path: '/sales/entries',
        statusCode: 200,
        body: '{"entries":[{"id":"old"}]}',
        headers: const {},
      );

      final client = _FakeHttpClient([
        http.Response('{"entries":[{"id":"fresh"}]}', 200),
      ]);
      final apiClient = ApiClient(authService, httpClient: client);

      final response = await apiClient.get(
        '/sales/entries',
        useCache: true,
        cachePolicy: ApiCachePolicy.networkFirst,
      );

      expect(response.body, '{"entries":[{"id":"fresh"}]}');
      expect(response.headers['x-rk-cache'], isNull);
      final updated = await ApiResponseCache.read(cacheKey);
      expect(updated?.body, '{"entries":[{"id":"fresh"}]}');
      expect(client.requests, hasLength(1));
    },
  );

  test(
    'networkFirst cache policy falls back to cache only after network failure',
    () async {
      final authService = AuthService();
      final cacheKey = await ApiResponseCache.scopedKey(
        authService: authService,
        path: '/management/entries',
      );
      expect(cacheKey, isNotNull);
      await ApiResponseCache.write(
        key: cacheKey!,
        path: '/management/entries',
        statusCode: 200,
        body: '{"entries":[{"id":"cached"}]}',
        headers: const {},
      );

      final client = _FakeHttpClient(const []);
      final apiClient = ApiClient(authService, httpClient: client);

      final response = await apiClient.get(
        '/management/entries',
        useCache: true,
        cachePolicy: ApiCachePolicy.networkFirst,
      );

      expect(response.body, '{"entries":[{"id":"cached"}]}');
      expect(response.headers['x-rk-cache'], 'fallback');
      expect(client.requests, hasLength(1));
    },
  );

  test('cache keys are scoped by user, station, and path', () async {
    final authService = AuthService();
    final first = await ApiResponseCache.scopedKey(
      authService: authService,
      path: '/sales/dashboard',
    );

    SharedPreferences.setMockInitialValues({
      'jwt_token': 'token-2',
      'auth_user': jsonEncode({
        'id': 'user-2',
        'name': 'Tester',
        'email': 'tester@example.com',
        'role': 'sales',
        'status': 'approved',
        'stationId': 'station-2',
      }),
    });
    final second = await ApiResponseCache.scopedKey(
      authService: AuthService(),
      path: '/sales/dashboard',
    );
    final third = await ApiResponseCache.scopedKey(
      authService: AuthService(),
      path: '/sales/entries',
    );

    expect(first, isNot(second));
    expect(second, isNot(third));
  });

  test('signOut clears cached API responses', () async {
    final authService = AuthService();
    final cacheKey = await ApiResponseCache.scopedKey(
      authService: authService,
      path: '/sales/dashboard',
    );
    expect(cacheKey, isNotNull);
    await ApiResponseCache.write(
      key: cacheKey!,
      path: '/sales/dashboard',
      statusCode: 200,
      body: '{}',
      headers: const {},
    );

    await authService.signOut();

    expect(await ApiResponseCache.read(cacheKey), isNull);
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._responses);

  final List<http.Response> _responses;
  final List<http.BaseRequest> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (_responses.isEmpty) {
      throw StateError('No fake response queued.');
    }
    final response = _responses.removeAt(0);
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(response.body)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
