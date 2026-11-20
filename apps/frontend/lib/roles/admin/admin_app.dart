import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../business/business_app.dart';
import '../buyer/buyer_app.dart';
import '../citizen/citizen_app.dart';
import '../common/kit.dart';
import '../driver/driver_app.dart';
import '../employee/employee_app.dart';
import 'admin_data.dart';
import 'admin_logic.dart';
import 'admin_pages_sys.dart';

String _tx(Tx t, Cell c) => t(c.ar, c.en);
Color _tone(BuildContext context, String? tone) => switch (tone) {
      'ok' => context.eco.primary,
      'warn' => context.eco.amber,
      'bad' => context.eco.danger,
      _ => context.eco.ink,
    };

/// Admin web dashboard: sidebar, tables, details panel, and support mode that opens a user's account.
class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(adminProvider.select((s) => s.support));
    return support == null ? const _Shell() : _SupportShell(support);
  }
}

class _SupportShell extends ConsumerWidget {
  const _SupportShell(this.s);
  final SupportSession s;

  Widget _app() => switch (s.role) {
        'citizen' => const CitizenApp(),
        'business' => const BusinessApp(),
        'driver' => const DriverApp(),
        'employee' => const EmployeeApp(),
        _ => const BuyerApp(),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      body: Column(children: [
        Material(
          color: EcoColors.admin,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.support_agent_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('${t('وضع الدعم', 'Support mode')}: ${_tx(t, s.name)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                TextButton(onPressed: ref.read(adminProvider.notifier).exitSupport, style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white24, minimumSize: const Size(0, 40)), child: Text(t('خروج', 'Exit'))),
              ]),
            ),
          ),
        ),
        Expanded(child: PhoneColumn(child: _app())),
      ]),
    );
  }
}

class _Shell extends ConsumerStatefulWidget {
  const _Shell();

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final s = ref.watch(adminProvider);
    ref.listen(adminProvider.select((x) => x.page), (_, _) => _search.clear());
    final page = s.live[s.page] ?? adminPages.firstWhere((p) => p.id == s.page);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final nav = _Nav(onPick: wide ? null : () => Navigator.of(context).pop());
      return Scaffold(
        backgroundColor: context.eco.surfaceAlt,
        drawer: wide ? null : Drawer(child: SafeArea(child: nav)),
        body: Row(children: [
          if (wide) SizedBox(width: 248, child: Material(color: context.eco.surface, child: SafeArea(child: nav))),
          Expanded(
            child: Column(children: [
              Material(
                color: context.eco.surface,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      if (!wide) Builder(builder: (c) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(c).openDrawer())),
                      Expanded(child: TextField(controller: _search, onChanged: ref.read(adminProvider.notifier).setQuery, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t('ابحث في الصفحة', 'Search this page'), isDense: true))),
                      const SizedBox(width: 8),
                      TextButton(onPressed: ref.read(arabicProvider.notifier).toggle, child: Text(ref.watch(stringsProvider).language)),
                      if (wide) ...[Text(t('الأدمن', 'Admin'), style: TextStyle(color: context.eco.inkSoft)), const SizedBox(width: 8), const CircleAvatar(radius: 16, backgroundColor: EcoColors.admin, child: Text('E', style: TextStyle(color: Colors.white)))],
                    ]),
                  ),
                ),
              ),
              Expanded(child: _PageBody(page: page, wide: wide)),
            ]),
          ),
        ]),
      );
    });
  }
}

class _Nav extends ConsumerWidget {
  const _Nav({this.onPick});
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final cur = ref.watch(adminProvider.select((s) => s.page));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 12), child: Row(children: [const LogoMark(size: 28), const SizedBox(width: 8), const Flexible(child: Wordmark(size: 22))])),
      for (final g in adminNav) ...[
        Padding(padding: const EdgeInsets.fromLTRB(8, 14, 8, 6), child: Text(_tx(t, g.$1), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.eco.inkSoft))),
        for (final id in g.$2)
          ListTile(
            dense: true,
            selected: cur == id,
            selectedTileColor: EcoColors.admin.withValues(alpha: 0.12),
            selectedColor: EcoColors.admin,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Text(_tx(t, adminPages.firstWhere((p) => p.id == id).title)),
            onTap: () {
              ref.read(adminProvider.notifier).openPage(id);
              onPick?.call();
            },
          ),
      ],
    ]);
  }
}

class _PageBody extends ConsumerWidget {
  const _PageBody({required this.page, required this.wide});
  final AdminPage page;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(adminProvider);
    final content = ListView(padding: const EdgeInsets.all(20), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tx(t, page.title), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 2), Text(_tx(t, page.sub), style: TextStyle(color: context.eco.inkSoft))])),
        for (final a in page.acts) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => toast(context, t('ده تصميم للتجربة', 'Design demo action')), child: Text(_tx(t, a)))),
      ]),
      const SizedBox(height: 16),
      for (var i = 0; i < page.blocks.length; i++) _BlockView(page: page, block: page.blocks[i], index: i),
    ]);
    final sel = _selected(s);
    final panel = sel == null ? null : _Panel(sel: sel);
    if (panel == null) return content;
    if (wide) return Row(children: [Expanded(child: content), SizedBox(width: 340, child: panel)]);
    return Stack(children: [content, Align(alignment: Alignment.bottomCenter, child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 440), child: panel))]);
  }

  _Selected? _selected(AdminState s) {
    final key = s.sel;
    if (key == null) return null;
    final parts = key.split(':');
    final b = int.parse(parts[0]);
    final r = int.parse(parts[1]);
    final block = page.blocks[b];
    if (block is! TableBlock) return null;
    return _Selected(block, r);
  }
}

class _Selected {
  const _Selected(this.block, this.row);
  final TableBlock block;
  final int row;
  List<Cell> get cells => block.rows[row];
  String? get role => block.keys?[row];
  (String, String)? get acts => block.acts?[row];
}

class _BlockView extends ConsumerWidget {
  const _BlockView({required this.page, required this.block, required this.index});
  final AdminPage page;
  final Block block;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    return switch (block) {
      StatsBlock b => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final it in b.items)
              SizedBox(
                width: 210,
                child: EcoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tx(t, it.$1), style: TextStyle(color: c.inkSoft)), const SizedBox(height: 4), Text(it.$2, style: Theme.of(context).textTheme.headlineSmall), if (it.$3.isNotEmpty) Text(it.$3, style: TextStyle(color: c.primary))])),
              ),
          ]),
        ),
      BarsBlock b => _section(context, _tx(t, b.title), [
          for (final it in b.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 90, child: Text(_tx(t, it.$1))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: it.$2 / b.items.map((x) => x.$2).reduce((a, z) => a > z ? a : z), minHeight: 12, color: c.primary, backgroundColor: c.surfaceAlt))),
                const SizedBox(width: 10),
                Text('${fmt(it.$2)} ${t('كجم', 'kg')}'),
              ]),
            ),
        ]),
      CardsBlock b => _section(context, _tx(t, b.title), [
          for (final it in b.items) Padding(padding: const EdgeInsets.only(bottom: 8), child: EcoCard(child: Row(children: [Icon(it.$3 == 'warn' ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: _tone(context, it.$3)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tx(t, it.$1), style: Theme.of(context).textTheme.titleSmall), Text(_tx(t, it.$2), style: TextStyle(color: c.inkSoft))]))]))),
        ]),
      MapBlock b => _section(context, _tx(t, b.title), [Container(height: 220, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.primary.withValues(alpha: 0.2))), child: Center(child: Icon(Icons.map_rounded, size: 56, color: c.primary.withValues(alpha: 0.4))))]),
      TableBlock b => _TableView(page: page, block: b, index: index),
    };
  }
}

Widget _section(BuildContext context, String title, List<Widget> children) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)), ...children]),
    );

class _TableView extends ConsumerWidget {
  const _TableView({required this.page, required this.block, required this.index});
  final AdminPage page;
  final TableBlock block;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(adminProvider);
    final c = context.eco;
    final q = s.query.trim().toLowerCase();
    final extra = page.id == 'audit' ? [for (final a in s.audit) [Cell(a.$1, a.$1), const Cell('أدمن', 'Admin'), a.$2, Cell(a.$3, a.$3)]] : <List<Cell>>[];
    final all = [...extra, ...block.rows];
    final shown = <int>[for (var i = 0; i < all.length; i++) if (q.isEmpty || all[i].map((x) => _tx(t, x)).join(' ').toLowerCase().contains(q)) i];
    final off = extra.length;
    Widget line(List<Cell> cells, {bool head = false, bool on = false, VoidCallback? tap}) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: (block.flex[i] * 10).round(),
              child: cells[i].tone != null && !head
                  ? Align(alignment: AlignmentDirectional.centerStart, child: Tag(_tx(t, cells[i]), color: _tone(context, cells[i].tone)))
                  : Text(_tx(t, cells[i]), style: head ? Theme.of(context).textTheme.labelMedium?.copyWith(color: c.inkSoft) : null),
            ),
        ]),
      );
      return Material(color: on ? EcoColors.admin.withValues(alpha: 0.08) : Colors.transparent, child: tap == null ? child : InkWell(onTap: tap, child: child));
    }

    return _section(context, _tx(t, block.title), [
      EcoCard(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth < 640 ? 640.0 : box.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: w,
              child: Column(children: [
                line(block.cols, head: true),
                const Divider(height: 1),
                if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t('مفيش نتائج.', 'No results.'), style: TextStyle(color: c.inkSoft))),
                for (final i in shown) ...[
                  line(all[i], on: s.sel == '$index:${i - off}' && i >= off, tap: i < off ? null : () => ref.read(adminProvider.notifier).select('$index:${i - off}')),
                  const Divider(height: 1),
                ],
              ]),
            ),
          );
        }),
      ),
    ]);
  }
}

class _Panel extends ConsumerWidget {
  const _Panel({required this.sel});
  final _Selected sel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final acts = sel.acts == null ? <String>[] : t(sel.acts!.$1, sel.acts!.$2).split('|');
    final role = sel.role;
    return Material(
      color: c.surface,
      elevation: 6,
      child: SafeArea(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Row(children: [Expanded(child: Text(_tx(t, sel.cells.first), style: Theme.of(context).textTheme.titleLarge)), TextButton(onPressed: () => ref.read(adminProvider.notifier).select(null), child: Text(t('إغلاق', 'Close')))]),
          const SizedBox(height: 8),
          for (var i = 0; i < sel.block.cols.length; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text(_tx(t, sel.block.cols[i]), style: TextStyle(color: c.inkSoft))), const SizedBox(width: 8), Flexible(child: Text(_tx(t, sel.cells[i]), textAlign: TextAlign.end, style: Theme.of(context).textTheme.titleSmall))])),
          if (role != null) ...[
            const SizedBox(height: 12),
            Text(t('آخر نشاط', 'Recent activity'), style: Theme.of(context).textTheme.titleSmall),
            for (final a in acts) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(a, style: TextStyle(color: c.inkSoft))),
            const SizedBox(height: 16),
            BigButton(t('ادخل على حسابه (وضع الدعم)', 'Open their account (support mode)'), color: EcoColors.admin, icon: Icons.support_agent_rounded, onTap: () {
              switch (role) {
                case 'citizen':
                  ref.read(citizenOnboardedProvider.notifier).done();
                case 'business':
                  ref.read(bizOnboardedProvider.notifier).done();
                case 'buyer' || 'factory':
                  ref.read(buyerOnboardedProvider.notifier).done();
              }
              ref.read(adminProvider.notifier).startSupport(role, sel.cells.first);
            }),
          ],
          const SizedBox(height: 8),
          BigButton(t('افتح التفاصيل', 'Open full details'), outlined: true, onTap: () => toast(context, t('ده تصميم للتجربة', 'Design demo action'))),
        ]),
      ),
    );
  }
}
