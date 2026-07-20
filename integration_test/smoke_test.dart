import 'package:apex/core/app_config.dart';
import 'package:apex/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots', (WidgetTester tester) async {
    if (!AppConfig.hasSupabase) {
      // CI / local runs without dart-define skip gracefully.
      await tester.pumpWidget(const app.MyApp());
      await tester.pumpAndSettle();
      expect(find.textContaining('Apex'), findsWidgets);
      return;
    }

    await tester.pumpWidget(const app.MyApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
