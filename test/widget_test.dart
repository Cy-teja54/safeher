import 'package:flutter_test/flutter_test.dart';
import 'package:safeher/main.dart';

void main() {
  testWidgets('App renders SafeHer title', (WidgetTester tester) async {
    await tester.pumpWidget(const SafeHerApp());
    expect(find.text('SafeHer'), findsOneWidget);
  });
}
