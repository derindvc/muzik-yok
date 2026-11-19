import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzik_yok/main.dart';

void main() {
  testWidgets('custom duration combines hours and minutes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ThinkingScreen()));

    await tester.tap(find.byKey(const Key('durationPicker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customDuration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customHours')), '25');
    await tester.enterText(find.byKey(const Key('customMinutes')), '20');
    await tester.tap(find.text('Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('25 sa 20 dk'), findsOneWidget);
  });
}
