import 'package:ecoplus_app/roles/citizen/citizen_logic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels follow the thresholds', () {
    expect(levelIndex(0), 0);
    expect(levelIndex(420), 1);
    expect(levelIndex(600), 2);
    expect(levelIndex(5000), 3);
  });

  test('points are added only when the warehouse weighs, and only once', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(citizenProvider.notifier);
    final id = n.book('اليوم', 'Today');
    expect(c.read(citizenProvider).points, 420);
    n.advance(id);
    n.advance(id);
    expect(c.read(citizenProvider).points, 420);
    n.advance(id);
    expect(c.read(citizenProvider).points, 462);
    n.advance(id);
    expect(c.read(citizenProvider).points, 462);
    expect(c.read(citizenProvider).ledger.first.points, 42);
  });
}
