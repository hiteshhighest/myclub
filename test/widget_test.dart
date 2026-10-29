
import 'package:flutter_test/flutter_test.dart';
import 'package:Klubb/main.dart';

void main() {
  testWidgets('Klubb shows setup message without credentials',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyClubApp(configured: false),
    );

    expect(
      find.textContaining('Klubb setup required.'),
      findsOneWidget,
    );
  });
}
