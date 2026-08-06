import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:territory_wars/main.dart';

void main() {
  testWidgets('Start screen shows nickname field and a disabled Start button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TerritoryWarsApp());

    expect(find.text('Territory Wars'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Start is disabled until a nickname is typed and a color is picked.
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('Start enables after valid nickname + color are chosen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TerritoryWarsApp());

    await tester.enterText(find.byType(TextField), 'TrailBlazer');
    await tester.pump();

    // Tap the first color swatch.
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets('Banned nickname shows an error and blocks navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const TerritoryWarsApp());

    await tester.enterText(find.byType(TextField), 'fuck');
    await tester.pump();
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Start'));
    await tester.pump();

    expect(find.textContaining("isn't allowed"), findsOneWidget);
  });
}
