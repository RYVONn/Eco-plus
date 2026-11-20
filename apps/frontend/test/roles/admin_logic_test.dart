import 'package:ecoplus_app/roles/admin/admin_data.dart';
import 'package:ecoplus_app/roles/admin/admin_logic.dart';
import 'package:ecoplus_app/roles/admin/admin_pages_sys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every page in the navigation exists', () {
    final ids = adminPages.map((p) => p.id).toSet();
    for (final g in adminNav) {
      for (final id in g.$2) {
        expect(ids.contains(id), isTrue, reason: id);
      }
    }
  });

  test('table rows match their column count', () {
    for (final p in adminPages) {
      for (final b in p.blocks.whereType<TableBlock>()) {
        for (final r in b.rows) {
          expect(r.length, b.cols.length, reason: p.id);
        }
        expect(b.flex.length, b.cols.length, reason: p.id);
      }
    }
  });

  test('support mode is audited and can be left', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(adminProvider.notifier);
    n.startSupport('citizen', const Cell('سارة', 'Sara'));
    expect(c.read(adminProvider).support?.role, 'citizen');
    expect(c.read(adminProvider).audit.length, 1);
    n.exitSupport();
    expect(c.read(adminProvider).support, isNull);
    expect(c.read(adminProvider).audit.length, 1);
  });

  test('opening a page clears search and selection', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(adminProvider.notifier);
    n.setQuery('x');
    n.select('0:1');
    n.openPage('pickups');
    expect(c.read(adminProvider).query, '');
    expect(c.read(adminProvider).sel, isNull);
  });
}
