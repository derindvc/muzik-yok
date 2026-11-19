import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzik_yok/main.dart';

void main() {
  testWidgets('failed save keeps the note available for retry', (tester) async {
    var attempts = 0;
    String? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ReflectionDialog(
                  intention: 'Bir fikir',
                  onSave: (text) async {
                    attempts++;
                    if (attempts == 1) throw StateError('temporary failure');
                    saved = text;
                  },
                ),
              ),
              child: const Text('Aç'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Önemli notum');
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(
      find.text('Not kaydedilemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Önemli notum'), findsOneWidget);

    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(saved, 'Önemli notum');
    expect(find.byType(ReflectionDialog), findsNothing);
  });
}
