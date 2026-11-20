import 'package:ecoplus_app/roles/driver/driver_logic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shift starts only after the whole vehicle check', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(driverProvider.notifier);
    n.start();
    expect(c.read(driverProvider).started, isFalse);
    for (var i = 0; i < 4; i++) {
      n.toggleCheck(i);
    }
    n.start();
    expect(c.read(driverProvider).started, isTrue);
  });

  test('a stop is handled once and the shift closes only after warehouse confirmation', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(driverProvider.notifier);
    n.complete(0, 4);
    n.skip(0);
    expect(c.read(driverProvider).status[0], StopStatus.done);
    expect(c.read(driverProvider).bagsCollected, 4);
    n.skip(1);
    n.complete(2, 5);
    n.skip(3);
    expect(c.read(driverProvider).allHandled, isTrue);
    expect(n.finishShift(), isFalse);
    n.confirmWarehouse();
    expect(n.finishShift(), isTrue);
    expect(c.read(driverProvider).count(StopStatus.todo), 4);
  });
}
