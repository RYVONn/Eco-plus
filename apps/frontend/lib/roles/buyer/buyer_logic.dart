import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';
import '../business/business_logic.dart' show materialSlot;

/// Lots and prices are design placeholders until real quotes exist.
class Lot {
  const Lot(this.id, this.mat, this.ar, this.en, this.gradeAr, this.gradeEn, this.formAr, this.formEn, this.avail, this.price, this.min);
  final int id;

  /// Index into bMats: 0 plastic, 1 paper, 2 cardboard, 3 metal.
  final int mat;
  final String ar, en, gradeAr, gradeEn, formAr, formEn;
  final double avail, price, min;
}

const _sampleLots = [
  Lot(1, 0, 'PET نضيف', 'Clean PET', 'نضيفة ومفروزة', 'Clean and sorted', 'بالات', 'Baled', 1800, 11, 500),
  Lot(2, 0, 'بلاستيك مخلوط', 'Mixed plastic', 'مخلوطة', 'Mixed', 'سايب', 'Loose', 240, 7, 20),
  Lot(3, 1, 'ورق أبيض مكتب', 'White office paper', 'نضيفة ومفروزة', 'Clean and sorted', 'بالات', 'Baled', 600, 6, 100),
  Lot(4, 2, 'كرتون بالات', 'Baled cardboard', 'نضيفة ومفروزة', 'Clean and sorted', 'بالات', 'Baled', 2400, 4.5, 500),
  Lot(5, 3, 'علب ألومنيوم', 'Aluminium cans', 'نضيفة ومفروزة', 'Clean and sorted', 'سايب', 'Loose', 90, 26, 10),
  Lot(6, 0, 'HDPE نضيف', 'Clean HDPE', 'نضيفة ومفروزة', 'Clean and sorted', 'بالات', 'Baled', 400, 10, 50),
];

/// The lots on offer. Sample lots in preview mode; the live catalogue in real mode.
List<Lot> lots = [..._sampleLots];

final Map<int, ({int materialTypeId, String? grade})> _lotKeys = {};

const deliveryFee = 150.0;
double bR1(double v) => (v * 10).round() / 10;
Lot lotOf(int id) => lots.firstWhere((l) => l.id == id, orElse: () => const Lot(0, 0, '—', '—', '—', '—', '—', '—', 0, 0, 0));

class BuyOrder {
  const BuyOrder({required this.id, required this.lot, required this.qty, required this.delivery, required this.stage});
  final int id, lot;
  final double qty;
  final bool delivery;

  /// 0 confirmed, 1 preparing, 2 ready or on the way, 3 delivered.
  final int stage;
  bool get done => stage >= 3;
  double get fee => delivery ? deliveryFee : 0;
  double get total => bR1(qty * lotOf(lot).price + fee);
  BuyOrder withStage(int s) => BuyOrder(id: id, lot: lot, qty: qty, delivery: delivery, stage: s);
}

class Contract {
  const Contract(this.ar, this.en, this.subAr, this.subEn, this.active);
  final String ar, en, subAr, subEn;
  final bool active;
}

class BuyerState {
  const BuyerState({
    this.factory = false,
    this.name = '',
    this.interests = const [true, false, false, false],
    this.orders = const [BuyOrder(id: 2031, lot: 1, qty: 500, delivery: true, stage: 1), BuyOrder(id: 2024, lot: 4, qty: 1000, delivery: false, stage: 3)],
    this.saved = const [],
    this.lastId = 2031,
    this.spent = 5800,
    this.requests = 0,
    this.scrapRequests = 0,
    this.prefs = const [true, true, true, false],
    this.contracts = const [
      Contract('PET نضيف · شهري', 'Clean PET · monthly', '2000 كجم كل شهر · تسليم أول الشهر', '2000 kg monthly · delivered at month start', true),
      Contract('كرتون بالات · أسبوعي', 'Baled cardboard · weekly', '1000 كجم كل أسبوع · قيد المراجعة', '1000 kg weekly · in review', false),
    ],
  });
  final bool factory;
  final String name;
  final List<bool> interests;
  final List<BuyOrder> orders;
  final List<int> saved;
  final int lastId, requests, scrapRequests;
  final double spent;
  final List<bool> prefs;
  final List<Contract> contracts;

  /// Independent recyclers only see small lots; factories see everything.
  List<Lot> market(int cat) {
    final l = lots.where((x) => (factory || x.min <= 100) && (cat < 0 || x.mat == cat)).toList();
    l.sort((a, b) => (interests[b.mat] ? 1 : 0) - (interests[a.mat] ? 1 : 0));
    return l;
  }

  BuyerState copyWith({bool? factory, String? name, List<bool>? interests, List<BuyOrder>? orders, List<int>? saved, int? lastId, double? spent, int? requests, int? scrapRequests, List<bool>? prefs, List<Contract>? contracts}) => BuyerState(
        factory: factory ?? this.factory,
        name: name ?? this.name,
        interests: interests ?? this.interests,
        orders: orders ?? this.orders,
        saved: saved ?? this.saved,
        lastId: lastId ?? this.lastId,
        spent: spent ?? this.spent,
        requests: requests ?? this.requests,
        scrapRequests: scrapRequests ?? this.scrapRequests,
        prefs: prefs ?? this.prefs,
        contracts: contracts ?? this.contracts,
      );
}

final buyerProvider = NotifierProvider<BuyerNotifier, BuyerState>(BuyerNotifier.new);

class BuyerNotifier extends Notifier<BuyerState> {
  @override
  BuyerState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) {
      lots = [];
      _lotKeys.clear();
      Future.microtask(refresh);
      return BuyerState(factory: true, name: user.name, orders: const [], spent: 0, contracts: const []);
    }
    lots = [..._sampleLots];
    return const BuyerState();
  }

  bool get isReal {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  /// Loads the live catalogue and this factory's orders. Contracts and scrap selling have no backend yet.
  Future<void> refresh() async {
    if (!isReal) return;
    try {
      final dio = ref.read(dioProvider);
      final cat = await dio.get('/catalog');
      final built = <Lot>[];
      _lotKeys.clear();
      var n = 0;
      for (final it in (((cat.data as Map<String, dynamic>)['items'] ?? const []) as List).cast<Map<String, dynamic>>()) {
        n++;
        final name = '${it['material']}';
        final grade = it['grade'] as String?;
        _lotKeys[n] = (materialTypeId: it['materialTypeId'] as int, grade: grade);
        built.add(Lot(n, materialSlot(name) ?? 0, name, name, grade ?? '—', grade ?? '—', '—', '—', double.tryParse('${it['availableKg']}') ?? 0, double.tryParse('${it['pricePerKg']}') ?? 0, 1));
      }
      lots = built;
      final ores = await dio.get('/orders', queryParameters: {'limit': 50});
      final orders = <BuyOrder>[];
      var spent = 0.0;
      for (final o in (((ores.data as Map<String, dynamic>)['items'] ?? const []) as List).cast<Map<String, dynamic>>()) {
        final st = '${o['status']}';
        if (st == 'cancelled') continue;
        final items = (o['items'] as List? ?? const []).cast<Map<String, dynamic>>();
        final qty = items.fold(0.0, (a, i) => a + (double.tryParse('${i['quantityKg']}') ?? 0));
        final mid = items.isEmpty ? null : items.first['materialTypeId'];
        final lotId = _lotKeys.entries.where((e) => e.value.materialTypeId == mid).firstOrNull?.key ?? 0;
        final stage = switch (st) { 'confirmed' => 1, 'dispatched' => 2, 'delivered' => 3, _ => 0 };
        final order = BuyOrder(id: o['id'] as int, lot: lotId, qty: qty, delivery: false, stage: stage);
        if (order.done) spent += items.fold(0.0, (a, i) => a + (double.tryParse('${i['quantityKg']}') ?? 0) * (double.tryParse('${i['unitPrice']}') ?? 0));
        orders.add(order);
      }
      state = state.copyWith(orders: orders, spent: spent);
    } catch (_) {}
  }

  /// Real order. Returns the new order id or an error message.
  Future<({int? id, String? error})> placeOrderReal(int lotId, double qty) async {
    final key = _lotKeys[lotId];
    if (key == null) return (id: null, error: 'الدفعة دي مش متاحة.');
    try {
      final res = await ref.read(dioProvider).post('/orders', data: {
        'items': [
          {'materialTypeId': key.materialTypeId, 'grade': ?key.grade, 'quantityKg': double.parse(qty.toStringAsFixed(3))},
        ],
      });
      await refresh();
      return (id: (res.data as Map<String, dynamic>)['id'] as int, error: null);
    } catch (e) {
      return (id: null, error: ApiError.from(e).message);
    }
  }

  void signup(String name, bool factory) => state = state.copyWith(name: name, factory: factory);
  void toggleInterest(int i) => state = state.copyWith(interests: [for (var k = 0; k < 4; k++) k == i ? !state.interests[k] : state.interests[k]]);
  void toggleSave(int id) => state = state.copyWith(saved: state.saved.contains(id) ? [for (final s in state.saved) if (s != id) s] : [...state.saved, id]);

  /// Returns the new order id, or -1 when the quantity is outside the lot limits.
  int placeOrder(int lotId, double qty, bool delivery) {
    final l = lotOf(lotId);
    if (qty < l.min || qty > l.avail) return -1;
    final id = state.lastId + 1;
    state = state.copyWith(lastId: id, orders: [BuyOrder(id: id, lot: lotId, qty: qty, delivery: delivery, stage: 0), ...state.orders]);
    return id;
  }

  /// Demo step. The spend is counted only when the order is delivered.
  void advance(int id) {
    final i = state.orders.indexWhere((o) => o.id == id);
    if (i < 0 || state.orders[i].done) return;
    final o = state.orders[i].withStage(state.orders[i].stage + 1);
    state = state.copyWith(orders: [for (var k = 0; k < state.orders.length; k++) k == i ? o : state.orders[k]], spent: o.done ? state.spent + o.total : state.spent);
  }

  void postRequest() => state = state.copyWith(requests: state.requests + 1);
  void postScrap() => state = state.copyWith(scrapRequests: state.scrapRequests + 1);
  void newContract() => state = state.copyWith(contracts: [...state.contracts, const Contract('عقد جديد', 'New contract', 'قيد المراجعة', 'In review', false)]);
  void togglePref(int i) => state = state.copyWith(prefs: [for (var k = 0; k < 4; k++) k == i ? !state.prefs[k] : state.prefs[k]]);
}
