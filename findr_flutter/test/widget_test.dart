import 'package:flutter_test/flutter_test.dart';
import 'package:findr_flutter/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const WayvioApp());
    await tester.pump();
    expect(find.text('Wayvio'), findsWidgets);
  });
}
