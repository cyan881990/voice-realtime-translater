import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_realtime_translater/ui/widgets/app_logo.dart';

void main() {
  testWidgets('logo renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AppLogo(size: 48, background: Colors.black)),
    ));
    expect(find.byType(AppLogo), findsOneWidget);
  });
}
