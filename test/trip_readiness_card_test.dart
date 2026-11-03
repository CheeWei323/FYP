import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/theme/app_theme.dart';
import 'package:fyp/widgets/trip_preparation_widgets.dart';

typedef ReadinessOutput = ({
  String score,
  String status,
  List<LinearProgressIndicator> bars,
});

Future<ReadinessOutput> renderReadiness(
  WidgetTester tester, {
  required int completed,
  required int total,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TripReadinessCard(
            progressFuture: Future<Map<String, int>>.value({
              'completed': completed,
              'total': total,
            }),
            onRetry: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final card = find.byType(TripReadinessCard);
  final texts = tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((text) => text.data)
      .whereType<String>()
      .toList();
  return (
    score: texts.firstWhere(
      (text) => text == 'Not available' || RegExp(r'^\d+%$').hasMatch(text),
      orElse: () => '<missing>',
    ),
    status: texts.firstWhere(
      (text) =>
          text == 'No requirements available' ||
          text == 'All requirements completed' ||
          RegExp(r'^\d+ requirements? remaining$').hasMatch(text),
      orElse: () => '<missing>',
    ),
    bars: tester
        .widgetList<LinearProgressIndicator>(
          find.descendant(
            of: card,
            matching: find.byType(LinearProgressIndicator),
          ),
        )
        .toList(),
  );
}

void main() {
  testWidgets('RS01 empty checklist shows unavailable readiness', (
    tester,
  ) async {
    final actual = await renderReadiness(tester, completed: 0, total: 0);
    // ignore: avoid_print
    print('RS01 score: expected=Not available, actual=${actual.score}');
    // ignore: avoid_print
    print(
      'RS01 status: expected=No requirements available, actual=${actual.status}',
    );
    // ignore: avoid_print
    print('RS01 progress bars: expected=0, actual=${actual.bars.length}');
    expect(actual.score, 'Not available');
    expect(actual.status, 'No requirements available');
    expect(actual.bars, isEmpty);
    expect(find.text('0%'), findsNothing);
    expect(find.text('All requirements completed'), findsNothing);
    expect(
      find.text('A score appears when applicable requirements are available.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RS02 partial completion rounds the displayed score', (
    tester,
  ) async {
    final actual = await renderReadiness(tester, completed: 2, total: 3);
    expect(actual.bars, hasLength(1));
    final progress = actual.bars.single.value;
    // ignore: avoid_print
    print('RS02 score: expected=67%, actual=${actual.score}');
    // ignore: avoid_print
    print(
      'RS02 status: expected=1 requirement remaining, actual=${actual.status}',
    );
    // ignore: avoid_print
    print(
      'RS02 progress: expected=0.666667, actual=${progress?.toStringAsFixed(6)}',
    );
    expect(actual.score, '67%');
    expect(actual.status, '1 requirement remaining');
    expect(progress, closeTo(2 / 3, 1e-9));
    expect(
      find.text('2 of 3 applicable requirements completed.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RS03 full completion shows all requirements completed', (
    tester,
  ) async {
    final actual = await renderReadiness(tester, completed: 3, total: 3);
    expect(actual.bars, hasLength(1));
    final progress = actual.bars.single.value;
    // ignore: avoid_print
    print('RS03 score: expected=100%, actual=${actual.score}');
    // ignore: avoid_print
    print(
      'RS03 status: expected=All requirements completed, actual=${actual.status}',
    );
    // ignore: avoid_print
    print('RS03 progress: expected=1.0, actual=$progress');
    expect(actual.score, '100%');
    expect(actual.status, 'All requirements completed');
    expect(progress, 1.0);
    expect(
      find.text('3 of 3 applicable requirements completed.'),
      findsOneWidget,
    );
    expect(find.textContaining('remaining'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
