import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

class Stop {
  const Stop(this.nameAr, this.nameEn, this.addrAr, this.addrEn, this.bags, this.eta, this.kg, this.noteAr, this.noteEn);
  final String nameAr, nameEn, addrAr, addrEn;
  final int bags;
  final String eta;
  final double kg;
  final String noteAr, noteEn;
}

const sampleStops = [
  Stop('كافيه المثال', 'Example Café', 'شارع المثال 1', 'Example St 1', 3, '10:10', 12, 'ادخل من الباب الخلفي.', 'Use the back door.'),
  Stop('سارة', 'Sara', 'شارع المثال 2', 'Example St 2', 1, '10:35', 4, 'الدور التاني، شقة 4.', 'Second floor, flat 4.'),
  Stop('مطعم المثال', 'Example Restaurant', 'شارع المثال 3', 'Example St 3', 5, '11:05', 20, 'اتصل قبل الوصول.', 'Call before arrival.'),
  Stop('عميل 4', 'Customer 4', 'شارع المثال 4', 'Example St 4', 2, '11:30', 7, '—', '—'),
];

/// Preview only. In the real app the code is checked by the server and never shown to the driver.
const demoHandoverCode = '4821';

enum StopStatus { todo, done, skipped }

class DriverState {
  DriverState({
    this.stops = sampleStops,
    this.started = false,
    this.checks = const [false, false, false, false],
    List<StopStatus>? status,
    List<int>? bags,
    this.warehouseOk = false,
    this.prefs = const [true, true, false],
    this.routeId,
    this.shipmentIds = const [],
    this.loading = false,
  })  : status = status ?? List.filled(stops.length, StopStatus.todo),
        bags = bags ?? [for (final s in stops) s.bags];
  final List<Stop> stops;
  final bool started;
  final List<bool> checks;
  final List<StopStatus> status;
  final List<int> bags;
  final bool warehouseOk;
  final List<bool> prefs;

  /// Set only for a real route loaded from the server.
  final int? routeId;
  final List<int> shipmentIds;
  final bool loading;

  int count(StopStatus s) => status.where((x) => x == s).length;
  int get nextIndex => status.indexOf(StopStatus.todo);
  bool get allHandled => nextIndex < 0;
  bool get ready => checks.every((x) => x);
  int get bagsCollected {
    var n = 0;
    for (var i = 0; i < status.length; i++) {
      if (status[i] == StopStatus.done) n += bags[i];
    }
    return n;
  }

  DriverState copyWith({bool? started, List<bool>? checks, List<StopStatus>? status, List<int>? bags, bool? warehouseOk, List<bool>? prefs, bool? loading}) => DriverState(
        stops: stops,
        started: started ?? this.started,
        checks: checks ?? this.checks,
        status: status ?? this.status,
        bags: bags ?? this.bags,
        warehouseOk: warehouseOk ?? this.warehouseOk,
        prefs: prefs ?? this.prefs,
        routeId: routeId,
        shipmentIds: shipmentIds,
        loading: loading ?? this.loading,
      );
}

final driverProvider = NotifierProvider<DriverNotifier, DriverState>(DriverNotifier.new);

class DriverNotifier extends Notifier<DriverState> {
  @override
  DriverState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) {
      Future.microtask(refresh);
      return DriverState(stops: const [], loading: true);
    }
    return DriverState();
  }

  bool get isReal => _real;

  /// Uploads the bag photo and attaches it to the collected stop. Returns an error message or null.
  Future<String?> sendProof(int i, Uint8List bytes, String filename) async {
    try {
      final dio = ref.read(dioProvider);
      final up = await dio.post('/uploads/image', data: FormData.fromMap({'file': MultipartFile.fromBytes(bytes, filename: filename)}));
      final url = (up.data as Map<String, dynamic>)['url'] as String;
      await dio.post('/driver/stops/${state.shipmentIds[i]}/proof', data: {'imageUrl': url});
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  bool get _real {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  /// Loads today's real route. Does nothing in preview mode.
  Future<void> refresh() async {
    if (!_real) return;
    try {
      final res = await ref.read(dioProvider).get('/driver/routes');
      final routes = ((res.data as Map<String, dynamic>)['routes'] as List).cast<Map<String, dynamic>>();
      final route = routes.where((r) => r['status'] != 'done').firstOrNull;
      if (route == null) {
        state = DriverState(stops: const [], prefs: state.prefs);
        return;
      }
      final raw = (route['stops'] as List).cast<Map<String, dynamic>>().where((s) => s['status'] != 'cancelled' && s['status'] != 'rejected').toList();
      final list = [
        for (final s in raw)
          Stop(
            ((s['customer'] as Map?)?['name'] ?? '') as String,
            ((s['customer'] as Map?)?['name'] ?? '') as String,
            '${(s['lat'] as num).toStringAsFixed(4)}, ${(s['lng'] as num).toStringAsFixed(4)}',
            '${(s['lat'] as num).toStringAsFixed(4)}, ${(s['lng'] as num).toStringAsFixed(4)}',
            1,
            '—',
            0,
            '—',
            '—',
          ),
      ];
      state = DriverState(
        stops: list,
        started: route['status'] == 'in_progress',
        checks: state.checks,
        status: [for (final s in raw) s['collectedAt'] != null ? StopStatus.done : StopStatus.todo],
        prefs: state.prefs,
        routeId: (route['id'] as num).toInt(),
        shipmentIds: [for (final s in raw) (s['shipmentId'] as num).toInt()],
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  /// Types the customer's code. The server checks it. Returns null on success, or a message to show.
  Future<String?> collect(int i, String code) async {
    if (!_real) return null;
    try {
      await ref.read(dioProvider).post('/driver/stops/${state.shipmentIds[i]}/collect', data: {'handoverCode': code});
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  void toggleCheck(int i) => state = state.copyWith(checks: [for (var k = 0; k < 4; k++) k == i ? !state.checks[k] : state.checks[k]]);
  Future<void> start() async {
    if (!state.ready) return;
    final id = state.routeId;
    if (_real && id != null) {
      try {
        await ref.read(dioProvider).post('/driver/routes/$id/start');
      } catch (_) {
        return;
      }
    }
    state = state.copyWith(started: true);
  }

  void _mark(int i, StopStatus s) {
    if (state.status[i] != StopStatus.todo) return;
    state = state.copyWith(status: [for (var k = 0; k < state.status.length; k++) k == i ? s : state.status[k]]);
  }

  void complete(int i, int bagCount) {
    if (state.status[i] != StopStatus.todo) return;
    state = state.copyWith(bags: [for (var k = 0; k < state.bags.length; k++) k == i ? bagCount : state.bags[k]]);
    _mark(i, StopStatus.done);
  }

  void skip(int i) => _mark(i, StopStatus.skipped);
  void confirmWarehouse() => state = state.copyWith(warehouseOk: true);
  void togglePref(int i) => state = state.copyWith(prefs: [for (var k = 0; k < 3; k++) k == i ? !state.prefs[k] : state.prefs[k]]);

  /// Closing the shift is only possible after the warehouse employee confirmed the handover.
  bool finishShift() {
    if (!state.warehouseOk) return false;
    state = DriverState(prefs: state.prefs, stops: state.stops, routeId: state.routeId, shipmentIds: state.shipmentIds);
    return true;
  }
}
