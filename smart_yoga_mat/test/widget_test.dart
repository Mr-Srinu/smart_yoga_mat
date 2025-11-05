import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_yoga_mat/main.dart';

void main() {
  testWidgets('App launches and shows main screen', (WidgetTester tester) async {
    // Build the app
    await tester.pumpWidget(const BluetoothPrototypeApp());

    // Wait for initial build
    await tester.pumpAndSettle();

    // Check that app title and buttons exist
    expect(find.text('Bluetooth Prototype'), findsOneWidget);
    expect(find.text('Scan BLE'), findsOneWidget);
    expect(find.text('Discover Classic'), findsOneWidget);
  });
}
