import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/site/site_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(child: MaterialApp(theme: buildTheme(Brightness.light), home: const SiteApp())));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('site moves between pages, opens a question and sends the demo form', (tester) async {
    await _pump(tester, const Size(1280, 900));
    expect(find.text('تلات خطوات'), findsOneWidget);
    await tester.tap(find.text('إزاي بتشتغل').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('هل المكافآت متاحة؟'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('هل المكافآت متاحة؟'));
    await tester.pumpAndSettle();
    expect(find.textContaining('كارت ولاء'), findsOneWidget);
    await tester.tap(find.text('الأسعار').first);
    await tester.pumpAndSettle();
    expect(find.text('معادن'), findsWidgets);
    await tester.tap(find.text('ابدأ').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ابعت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ابعت'));
    await tester.pump();
    expect(find.text('وصلنا طلبك (تجربة)'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('site fits a phone screen and the menu opens', (tester) async {
    await _pump(tester, const Size(390, 800));
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عننا'));
    await tester.pumpAndSettle();
    expect(find.text('وزن صادق'), findsOneWidget);
  });
}
