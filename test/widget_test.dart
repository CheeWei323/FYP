import 'package:flutter_test/flutter_test.dart';
import 'package:fyp/app.dart';

void main() {
  testWidgets('TravelGuard MY onboarding screen loads',
          (WidgetTester tester) async {
        await tester.pumpWidget(const TravelGuardApp());

        expect(find.text('TravelGuard MY'), findsOneWidget);
        expect(find.text('Get Started'), findsOneWidget);
      });
}