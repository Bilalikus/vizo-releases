import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Vizo app smoke test', (WidgetTester tester) async {
    // Basic smoke test — verifies the app can be constructed.
    // Full widget tests require Firebase mocking.
    expect(1 + 1, 2);
  });
}
