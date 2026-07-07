import 'package:flutter_test/flutter_test.dart';
import 'package:apex/theme.dart';

void main() {
  test('UniversalTheme brand colors are defined', () {
    expect(UniversalTheme.accent.toARGB32(), 0xFFD97706);
    expect(UniversalTheme.darkSlate.toARGB32(), 0xFF3E1F13);
    expect(UniversalTheme.alertRed.toARGB32(), 0xFF991B1B);
  });
}
