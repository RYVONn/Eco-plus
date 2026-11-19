import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

/// Materials and prices are design placeholders until real quotes exist.
class BMat {
  const BMat(this.ar, this.en, this.color, this.code, this.price, this.factor, this.trendAr, this.trendEn);
  final String ar, en, code, trendAr, trendEn;
  final Color color;
  final double price;
  final double factor;
}

const bMats = [
  BMat('بلاستيك', 'Plastic', Color(0xFFCFE6FF), 'PL', 8, 1.0, 'السعر طالع', 'Price rising'),
  BMat('ورق', 'Paper', Color(0xFFFFF1C2), 'PA', 4, 0.6, 'السعر ثابت', 'Price steady'),
  BMat('كرتون', 'Cardboard', Color(0xFFEAD7BE), 'CB', 3, 0.5, 'السعر ثابت', 'Price steady'),
  BMat('معادن', 'Metal', Color(0xFFDDE3E8), 'MT', 20, 0.0, 'السعر نازل', 'Price falling'),
];

double r1(double v) => (v * 10).round() / 10;
double estimate(List<double> items) {
  var s = 0.0;
  for (var i = 0; i < bMats.length; i++) {
    s += items[i] * bMats[i].price;
  }
  return r1(s);
}

double pointsOf(List<double> items) {
  var s = 0.0;
  for (var i = 0; i < bMats.length; i++) {
    s += items[i] * bMats[i].factor;
  }
  return r1(s);
}

enum Reward { cash, points }

class BPickup {
  const BPickup({required this.id, required this.whenAr, required this.whenEn, required this.branch, required this.stage, required this.items, this.weighed, this.reward = Reward.cash});
  final int id;
  final String whenAr, whenEn;
  final int branch;

  /// 0 scheduled, 1 driver assigned, 2 collected, 3 weighed.
  final int stage;
  final List<double> items;
  final List<double>? weighed;
  final Reward reward;
  bool get done => stage >= 3;
  double get kg => (weighed ?? items).fold(0.0, (a, b) => a + b);
  BPickup copyWith({int? stage, List<double>? weighed}) => BPickup(id: id, whenAr: whenAr, whenEn: whenEn, branch: branch, stage: stage ?? this.stage, items: items, weighed: weighed ?? this.weighed, reward: reward);
}

class BBranch {
  const BBranch(this.ar, this.en, this.addrAr, this.addrEn, {this.on = true, this.schedAr, this.schedEn});
  final String ar, en, addrAr, addrEn;
  final bool on;
  final String? schedAr, schedEn;
  BBranch copyWith({bool? on}) => BBranch(ar, en, addrAr, addrEn, on: on ?? this.on, schedAr: schedAr, schedEn: schedEn);
}

class BTx {
  const BTx(this.ar, this.en, this.whenAr, this.whenEn, this.value);
  final String ar, en, whenAr, whenEn;
  final double value;
}

class BMember {
  const BMember(this.ar, this.en, this.manager, this.invited, {this.owner = false});
  final String ar, en;
  final bool manager, invited, owner;
}

class BizState {
  const BizState({
    this.name = '',
    this.type = 0,
    this.balance = 1240,
    this.points = 420,
    this.lastId = 1052,
    required this.pickups,
    required this.txs,
    required this.branches,
    required this.team,
    this.prefs = const [true, true, false, true],
  });
  final String name;
  final int type;
  final double balance;
  final double points;
  final int lastId;
  final List<BPickup> pickups;
  final List<BTx> txs;
  final List<BBranch> branches;
  final List<BMember> team;
  final List<bool> prefs;

  BPickup? get next {
    for (final p in pickups) {
      if (!p.done) return p;
    }
    return null;
  }

  double get pending => r1(pickups.where((p) => !p.done).fold(0.0, (a, p) => a + estimate(p.items) * 0.9));
  double get weighedKg => pickups.where((p) => p.done).fold(0.0, (a, p) => a + p.kg);

  BizState copyWith({String? name, int? type, double? balance, double? points, int? lastId, List<BPickup>? pickups, List<BTx>? txs, List<BBranch>? branches, List<BMember>? team, List<bool>? prefs}) => BizState(
        name: name ?? this.name,
        type: type ?? this.type,
        balance: balance ?? this.balance,
        points: points ?? this.points,
        lastId: lastId ?? this.lastId,
        pickups: pickups ?? this.pickups,
        txs: txs ?? this.txs,
        branches: branches ?? this.branches,
        team: team ?? this.team,
        prefs: prefs ?? this.prefs,
      );
}

final businessProvider = NotifierProvider<BusinessNotifier, BizState>(BusinessNotifier.new);

int? materialSlot(String name) {
  final n = name.toLowerCase();
  if (n.contains('plastic')) return 0;
  if (n.contains('paper')) return 1;
  if (n.contains('cardboard')) return 2;
  if (n.contains('alumin') || n.contains('metal')) return 3;
  return null;
}

class BusinessNotifier extends Notifier<BizState> {
  @override
  BizState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) {
      Future.microtask(refresh);
      return BizState(
        name: user.name,
        balance: 0,
        points: 0,
        pickups: const [],
        txs: const [],
        branches: const [BBranch('الفرع الرئيسي', 'Main branch', '—', '—')],
        team: const [BMember('أنت', 'You', true, false, owner: true)],
      );
    }
    return _sample;
  }

  bool get isReal {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  /// Loads the business's real shipments as pickups. Wallet, branches and team have no backend yet.
  Future<void> refresh() async {
    if (!isReal) return;
    try {
      final res = await ref.read(dioProvider).get('/shipments', queryParameters: {'limit': 50});
      final raw = (((res.data as Map<String, dynamic>)['items'] ?? const []) as List).cast<Map<String, dynamic>>();
      final list = <BPickup>[];
      for (final r in raw) {
        final st = '${r['status']}';
        if (st == 'cancelled' || st == 'rejected') continue;
        final stage = switch (st) { 'assigned' => 1, 'collected' => 2, 'weighed' => 3, _ => 0 };
        final created = DateTime.tryParse('${r['createdAt']}')?.toLocal();
        final label = created == null ? '' : '${created.day}/${created.month}';
        List<double>? weighed;
        final w = r['weighing'] as Map<String, dynamic>?;
        if (w != null && w['accepted'] == true) {
          weighed = [0, 0, 0, 0];
          final slot = materialSlot('${(w['materialType'] as Map<String, dynamic>?)?['name'] ?? ''}') ?? 0;
          weighed[slot] = double.tryParse('${w['actualWeightKg']}') ?? 0;
        }
        list.add(BPickup(id: r['id'] as int, whenAr: label, whenEn: label, branch: 0, stage: stage, items: weighed ?? const [0, 0, 0, 0], weighed: weighed));
      }
      state = state.copyWith(pickups: list);
    } catch (_) {}
  }

  static const _sample = BizState(
        pickups: [
          BPickup(id: 1052, whenAr: 'النهارده 4 – 8 م', whenEn: 'Today 4 – 8 PM', branch: 0, stage: 1, items: [6, 0, 4, 0]),
          BPickup(id: 1049, whenAr: 'بكرة 9 ص – 12 م', whenEn: 'Tomorrow 9 AM – 12 PM', branch: 1, stage: 0, items: [0, 5, 0, 2]),
          BPickup(id: 1041, whenAr: 'الأحد الماضي', whenEn: 'Last Sunday', branch: 0, stage: 3, items: [6.4, 0, 3.6, 0], weighed: [5.8, 0, 3.2, 0]),
        ],
        txs: [
          BTx('استلام #1041', 'Pickup #1041', 'امبارح', 'Yesterday', 56),
          BTx('استلام #1036', 'Pickup #1036', 'من 5 أيام', '5 days ago', 184),
          BTx('سحب رصيد', 'Withdrawal', 'من أسبوع', '1 week ago', -500),
          BTx('استلام #1030', 'Pickup #1030', 'من أسبوعين', '2 weeks ago', 92),
        ],
        branches: [
          BBranch('فرع وسط البلد', 'Downtown branch', 'شارع المثال 1', 'Example St 1', schedAr: 'كل سبت وثلاثاء · 4 – 8 م', schedEn: 'Every Sat and Tue · 4 – 8 PM'),
          BBranch('فرع المعادي', 'Maadi branch', 'شارع المثال 7', 'Example St 7'),
        ],
        team: [BMember('أنت', 'You', true, false, owner: true), BMember('منى', 'Mona', true, false)],
      );

  void signup(String name, int type) => state = state.copyWith(name: name, type: type);

  int createPickup({required List<double> items, required int branch, required String whenAr, required String whenEn, required Reward reward}) {
    final id = state.lastId + 1;
    state = state.copyWith(lastId: id, pickups: [BPickup(id: id, whenAr: whenAr, whenEn: whenEn, branch: branch, stage: 0, items: items, reward: reward), ...state.pickups]);
    return id;
  }

  /// Demo step. Money or points arrive only at the weighing step, from the weighed amount.
  void advance(int id) {
    final i = state.pickups.indexWhere((p) => p.id == id);
    if (i < 0 || state.pickups[i].done) return;
    final p = state.pickups[i];
    final stage = p.stage + 1;
    List<double>? weighed;
    var balance = state.balance;
    var points = state.points;
    var txs = state.txs;
    if (stage == 3) {
      weighed = [for (final q in p.items) r1(q * 0.9)];
      if (p.reward == Reward.points) {
        points += pointsOf(weighed);
      } else {
        final v = estimate(weighed);
        balance += v;
        txs = [BTx('استلام #$id', 'Pickup #$id', 'دلوقتي', 'Now', v), ...txs];
      }
    }
    state = state.copyWith(
      pickups: [for (var k = 0; k < state.pickups.length; k++) k == i ? p.copyWith(stage: stage, weighed: weighed) : state.pickups[k]],
      balance: balance,
      points: points,
      txs: txs,
    );
  }

  bool withdraw(double amount) {
    if (amount <= 0 || amount > state.balance) return false;
    state = state.copyWith(balance: state.balance - amount, txs: [BTx('سحب رصيد', 'Withdrawal', 'دلوقتي', 'Now', -amount), ...state.txs]);
    return true;
  }

  void addBranch(String name, String addr) => state = state.copyWith(branches: [...state.branches, BBranch(name, name, addr, addr)]);
  void toggleBranch(int i) => state = state.copyWith(branches: [for (var k = 0; k < state.branches.length; k++) k == i ? state.branches[k].copyWith(on: !state.branches[k].on) : state.branches[k]]);
  void invite(String email, bool manager) => state = state.copyWith(team: [...state.team, BMember(email, email, manager, true)]);
  void togglePref(int i) => state = state.copyWith(prefs: [for (var k = 0; k < 4; k++) k == i ? !state.prefs[k] : state.prefs[k]]);
}
