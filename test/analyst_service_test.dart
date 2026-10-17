import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:fyp/services/analyst_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AGGREGATE TRANSPORT AND ERROR HANDLING
  // ---------------------------------------------------------------------------
  test(
    'The client sends a token and filters and preserves decimal chart values',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/analytics/query');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {
          'metric': 'completion',
          'destinationId': 'japan',
          'purpose': 'tourism',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'overallCompletionRate': 0,
              'destinationComparison': [
                {'completionRate': 50, 'tripCount': 2},
              ],
            },
          }),
          200,
        );
      });
      addTearDown(client.close);
      final service = AnalystService(
        client: client,
        tokenProvider: () async => 'test-token',
      );
      final result = await service.getChecklistCompletionAnalytics(
        destinationId: 'japan',
        purpose: 'tourism',
      );
      expect(result['overallCompletionRate'], isA<double>());
      expect(
        result['destinationComparison'][0]['completionRate'],
        isA<double>(),
      );
      expect(result['destinationComparison'][0]['tripCount'], isA<int>());
    },
  );

  test('A signed-out client makes no HTTP request', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    addTearDown(client.close);
    final service = AnalystService(
      client: client,
      tokenProvider: () async => null,
    );
    await expectLater(service.getOverview(), throwsException);
    expect(requests, 0);
  });

  test('Access denial does not fall back to raw Firestore reads', () async {
    final client = MockClient(
      (_) async => http.Response('{"error":"Analyst access required."}', 403),
    );
    addTearDown(client.close);
    final service = AnalystService(
      client: client,
      tokenProvider: () async => 'test-token',
    );
    await expectLater(
      service.getOverview(),
      throwsA(
        predicate(
          (error) => error.toString().contains('Analyst access required.'),
        ),
      ),
    );
  });

  test(
    'Country labels remain compatible with the existing filter controls',
    () async {
      final client = MockClient(
        (_) async =>
            http.Response('{"data":[{"id":"japan","name":"Japan"}]}', 200),
      );
      addTearDown(client.close);
      final service = AnalystService(
        client: client,
        tokenProvider: () async => 'test-token',
      );
      expect(await service.getAnalyticsFilterCountries(), [
        {'id': 'japan', 'name': 'Japan'},
      ]);
    },
  );
}
