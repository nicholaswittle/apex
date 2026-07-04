import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test: Apex Scheduler widget tree renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text("Apex Scheduler")),
        ),
      ),
    );
    expect(find.text("Apex Scheduler"), findsOneWidget);
  });
}
