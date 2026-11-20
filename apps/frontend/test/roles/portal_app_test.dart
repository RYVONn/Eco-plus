import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/portal/portal_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget home, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: buildTheme(Brightness.light), home: home)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('client portal moves between pages and filters a table', (tester) async {
    await _pump(tester, const ClientPortalApp(), const Size(1400, 1000));
    expect(find.text('نظرة عامة'), findsWidgets);
    await tester.tap(find.text('الاستلامات').first);
    await tester.pumpAndSettle();
    expect(find.text('#P-412'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'الزمالك');
    await tester.pumpAndSettle();
    expect(find.text('#P-412'), findsNothing);
    expect(find.text('#P-377'), findsOneWidget);
    await tester.tap(find.text('#P-377'));
    await tester.pumpAndSettle();
    expect(find.text('52 kg'), findsNWidgets(2));
  });

  testWidgets('factory portal works on a narrow screen with a drawer', (tester) async {
    await _pump(tester, const FactoryPortalApp(), const Size(420, 900));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفواتير'));
    await tester.pumpAndSettle();
    expect(find.text('INV-318'), findsOneWidget);
  });
}
