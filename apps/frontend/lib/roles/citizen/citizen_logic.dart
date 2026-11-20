import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

/// Preview value: the real code is created by the server and shown only to the customer.
const sampleHandoverCode = '4821';

const levels = [
  ('B', 'برونز', 'Bronze', 0),
  ('S', 'سيلفر', 'Silver', 300),
  ('G', 'جولد', 'Gold', 600),
  ('P', 'بلاتينيوم', 'Platinum', 1200),
];

/// Index of the level a balance belongs to.
int levelIndex(int points) {
  var idx = 0;
  for (var i = 0; i < levels.length; i++) {
    if (points >= levels[i].$4) idx = i;
  }
  return idx;
}

class CShip {
  const CShip({required this.id, required this.bags, required this.whenAr, required this.whenEn, required this.step, this.code});
  final String id;

  /// The handover code created by the server. Null in preview mode.
  final String? code;
  final int bags;
  final String whenAr, whenEn;

  /// 0 booked, 1 driver assigned, 2 collected, 3 weighed.
  final int step;
  bool get done => step >= 3;
  CShip withStep(int s) => CShip(id: id, bags: bags, whenAr: whenAr, whenEn: whenEn, step: s, code: code);
}

class LedgerRow {
  const LedgerRow(this.titleAr, this.titleEn, this.refAr, this.refEn, this.points);
  final String titleAr, titleEn, refAr, refEn;
  final int points;
}

class CitizenState {
  const CitizenState({
    required this.points,
    required this.ships,
    required this.ledger,
    this.addressDefault = 0,
    this.extraAddress = false,
    this.prefs = const [true, true, false],
    this.perms = const [true, true, false],
  });
  final int points;
  final List<CShip> ships;
  final List<LedgerRow> ledger;
  final int addressDefault;
  final bool extraAddress;
  final List<bool> prefs;
  final List<bool> perms;

  CShip? get active {
    for (final s in ships) {
      if (!s.done) return s;
    }
    return null;
  }

  CitizenState copyWith({int? points, List<CShip>? ships, List<LedgerRow>? ledger, int? addressDefault, bool? extraAddress, List<bool>? prefs, List<bool>? perms}) => CitizenState(
        points: points ?? this.points,
        ships: ships ?? this.ships,
        ledger: ledger ?? this.ledger,
        addressDefault: addressDefault ?? this.addressDefault,
        extraAddress: extraAddress ?? this.extraAddress,
        prefs: prefs ?? this.prefs,
        perms: perms ?? this.perms,
      );
}

final citizenProvider = NotifierProvider<CitizenNotifier, CitizenState>(CitizenNotifier.new);

class CitizenNotifier extends Notifier<CitizenState> {
  @override
  CitizenState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) {
      Future.microtask(refresh);
      return const CitizenState(points: 0, ships: [], ledger: []);
    }
    return _sample;
  }

  /// Loads the real balance, pickups and points history. Does nothing in preview mode.
  Future<void> refresh() async {
    final user = ref.read(sessionProvider).value;
    if (user == null || user.isDemo) return;
    try {
      final dio = ref.read(dioProvider);
      final pts = (await dio.get('/me/points', queryParameters: {'limit': 20})).data as Map<String, dynamic>;
      final sh = (await dio.get('/shipments', queryParameters: {'limit': 30})).data as Map<String, dynamic>;
      state = state.copyWith(points: (pts['balance'] as num).toInt(), ships: _ships(sh), ledger: _ledger(pts));
    } catch (_) {
      // Keep what is on screen; the next refresh will try again.
    }
  }

  static const _steps = {'created': 0, 'assigned': 1, 'collected': 2, 'weighed': 3};

  List<CShip> _ships(Map<String, dynamic> page) => [
        for (final j in (page['items'] as List).cast<Map<String, dynamic>>())
          if (_steps.containsKey(j['status']))
            CShip(
              id: 'EP-${j['id']}',
              bags: 1,
              whenAr: _day(j['createdAt'] as String),
              whenEn: _day(j['createdAt'] as String),
              step: _steps[j['status']]!,
              code: j['handoverCode'] as String?,
            ),
      ];

  List<LedgerRow> _ledger(Map<String, dynamic> pts) {
    final items = ((pts['history'] as Map<String, dynamic>)['items'] as List).cast<Map<String, dynamic>>();
    return [
      for (final j in items)
        LedgerRow(
          'وزن مؤكد · ${(j['weighing'] as Map?)?['materialType']?['name'] ?? ''}',
          'Weighed · ${(j['weighing'] as Map?)?['materialType']?['name'] ?? ''}',
          'EP-${(j['weighing'] as Map?)?['shipmentId'] ?? ''} · ${_day(j['createdAt'] as String)}',
          'EP-${(j['weighing'] as Map?)?['shipmentId'] ?? ''} · ${_day(j['createdAt'] as String)}',
          (j['points'] as num).toInt(),
        ),
    ];
  }

  String _day(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    return d == null ? '' : '${d.day}/${d.month}';
  }

  static const _sample = CitizenState(
        points: 420,
        ships: [
          CShip(id: 'EP-1042', bags: 3, whenAr: 'النهارده', whenEn: 'Today', step: 1),
          CShip(id: 'EP-1038', bags: 2, whenAr: '12 نوفمبر', whenEn: 'Nov 12', step: 3),
          CShip(id: 'EP-1031', bags: 1, whenAr: '5 نوفمبر', whenEn: 'Nov 5', step: 3),
        ],
        ledger: [
          LedgerRow('وزن مؤكد · بلاستيك', 'Weighed · plastic', 'EP-1038 · 12 نوفمبر', 'EP-1038 · Nov 12', 42),
          LedgerRow('وزن مؤكد · ورق', 'Weighed · paper', 'EP-1031 · 5 نوفمبر', 'EP-1031 · Nov 5', 18),
          LedgerRow('مكافأة ترحيب', 'Welcome bonus', '1 نوفمبر', 'Nov 1', 50),
          LedgerRow('وزن مؤكد · كرتون', 'Weighed · cardboard', 'EP-1024 · 28 أكتوبر', 'EP-1024 · Oct 28', 30),
          LedgerRow('وزن مؤكد · بلاستيك', 'Weighed · plastic', 'EP-1019 · 20 أكتوبر', 'EP-1019 · Oct 20', 36),
        ],
      );

  /// Books a new pickup for 3 bags and returns its number.
  String book(String whenAr, String whenEn) {
    final id = 'EP-${1043 + state.ships.where((s) => s.id.compareTo('EP-1043') >= 0).length}';
    state = state.copyWith(ships: [CShip(id: id, bags: 3, whenAr: whenAr, whenEn: whenEn, step: 0), ...state.ships]);
    return id;
  }

  /// Demo only: moves a shipment one step. Points arrive only at the last step, after the warehouse weighs.
  void advance(String id) {
    final i = state.ships.indexWhere((s) => s.id == id);
    if (i < 0 || state.ships[i].done) return;
    final next = state.ships[i].step + 1;
    final ships = [for (var k = 0; k < state.ships.length; k++) k == i ? state.ships[k].withStep(next) : state.ships[k]];
    if (next == 3) {
      state = state.copyWith(
        ships: ships,
        points: state.points + 42,
        ledger: [LedgerRow('وزن مؤكد · بلاستيك', 'Weighed · plastic', '$id · اليوم', '$id · Today', 42), ...state.ledger],
      );
    } else {
      state = state.copyWith(ships: ships);
    }
  }

  void setDefaultAddress(int i) => state = state.copyWith(addressDefault: i);
  void addAddress() => state = state.copyWith(extraAddress: true);
  void togglePref(int i) => state = state.copyWith(prefs: [for (var k = 0; k < 3; k++) k == i ? !state.prefs[k] : state.prefs[k]]);
  void togglePerm(int i) => state = state.copyWith(perms: [for (var k = 0; k < 3; k++) k == i ? !state.perms[k] : state.perms[k]]);
}
