import 'package:flutter_test/flutter_test.dart';
import 'package:tapir/main.dart';

void main() {
  testWidgets('app launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const TapirApp());

    // verify the app title is present
    expect(find.text('Tapir'), findsOneWidget);
  });
}
