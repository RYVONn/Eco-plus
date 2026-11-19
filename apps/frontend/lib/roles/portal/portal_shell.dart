import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../admin/admin_data.dart';
import '../common/kit.dart';

String _tx(Tx t, Cell c) => t(c.ar, c.en);
Color _tone(BuildContext context, String? tone) => switch (tone) {
      'ok' => context.eco.primary,
      'warn' => context.eco.amber,
      'bad' => context.eco.danger,
      _ => context.eco.ink,
    };

/// Web portal for a customer role: sidebar, pages built from stats, bars, cards and tables. Wide screens show the sidebar, narrow ones a drawer.
class PortalShell extends ConsumerStatefulWidget {
  const PortalShell({super.key, required this.role, required this.accent, required this.nav, required this.pages});
  final Cell role;
  final Color accent;
  final List<(Cell, List<String>)> nav;
  final List<AdminPage> pages;

  @override
  ConsumerState<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends ConsumerState<PortalShell> {
  late String _page = widget.pages.first.id;
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(String id) => setState(() {
        _page = id;
        _q = '';
        _search.clear();
      });

  Widget _nav(Tx t, {VoidCallback? onPick}) => ListView(padding: const EdgeInsets.all(12), children: [
        const Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 12), child: Row(children: [LogoMark(size: 28), SizedBox(width: 8), Flexible(child: Wordmark(size: 22))])),
        for (final g in widget.nav) ...[
          Padding(padding: const EdgeInsets.fromLTRB(8, 14, 8, 6), child: Text(_tx(t, g.$1), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.eco.inkSoft))),
          for (final id in g.$2)
            ListTile(
              dense: true,
              selected: _page == id,
              selectedTileColor: widget.accent.withValues(alpha: 0.12),
              selectedColor: widget.accent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(_tx(t, widget.pages.firstWhere((p) => p.id == id).title)),
              onTap: () {
                _open(id);
                onPick?.call();
              },
            ),
        ],
      ]);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final page = widget.pages.firstWhere((p) => p.id == _page);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      return Scaffold(
        backgroundColor: context.eco.surfaceAlt,
        drawer: wide ? null : Drawer(child: SafeArea(child: Builder(builder: (c) => _nav(t, onPick: () => Navigator.of(c).pop())))),
        body: Row(children: [
          if (wide) SizedBox(width: 248, child: Material(color: context.eco.surface, child: SafeArea(child: _nav(t)))),
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
                      Expanded(child: TextField(controller: _search, onChanged: (v) => setState(() => _q = v), decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: t('ابحث في الصفحة', 'Search this page'), isDense: true))),
                      const SizedBox(width: 8),
                      TextButton(onPressed: ref.read(arabicProvider.notifier).toggle, child: Text(ref.watch(stringsProvider).language)),
                      if (wide) ...[Text(_tx(t, widget.role), style: TextStyle(color: context.eco.inkSoft)), const SizedBox(width: 8), CircleAvatar(radius: 16, backgroundColor: widget.accent, child: const Icon(Icons.person_rounded, size: 18, color: Colors.white))],
                    ]),
                  ),
                ),
              ),
              Expanded(child: _body(t, page)),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _body(Tx t, AdminPage page) {
    final c = context.eco;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tx(t, page.title), style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 2), Text(_tx(t, page.sub), style: TextStyle(color: c.inkSoft))])),
        for (final a in page.acts) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: widget.accent), onPressed: () => toast(context, t('ده تصميم للتجربة', 'Design demo action')), child: Text(_tx(t, a)))),
      ]),
      const SizedBox(height: 16),
      for (final b in page.blocks) _block(t, b),
    ]);
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(title, style: Theme.of(context).textTheme.titleMedium)), ...children]),
      );

  Widget _block(Tx t, Block b) {
    final c = context.eco;
    return switch (b) {
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
      BarsBlock b => _section(_tx(t, b.title), [
          for (final it in b.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(width: 90, child: Text(_tx(t, it.$1))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: it.$2 / b.items.map((x) => x.$2).reduce((a, z) => a > z ? a : z), minHeight: 10, color: widget.accent, backgroundColor: c.surfaceAlt))),
                const SizedBox(width: 10),
                Text('${fmt(it.$2)} ${t('كجم', 'kg')}'),
              ]),
            ),
        ]),
      CardsBlock b => _section(_tx(t, b.title), [
          for (final it in b.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EcoCard(child: Row(children: [
                Icon(it.$3 == 'warn' ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: _tone(context, it.$3)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_tx(t, it.$1), style: Theme.of(context).textTheme.titleSmall), Text(_tx(t, it.$2), style: TextStyle(color: c.inkSoft))])),
              ])),
            ),
        ]),
      MapBlock b => _section(_tx(t, b.title), [Container(height: 220, alignment: Alignment.center, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.inkSoft.withValues(alpha: 0.2))), child: Icon(Icons.map_rounded, size: 48, color: c.inkSoft))]),
      TableBlock b => _table(t, b),
    };
  }

  Widget _table(Tx t, TableBlock b) {
    final c = context.eco;
    final q = _q.trim().toLowerCase();
    final shown = [for (final r in b.rows) if (q.isEmpty || r.map((x) => _tx(t, x)).join(' ').toLowerCase().contains(q)) r];
    Widget line(List<Cell> cells, {bool head = false, VoidCallback? tap}) {
      final child = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: (b.flex[i] * 10).round(),
              child: cells[i].tone != null && !head
                  ? Align(alignment: AlignmentDirectional.centerStart, child: Tag(_tx(t, cells[i]), color: _tone(context, cells[i].tone)))
                  : Text(_tx(t, cells[i]), style: head ? Theme.of(context).textTheme.labelMedium?.copyWith(color: c.inkSoft) : null),
            ),
        ]),
      );
      return Material(color: Colors.transparent, child: tap == null ? child : InkWell(onTap: tap, child: child));
    }

    return _section(_tx(t, b.title), [
      EcoCard(
        padding: EdgeInsets.zero,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth < 640 ? 640.0 : box.maxWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: w,
              child: Column(children: [
                line(b.cols, head: true),
                const Divider(height: 1),
                if (shown.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(t('مفيش نتائج.', 'No results.'), style: TextStyle(color: c.inkSoft))),
                for (final r in shown) ...[
                  line(r, tap: () => _details(t, b, r)),
                  const Divider(height: 1),
                ],
              ]),
            ),
          );
        }),
      ),
    ]);
  }

  void _details(Tx t, TableBlock b, List<Cell> r) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
            for (var i = 0; i < r.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [Text(_tx(t, b.cols[i]), style: TextStyle(color: context.eco.inkSoft)), const SizedBox(width: 12), Expanded(child: Text(_tx(t, r[i]), textAlign: TextAlign.end, style: TextStyle(color: _tone(context, r[i].tone))))]),
              ),
          ]),
        ),
      );
}
