import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizniz_tracker/app.dart';

void main() {
  testWidgets('dashboard navigation opens the inventory placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const BiznizTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Business Overview'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The inventory module is reserved for its assigned team.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('record sale quick action opens the sales placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(const BiznizTrackerApp());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Record Sale'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Record Sale'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'The sales module is reserved for its assigned team.',
      ),
      findsOneWidget,
    );
  });
}
