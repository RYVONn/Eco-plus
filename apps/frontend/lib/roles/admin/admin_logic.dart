import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api.dart';
import '../../core/session.dart';

import 'admin_data.dart';
import 'admin_pages_sys.dart';

/// An admin looking at someone else's account to help them. Every start is written to the audit log.
class SupportSession {
  const SupportSession(this.role, this.name, this.target);
  final String role;
  final Cell name;
  final String target;
}

class AdminState {
  const AdminState({this.page = 'overview', this.query = '', this.sel, this.support, this.audit = const [], this.live = const {}});
  final String page, query;

  /// "block:row" of the selected table row.
  final String? sel;
  final SupportSession? support;

  /// Entries added during this session, newest first: time, action in Arabic and English, target.
  final List<(String, Cell, String)> audit;

  /// Pages filled with real data. Pages not in here show the design samples.
  final Map<String, AdminPage> live;

  AdminState copyWith({Map<String, AdminPage>? live, String? page, String? query, Object? sel = _keep, Object? support = _keep, List<(String, Cell, String)>? audit}) => AdminState(
        page: page ?? this.page,
        query: query ?? this.query,
        sel: identical(sel, _keep) ? this.sel : sel as String?,
        support: identical(support, _keep) ? this.support : support as SupportSession?,
        audit: audit ?? this.audit,
        live: live ?? this.live,
      );
}

const Object _keep = Object();

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);

class AdminNotifier extends Notifier<AdminState> {
  @override
  AdminState build() {
    final user = ref.read(sessionProvider).value;
    if (user != null && !user.isDemo) Future.microtask(refresh);
    return const AdminState();
  }

  bool get isReal {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  AdminPage pageFor(String id) => state.live[id] ?? adminPages.firstWhere((p) => p.id == id);
  AdminPage get current => pageFor(state.page);

  AdminPage _with(String id, List<Block> blocks) {
    final base = adminPages.firstWhere((p) => p.id == id);
    return AdminPage(id, base.title, base.sub, blocks, acts: base.acts);
  }

  static Cell _tone(String status) => switch (status) {
        'weighed' || 'delivered' || 'paid' => ok(status, status),
        'rejected' || 'cancelled' => bd(status, status),
        _ => wn(status, status),
      };

  /// Fills overview, pickups, orders and buyers from the backend. Other pages keep the design samples.
  Future<void> refresh() async {
    if (!isReal) return;
    final dio = ref.read(dioProvider);
    final live = <String, AdminPage>{};
    try {
      final st = (await dio.get('/admin/stats', queryParameters: {'days': 7})).data as Map<String, dynamic>;
      final series = (st['series'] as List).cast<Map<String, dynamic>>();
      live['overview'] = _with('overview', [
        StatsBlock([
          (c('شحنات (7 أيام)', 'Shipments (7 days)'), '${st['totalShipments']}', ''),
          (c('كجم اتوزنت', 'kg weighed'), (st['totalKg'] as num).toStringAsFixed(1), ''),
          (c('نسبة الرفض', 'Rejection rate'), '${((st['rejectionRate'] as num) * 100).round()}%', ''),
        ]),
        BarsBlock(c('الكجم في اليوم', 'kg per day'), [for (final r in series) (s('${r['day']}'.substring(5)), (r['kg'] as num).toDouble())]),
      ]);
    } catch (_) {}
    try {
      final rows = ((await dio.get('/shipments', queryParameters: {'limit': 50})).data as Map<String, dynamic>)['items'] as List;
      live['pickups'] = _with('pickups', [
        TableBlock(c('الاستلامات', 'Pickups'), [c('الرقم', 'ID'), c('النوع', 'Type'), c('الكجم', 'kg'), c('الحالة', 'Status')], [1.5, 2, 1.5, 2], [
          for (final r in rows.cast<Map<String, dynamic>>())
            [
              s('#${r['id']}'),
              r['sourceType'] == 'business' ? c('بيزنس', 'Business') : c('مواطن', 'Citizen'),
              s('${(r['weighing'] as Map<String, dynamic>?)?['actualWeightKg'] ?? '-'}'),
              _tone('${r['status']}'),
            ],
        ]),
      ]);
    } catch (_) {}
    try {
      final rows = ((await dio.get('/orders', queryParameters: {'limit': 50})).data as Map<String, dynamic>)['items'] as List;
      live['orders'] = _with('orders', [
        TableBlock(c('الطلبات', 'Orders'), [c('الرقم', 'ID'), c('المصنع', 'Factory'), c('الكجم', 'kg'), c('الحالة', 'Status')], [1.5, 3, 1.5, 2], [
          for (final r in rows.cast<Map<String, dynamic>>())
            [
              s('#${r['id']}'),
              s('${(r['factory'] as Map<String, dynamic>?)?['name'] ?? '-'}'),
              s(((r['items'] as List? ?? const []).cast<Map<String, dynamic>>().fold(0.0, (a, i) => a + (double.tryParse('${i['quantityKg']}') ?? 0))).toStringAsFixed(1)),
              _tone('${r['status']}'),
            ],
        ]),
      ]);
    } catch (_) {}
    try {
      final rows = ((await dio.get('/admin/audit', queryParameters: {'limit': 50})).data as Map<String, dynamic>)['items'] as List;
      live['audit'] = _with('audit', [
        TableBlock(c('سجل المراجعة', 'Audit log'), [c('الوقت', 'Time'), c('من', 'By'), c('الإجراء', 'Action'), c('الحساب', 'Account')], [2, 2, 3, 2], [
          for (final r in rows.cast<Map<String, dynamic>>())
            [
              s('${r['createdAt']}'.replaceFirst('T', ' ').substring(0, 16)),
              s('${(r['actor'] as Map<String, dynamic>?)?['name'] ?? '-'}'),
              s('${r['action']}'),
              s('${(r['target'] as Map<String, dynamic>?)?['name'] ?? '-'}'),
            ],
        ]),
      ]);
    } catch (_) {}
    try {
      final imp = (await dio.get('/admin/impact')).data as Map<String, dynamic>;
      final al = ((await dio.get('/admin/alerts')).data as Map<String, dynamic>)['items'] as List;
      final base = live['overview'] ?? _with('overview', const []);
      live['overview'] = _with('overview', [
        ...base.blocks,
        StatsBlock([
          (c('كجم اتدوّر', 'kg recycled'), (imp['totalKg'] as num).toStringAsFixed(1), ''),
          (c('CO2 موفّر (تقدير)', 'CO2 saved (estimate)'), (imp['co2SavedKg'] as num).toStringAsFixed(1), ''),
          (c('تنبيهات', 'Alerts'), '${al.length}', ''),
        ]),
        if (al.isNotEmpty)
          TableBlock(c('تنبيهات', 'Alerts'), [c('النوع', 'Type'), c('العدد', 'Count')], [4, 1], [
            for (final a in al.cast<Map<String, dynamic>>()) [Cell('${a['type']}', '${a['type']}', tone: a['severity'] == 'bad' ? 'bad' : 'warn'), s('${a['count']}')],
          ]),
      ]);
    } catch (_) {}
    try {
      final rows = ((await dio.get('/factories', queryParameters: {'limit': 50})).data as Map<String, dynamic>)['items'] as List;
      live['buyers'] = _with('buyers', [
        TableBlock(c('المصانع', 'Factories'), [c('الرقم', 'ID'), c('الاسم', 'Name')], [1.5, 4], [
          for (final r in rows.cast<Map<String, dynamic>>()) [s('#${r['id']}'), s('${r['name']}')],
        ]),
      ]);
    } catch (_) {}
    if (live.isNotEmpty) state = state.copyWith(live: {...state.live, ...live});
  }

  void openPage(String id) => state = state.copyWith(page: id, query: '', sel: null);
  void setQuery(String q) => state = state.copyWith(query: q, sel: null);
  void select(String? key) => state = state.copyWith(sel: key == state.sel ? null : key);

  void startSupport(String role, Cell name) {
    state = state.copyWith(
      support: SupportSession(role, name, name.en),
      sel: null,
      audit: [('now', const Cell('دخل على حساب (وضع الدعم)', 'Opened an account (support mode)'), name.en), ...state.audit],
    );
  }

  void exitSupport() => state = state.copyWith(support: null);
}
