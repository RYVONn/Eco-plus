import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';
import '../../core/api.dart';
import '../common/kit.dart';
import 'site_data.dart';

const _ink = Color(0xFF0D2B22);
const _ink2 = Color(0xFF3E5A50);
const _paper = Color(0xFFF3F6F1);
const _green = Color(0xFF0B7F5E);
const _lime = Color(0xFFC9F25A);
const _mint = Color(0xFFDDF1E7);
const _line = Color(0xFFD9E4DD);

/// Public sales website: seven pages, Arabic and English, with a contact form that only shows a demo message.
class SiteApp extends ConsumerStatefulWidget {
  const SiteApp({super.key, this.page = 'home'});
  final String page;

  @override
  ConsumerState<SiteApp> createState() => _SiteAppState();
}

class _SiteAppState extends ConsumerState<SiteApp> {
  late String _page = widget.page;
  int _open = -1;
  int _kind = 0;
  final _fields = List.generate(4, (_) => TextEditingController());
  bool _sending = false;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    for (final f in _fields) {
      f.dispose();
    }
    super.dispose();
  }

  void _go(String p) {
    setState(() {
      _page = p;
      _open = -1;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  String _l(Tx t, P p) => t(p.$1, p.$2);

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final blocks = sitePages[_page] ?? sitePages['home']!;
    return Theme(
      data: Theme.of(context).copyWith(textTheme: Theme.of(context).textTheme.apply(bodyColor: _ink, displayColor: _ink)),
      child: Scaffold(
        backgroundColor: _paper,
        body: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 860;
          final pad = wide ? 48.0 : 20.0;
          return Column(children: [
            _nav(t, wide, pad),
            Expanded(
              child: ListView(controller: _scroll, children: [
                for (final b in blocks) _block(t, b, wide, pad, box.maxWidth),
                if (_page == 'contact') _contact(t, pad),
                _footer(t, pad),
              ]),
            ),
          ]);
        }),
      ),
    );
  }

  Widget _nav(Tx t, bool wide, double pad) => Material(
        color: _paper,
        child: SafeArea(
          bottom: false,
          child: Container(
            height: 68,
            padding: EdgeInsets.symmetric(horizontal: pad),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _line, width: 1.5))),
            child: Row(children: [
              InkWell(onTap: () => _go('home'), child: const Row(children: [LogoMark(size: 30), SizedBox(width: 8), Text('ecoplus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22))])),
              const SizedBox(width: 16),
              if (wide)
                for (final n in siteNav)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: _page == n.$1 ? _ink : _ink2, backgroundColor: _page == n.$1 ? _mint : null, minimumSize: const Size(0, 40)),
                      onPressed: () => _go(n.$1),
                      child: Text(t(n.$2.$1, n.$2.$2), style: TextStyle(fontWeight: _page == n.$1 ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ),
              const Spacer(),
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38), foregroundColor: _ink, side: const BorderSide(color: _ink, width: 1.5), shape: const StadiumBorder()), onPressed: ref.read(arabicProvider.notifier).toggle, child: Text(t('EN', 'ع'))),
              const SizedBox(width: 8),
              if (wide) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 42), backgroundColor: _ink, foregroundColor: _lime, shape: const StadiumBorder()), onPressed: () => _go('contact'), child: Text(t('ابدأ', 'Get started'))),
              if (!wide)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu_rounded),
                  onSelected: _go,
                  itemBuilder: (_) => [for (final n in siteNav) PopupMenuItem(value: n.$1, child: Text(t(n.$2.$1, n.$2.$2))), PopupMenuItem(value: 'contact', child: Text(t('ابدأ', 'Get started')))],
                ),
            ]),
          ),
        ),
      );

  Widget _block(Tx t, Blk b, bool wide, double pad, double width) => switch (b) {
        SiteHero h => _hero(t, h, wide, pad),
        H2 h => Padding(padding: EdgeInsets.fromLTRB(pad, 56, pad, 8), child: Text(_l(t, h.t), style: TextStyle(fontSize: wide ? 44 : 30, fontWeight: FontWeight.w700, height: 1.15))),
        Cards c => _cards(t, c, pad, width),
        Band c => Padding(
            padding: EdgeInsets.fromLTRB(pad, 36, pad, 0),
            child: Container(
              padding: EdgeInsets.all(wide ? 40 : 24),
              decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(32)),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 16, spacing: 24, children: [
                Text(_l(t, c.t), style: TextStyle(fontSize: wide ? 32 : 24, fontWeight: FontWeight.w700)),
                FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: _ink, foregroundColor: _lime, shape: const StadiumBorder()), onPressed: () => _go(c.go), child: Text(_l(t, c.btn))),
              ]),
            ),
          ),
        Marquee() => Container(
            color: _lime,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(t('● بلاستيك   ● ورق   ● كرتون   ● معادن', '● Plastic   ● Paper   ● Cardboard   ● Metal'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22))),
          ),
        FaqBlk() => _faq(t, pad),
        PricingBlk() => _pricing(t, pad),
      };

  Widget _hero(Tx t, SiteHero h, bool wide, double pad) {
    final dark = !h.light;
    final fg = dark ? Colors.white : _ink;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [TextSpan(text: '${_l(t, h.h1)} '), TextSpan(text: _l(t, h.em), style: TextStyle(color: dark ? _lime : _green))]), style: TextStyle(fontSize: wide ? 68 : 38, fontWeight: FontWeight.w700, height: 1.1, color: fg)),
      const SizedBox(height: 16),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Text(_l(t, h.p), style: TextStyle(fontSize: wide ? 19 : 16, color: fg.withValues(alpha: 0.88)))),
      const SizedBox(height: 24),
      Wrap(spacing: 12, runSpacing: 12, children: [
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 46), backgroundColor: dark ? _lime : _ink, foregroundColor: dark ? _ink : _lime, shape: const StadiumBorder()), onPressed: () => _go(h.go1), child: Text(_l(t, h.b1))),
        if (h.b2 != null) OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: Colors.white, side: const BorderSide(color: Colors.white, width: 2), shape: const StadiumBorder()), onPressed: () => _go(h.go2!), child: Text(_l(t, h.b2!))),
      ]),
    ]);
    final art = Center(
      child: Container(
        width: wide ? 320 : 200,
        height: wide ? 320 : 200,
        decoration: BoxDecoration(shape: BoxShape.circle, color: dark ? const Color(0xFF0B3B2E) : Colors.white, border: Border.all(color: dark ? _lime.withValues(alpha: 0.35) : _line, width: 2)),
        child: Center(child: LogoMark(size: wide ? 150 : 90)),
      ),
    );
    return Container(
      color: dark ? _ink : _mint,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: wide ? 80 : 40),
      child: wide ? Row(children: [Expanded(flex: 11, child: text), const SizedBox(width: 40), Expanded(flex: 9, child: art)]) : Column(children: [text, const SizedBox(height: 28), art]),
    );
  }

  Widget _cards(Tx t, Cards c, double pad, double width) {
    final cols = width >= 860 ? c.items.length : (width >= 560 ? 2 : 1);
    final w = (width - pad * 2 - 20 * (cols - 1)) / cols;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 20, pad, 0),
      child: Wrap(spacing: 20, runSpacing: 20, children: [
        for (var i = 0; i < c.items.length; i++)
          Container(
            width: w.floorToDouble(),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: i.isOdd ? _mint : Colors.white, borderRadius: BorderRadius.circular(28)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle), child: Text(_l(t, c.items[i].$1), style: const TextStyle(fontWeight: FontWeight.w700))),
              const SizedBox(height: 12),
              Text(_l(t, c.items[i].$2), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(_l(t, c.items[i].$3), style: const TextStyle(color: _ink2, fontSize: 15)),
            ]),
          ),
      ]),
    );
  }

  Widget _faq(Tx t, double pad) => Padding(
        padding: EdgeInsets.fromLTRB(pad, 48, pad, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('أسئلة شائعة', 'FAQ'), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          for (var i = 0; i < siteFaqs.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _line, width: 1.5), borderRadius: BorderRadius.circular(20)),
              child: Column(children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => setState(() => _open = _open == i ? -1 : i),
                  child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Expanded(child: Text(_l(t, siteFaqs[i].$1), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17))), Text(_open == i ? '−' : '+', style: const TextStyle(fontSize: 22))])),
                ),
                if (_open == i) Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: Align(alignment: AlignmentDirectional.centerStart, child: Text(_l(t, siteFaqs[i].$2), style: const TextStyle(color: _ink2)))),
              ]),
            ),
        ]),
      );

  Widget _pricing(Tx t, double pad) {
    Widget row(List<String> cells, {bool head = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(color: head ? const Color(0xFFE9F0EA) : Colors.white, border: const Border(bottom: BorderSide(color: _line, width: 1.5))),
          child: Row(children: [for (var i = 0; i < cells.length; i++) Expanded(flex: i == 0 ? 14 : 10, child: Text(cells[i], style: TextStyle(fontWeight: head || i == 0 ? FontWeight.w700 : FontWeight.w400)))]),
        );
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 24, pad, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(children: [
          row([t('الخامة', 'Material'), t('نضيفة (جنيه/كجم)', 'Clean (EGP/kg)'), t('مخلوطة (جنيه/كجم)', 'Mixed (EGP/kg)'), t('سعر الشراء (مثال)', 'Buy price (example)')], head: true),
          for (final p in sitePrices) row([_l(t, p.$1), p.$2, p.$3, p.$4]),
        ]),
      ),
    );
  }

  /// Sends the form to the backend when name and mobile are filled. An empty form only shows the demo message.
  Future<void> _send(Tx t) async {
    final name = _fields[0].text.trim();
    final phone = _fields[1].text.trim();
    if (name.isEmpty || phone.isEmpty) {
      toast(context, t('وصلنا طلبك (تجربة)', 'We got your request (demo)'));
      return;
    }
    setState(() => _sending = true);
    final message = '${_l(t, siteKinds[_kind])} | ${_fields[2].text.trim()} | ${_fields[3].text.trim()}';
    String? err;
    try {
      await ref.read(dioProvider).post('/contact', data: {'name': name, 'contact': phone, 'message': message.length < 5 ? '$message ....' : message});
    } catch (e) {
      err = ApiError.from(e).message;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    toast(context, err ?? t('وصلنا طلبك، هنرجع لك قريب.', 'We got your request and will get back to you soon.'));
    if (err == null) {
      for (final f in _fields) {
        f.clear();
      }
    }
  }

  Widget _contact(Tx t, double pad) {
    Widget field(String hint, int k) => TextField(controller: _fields[k], decoration: InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line, width: 2))));
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 40, pad, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('كلمنا', 'Talk to us'), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
        Text(t('اختار أنت مين، وهنرجع لك.', 'Pick who you are and we will get back to you.'), style: const TextStyle(color: _ink2)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < siteKinds.length; i++)
            ChoiceChip(label: Text(_l(t, siteKinds[i])), selected: _kind == i, onSelected: (_) => setState(() => _kind = i), selectedColor: _ink, labelStyle: TextStyle(color: _kind == i ? _lime : _ink, fontWeight: FontWeight.w600), backgroundColor: Colors.white, side: const BorderSide(color: _line, width: 1.5), shape: const StadiumBorder(), showCheckmark: false),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final two = box.maxWidth >= 640;
          final w = two ? (box.maxWidth - 16) / 2 : box.maxWidth;
          return Wrap(spacing: 16, runSpacing: 16, children: [
            for (final (k, h) in [t('الاسم', 'Name'), t('رقم الموبايل', 'Mobile'), t('المدينة', 'City'), t('كمية تقريبية في الشهر (اختياري)', 'Approx. monthly amount (optional)')].indexed) SizedBox(width: w, child: field(h, k)),
            SizedBox(width: box.maxWidth, child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 56), backgroundColor: _ink, foregroundColor: _lime, shape: const StadiumBorder()), onPressed: _sending ? null : () => _send(t), child: Text(t('ابعت', 'Send')))),
          ]);
        }),
      ]),
    );
  }

  Widget _footer(Tx t, double pad) => Container(
        margin: const EdgeInsets.only(top: 56),
        color: _ink,
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 36),
        child: Wrap(spacing: 24, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('ecoplus', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)), Text(t('صوّر. إحنا نيجي. وانت تكسب.', 'Snap it. We collect. You earn.'), style: const TextStyle(color: Color(0xFFCFE2D8)))]),
          Text(t('أرقام وأسعار الموقع أمثلة للتصميم ولسه هتتحدد.', 'Numbers and prices on this site are design examples and will be set later.'), style: const TextStyle(color: Color(0xFFCFE2D8))),
        ]),
      );
}
