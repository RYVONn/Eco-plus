import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

/// Materials as in the design. Factors and prices are placeholders until real quotes exist.
class Mat {
  const Mat(this.ar, this.en, this.color, this.factor, this.price, this.capacity, this.code);
  final String ar, en;
  final Color color;
  final double factor;
  final double price;
  final double capacity;
  final String code;
}

const mats = [
  Mat('بلاستيك', 'Plastic', Color(0xFFCFE6FF), 1.0, 8, 500, 'PL'),
  Mat('ورق', 'Paper', Color(0xFFFFF1C2), 0.6, 4, 400, 'PA'),
  Mat('كرتون', 'Cardboard', Color(0xFFEAD7BE), 0.5, 3, 500, 'CB'),
  Mat('معادن', 'Metal', Color(0xFFDDE3E8), 0.0, 20, 100, 'MT'),
];

const silverMultiplier = 1.2;

/// Points for a citizen: weight x material factor x level multiplier, only after weighing.
double pointsFor(List<double> weights, double level) {
  var sum = 0.0;
  for (var i = 0; i < mats.length; i++) {
    sum += weights[i] * mats[i].factor;
  }
  return sum * level;
}

/// Cash for a business seller: weight x price per kg.
double payoutFor(List<double> weights) {
  var sum = 0.0;
  for (var i = 0; i < mats.length; i++) {
    sum += weights[i] * mats[i].price;
  }
  return sum;
}

double totalKg(List<double> w) => w.fold(0.0, (a, b) => a + b);

enum ShipStatus { waiting, weighed, rejected }

class EmpShip {
  const EmpShip({required this.id, required this.whoAr, required this.whoEn, required this.biz, required this.est, this.status = ShipStatus.waiting, this.weights, this.level = 1.0});
  final int id;
  final String whoAr, whoEn;
  final bool biz;
  final List<double> est;
  final ShipStatus status;
  final List<double>? weights;
  final double level;

  EmpShip copyWith({ShipStatus? status, List<double>? weights}) =>
      EmpShip(id: id, whoAr: whoAr, whoEn: whoEn, biz: biz, est: est, level: level, status: status ?? this.status, weights: weights ?? this.weights);

  double get result => biz ? payoutFor(weights ?? est) : pointsFor(weights ?? est, level);
}

class EmpBatch {
  const EmpBatch({required this.mat, required this.kg, this.closed = false, required this.sources});
  final int mat;
  final double kg;
  final bool closed;
  final List<(int, double)> sources;

  String get code => 'B-${mats[mat].code}-0${7 + mat}';
  double get fill => kg / mats[mat].capacity;

  EmpBatch copyWith({double? kg, bool? closed, List<(int, double)>? sources}) =>
      EmpBatch(mat: mat, kg: kg ?? this.kg, closed: closed ?? this.closed, sources: sources ?? this.sources);
}

class EmpState {
  const EmpState({required this.ships, required this.batches, this.ledger = 12, this.shiftClosed = false});
  final List<EmpShip> ships;
  final List<EmpBatch> batches;
  final int ledger;
  final bool shiftClosed;

  int count(ShipStatus s) => ships.where((x) => x.status == s).length;
  double get kgToday => ships.where((x) => x.status == ShipStatus.weighed).fold(0.0, (a, x) => a + totalKg(x.weights!));

  EmpShip? byId(int id) {
    for (final s in ships) {
      if (s.id == id) return s;
    }
    return null;
  }

  EmpState copyWith({List<EmpShip>? ships, List<EmpBatch>? batches, int? ledger, bool? shiftClosed}) =>
      EmpState(ships: ships ?? this.ships, batches: batches ?? this.batches, ledger: ledger ?? this.ledger, shiftClosed: shiftClosed ?? this.shiftClosed);
}

final employeeProvider = NotifierProvider<EmployeeNotifier, EmpState>(EmployeeNotifier.new);

class EmployeeNotifier extends Notifier<EmpState> {
  @override
  EmpState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) {
      Future.microtask(refresh);
      return const EmpState(ships: [], batches: [EmpBatch(mat: 0, kg: 0, sources: []), EmpBatch(mat: 1, kg: 0, sources: []), EmpBatch(mat: 2, kg: 0, sources: []), EmpBatch(mat: 3, kg: 0, sources: [])]);
    }
    return _sample;
  }

  bool get _real {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  Map<int, int> _matIds = {};

  static int? _slot(String name) {
    final n = name.toLowerCase();
    if (n.contains('plastic')) return 0;
    if (n.contains('paper')) return 1;
    if (n.contains('cardboard')) return 2;
    if (n.contains('alumin') || n.contains('metal')) return 3;
    return null;
  }

  List<Map<String, dynamic>> _items(dynamic data) {
    final list = data is List ? data : (data as Map<String, dynamic>)['items'] as List? ?? const [];
    return list.cast<Map<String, dynamic>>();
  }

  /// Loads real shipments, material ids and stock. Does nothing in preview mode.
  Future<void> refresh() async {
    if (!_real) return;
    try {
      final dio = ref.read(dioProvider);
      final mres = await dio.get('/materials');
      final ids = <int, int>{};
      for (final m in _items(mres.data)) {
        final slot = _slot('${m['name']}');
        if (slot != null && !ids.containsKey(slot)) ids[slot] = m['id'] as int;
      }
      _matIds = ids;
      final sres = await dio.get('/shipments', queryParameters: {'limit': 50});
      final ships = <EmpShip>[];
      for (final r in _items(sres.data)) {
        final st = '${r['status']}';
        final status = switch (st) { 'collected' => ShipStatus.waiting, 'weighed' => ShipStatus.weighed, 'rejected' => ShipStatus.rejected, _ => null };
        if (status == null) continue;
        final id = r['id'] as int;
        final biz = r['sourceType'] == 'business';
        List<double>? weights;
        final w = r['weighing'] as Map<String, dynamic>?;
        if (w != null && w['accepted'] == true) {
          weights = [0, 0, 0, 0];
          final slot = ids.entries.where((e) => e.value == w['materialTypeId']).firstOrNull?.key ?? 0;
          weights[slot] = double.tryParse('${w['actualWeightKg']}') ?? 0;
        }
        ships.add(EmpShip(id: id, whoAr: 'شحنة #$id', whoEn: 'Shipment #$id', biz: biz, est: const [0, 0, 0, 0], status: status, weights: weights));
      }
      final stock = await dio.get('/warehouse/stock');
      final kg = [0.0, 0.0, 0.0, 0.0];
      for (final it in _items((stock.data as Map<String, dynamic>)['items'] ?? const [])) {
        final slot = _slot('${it['material']}');
        if (slot != null) kg[slot] += double.tryParse('${it['weightKg']}') ?? 0;
      }
      state = state.copyWith(ships: ships, batches: [for (var i = 0; i < mats.length; i++) EmpBatch(mat: i, kg: kg[i], sources: const [])]);
    } catch (_) {}
  }

  /// Real weigh: the backend takes one material per shipment. Returns an error message or null.
  Future<String?> weighReal(int id, List<double> weights, {String? grade}) async {
    final used = [for (var i = 0; i < weights.length; i++) if (weights[i] > 0) i];
    if (used.length != 1) return 'الشحنة الحقيقية بتتوزن على خامة واحدة. ادخل وزن خامة واحدة بس.';
    final matId = _matIds[used.first];
    if (matId == null) return 'الخامة دي مش موجودة في الباك إند.';
    try {
      await ref.read(dioProvider).post('/shipments/$id/weigh', data: {'materialTypeId': matId, 'actualWeightKg': double.parse(weights[used.first].toStringAsFixed(3)), 'accepted': true, 'grade': ?grade});
      await refresh();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  Future<String?> rejectReal(int id, String reason) async {
    try {
      await ref.read(dioProvider).post('/shipments/$id/weigh', data: {'actualWeightKg': 0, 'accepted': false, 'rejectReason': reason});
      await refresh();
      return null;
    } catch (e) {
      return ApiError.from(e).message;
    }
  }

  bool get isReal => _real;

  /// Looks a shipment up by its QR text. Returns the shipment id, or an error message.
  Future<({int? id, String? error})> lookupQr(String code) async {
    try {
      final res = await ref.read(dioProvider).get('/shipments/by-qr/${Uri.encodeComponent(code.trim())}');
      final r = res.data as Map<String, dynamic>;
      final id = r['id'] as int;
      switch ('${r['status']}') {
        case 'collected':
          if (state.byId(id) == null) {
            state = state.copyWith(ships: [EmpShip(id: id, whoAr: 'شحنة #$id', whoEn: 'Shipment #$id', biz: r['sourceType'] == 'business', est: const [0, 0, 0, 0]), ...state.ships]);
          }
          return (id: id, error: null);
        case 'weighed':
          return (id: null, error: 'الشحنة دي اتوزنت قبل كده.');
        case 'rejected' || 'cancelled':
          return (id: null, error: 'الشحنة دي اتقفلت.');
        default:
          return (id: null, error: 'الشحنة لسه ماوصلتش المخزن. السواق لازم يستلمها الأول.');
      }
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    }
  }

  static const _sample = EmpState(
        ships: [
          EmpShip(id: 1052, whoAr: 'كافيه المثال', whoEn: 'Example Café', biz: true, est: [6, 0, 4, 0]),
          EmpShip(id: 1051, whoAr: 'سارة', whoEn: 'Sara', biz: false, est: [3, 2, 0, 0], level: silverMultiplier),
          EmpShip(id: 1050, whoAr: 'عمر', whoEn: 'Omar', biz: false, est: [0, 4, 3, 0]),
          EmpShip(id: 1048, whoAr: 'مطعم المثال', whoEn: 'Example Restaurant', biz: true, est: [5, 0, 0, 3]),
        ],
        batches: [
          EmpBatch(mat: 0, kg: 312, sources: [(1044, 120), (1046, 98), (1047, 94)]),
          EmpBatch(mat: 1, kg: 180, sources: [(1043, 110), (1045, 70)]),
          EmpBatch(mat: 2, kg: 410, sources: [(1040, 200), (1042, 210)]),
          EmpBatch(mat: 3, kg: 40, sources: [(1041, 40)]),
        ],
      );

  /// One all-or-nothing step. Saving the same shipment twice changes nothing.
  bool saveWeights(int id, List<double> weights) {
    final ship = state.byId(id);
    if (ship == null || ship.status != ShipStatus.waiting) return false;
    final batches = [...state.batches];
    var entries = 0;
    for (var i = 0; i < mats.length; i++) {
      if (weights[i] <= 0) continue;
      entries++;
      final b = batches[i];
      batches[i] = b.copyWith(kg: b.kg + weights[i], sources: [...b.sources, (id, weights[i])]);
    }
    state = state.copyWith(
      ships: [for (final s in state.ships) s.id == id ? s.copyWith(status: ShipStatus.weighed, weights: weights) : s],
      batches: batches,
      ledger: state.ledger + entries,
    );
    return true;
  }

  void reject(int id) {
    final ship = state.byId(id);
    if (ship == null || ship.status != ShipStatus.waiting) return;
    state = state.copyWith(ships: [for (final s in state.ships) s.id == id ? s.copyWith(status: ShipStatus.rejected) : s]);
  }

  void closeBatch(int index) => state = state.copyWith(batches: [for (var i = 0; i < state.batches.length; i++) i == index ? state.batches[i].copyWith(closed: true) : state.batches[i]]);

  void closeShift() => state = state.copyWith(shiftClosed: true);
}
