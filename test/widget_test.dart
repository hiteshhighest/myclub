
import 'package:flutter_test/flutter_test.dart';
import 'package:myclub/main.dart';

void main() {
  testWidgets('MyClub shows setup message without credentials',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MyClubApp(configured: false),
    );

    expect(
      find.textContaining('MyClub setup required.'),
      findsOneWidget,
    );
  });
}
