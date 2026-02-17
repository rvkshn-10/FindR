// Basic Flutter widget test for Wayvio app.

import 'package:flutter_test/flutter_test.dart';
import 'package:findr_flutter/main.dart';

void main() {
  testWidgets('App loads and shows search screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WayvioApp());

    expect(find.text('What do you need?'), findsOneWidget);
    expect(find.text('Supply Map'), findsWidgets);
  });
}
