import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_pipe/main.dart';

void main() {
  testWidgets('App should build', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FitnessPipeApp());

    // Verify app title is displayed
    expect(find.text('FitnessPipe'), findsOneWidget);
  });
}
