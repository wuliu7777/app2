import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox_app/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ToolboxApp());

    // Verify that our home page loads
    expect(find.text('实用小工具集合'), findsOneWidget);
  });
}
