import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muzik_yok/main.dart';

void main() {
  testWidgets('appearance switch changes the whole app theme', (tester) async {
    await tester.pumpWidget(const MuzikYokApp());

    expect(
      Theme.of(tester.element(find.text('DÜŞÜNME SÜRESİ'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.byTooltip('Açık moda geç'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('DÜŞÜNME SÜRESİ'))).brightness,
      Brightness.light,
    );
    expect(find.byTooltip('Koyu moda geç'), findsOneWidget);
  });
}
