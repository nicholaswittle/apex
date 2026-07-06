import 'package:flutter_test/flutter_test.dart';
import 'package:apex/theme.dart';

void main() {
  test('UniversalTheme brand colors are defined', () {
    expect(UniversalTheme.accent.value, 0xFFD97706);
    expect(UniversalTheme.darkSlate.value, 0xFF3E1F13);
    expect(UniversalTheme.alertRed.value, 0xFF991B1B);
  });
}
