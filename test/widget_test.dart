import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_route_app/main.dart';

void main() {
  testWidgets('Delivery Assistant smoke test', (WidgetTester tester) async {
    // بناء التطبيق والتحقق من عمله بنجاح
    await tester.pumpWidget(const MyApp());

    // التحقق من ظهور التطبيق والتوافق مع MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}