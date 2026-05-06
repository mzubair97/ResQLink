import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqlink/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const ResQLinkApp()); // or ResQLinkApp

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
