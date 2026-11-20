import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../business/business_logic.dart' show bMats;
import '../common/kit.dart';
import 'buyer_logic.dart';

final buyerTabProvider = NotifierProvider<_IntNotifier, int>(_IntNotifier.new);
final buyerOnboardedProvider = NotifierProvider<_BoolNotifier, bool>(_BoolNotifier.new);
final _catProvider = NotifierProvider<_CatNotifier, int>(_CatNotifier.new);
final _draftProvider = NotifierProvider<_DraftNotifier, _Draft>(_DraftNotifier.new);

class _IntNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void open(int i) => state = i;
}

class _CatNotifier extends Notifier<int> {
  @override
  int build() => -1;
  void pick(int i) => state = i;
}

class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void done() => state = true;
}

class _Draft {
  const _Draft({this.lot = 1, this.qty = 500, this.delivery = false, this.pm = 0});
  final int lot;
  final double qty;
  final bool delivery;
  final int pm;
  _Draft copy({int? lot, double? qty, bool? delivery, int? pm}) => _Draft(lot: lot ?? this.lot, qty: qty ?? this.qty, delivery: delivery ?? this.delivery, pm: pm ?? this.pm);
  double get total => bR1(qty * lotOf(lot).price + (delivery ? deliveryFee : 0));
  bool get valid => qty >= lotOf(lot).min && qty <= lotOf(lot).avail;
}

class _DraftNotifier extends Notifier<_Draft> {
  @override
  _Draft build() => const _Draft();
  void set(_Draft d) => state = d;
}

/// Buyer (independent recycler or factory): browse lots, order, pay, track, contracts and scrap selling.
class BuyerApp extends ConsumerWidget {
  const BuyerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(buyerOnboardedProvider);
    return Navigator(key: ValueKey(onboarded), onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => onboarded ? const _Tabs() : const _SignupPage()));
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final i = ref.watch(buyerTabProvider);
    return Scaffold(
      body: IndexedStack(index: i, children: const [_MarketPage(), _OrdersPage(), _SavedPage(), _MorePage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        indicatorColor: EcoColors.buyer.withValues(alpha: 0.18),
        onDestinationSelected: ref.read(buyerTabProvider.notifier).open,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.storefront_rounded), label: t('السوق', 'Market')),
          NavigationDestination(icon: const Icon(Icons.local_shipping_rounded), label: t('طلباتي', 'Orders')),
          NavigationDestination(icon: const Icon(Icons.bookmark_rounded), label: t('المحفوظ', 'Saved')),
          NavigationDestination(icon: const Icon(Icons.menu_rounded), label: t('المزيد', 'More')),
        ],
      ),
    );
  }
}

String _egp(Tx t, num v) => '${fmt(v)} ${t('جنيه', 'EGP')}';
String _kg(Tx t, num v) => '${fmt(v)} ${t('كجم', 'kg')}';
String _lot(Tx t, Lot l) => t(l.ar, l.en);
String _stage(Tx t, int s) => [t('اتأكد', 'Confirmed'), t('بنجهّز', 'Preparing'), t('جاهز أو في الطريق', 'Ready or on the way'), t('اتسلّم', 'Delivered')][s];
Widget _matBadge(int mat) => Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: bMats[mat].color, borderRadius: BorderRadius.circular(12)), child: Text(bMats[mat].code, style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700)));

// ---------------------------------------------------------------- sign up

class _SignupPage extends ConsumerStatefulWidget {
  const _SignupPage();

  @override
  ConsumerState<_SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<_SignupPage> {
  final _name = TextEditingController();
  bool _factory = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    Widget kind(bool f, String title, String sub) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row3(leading: Icon(_factory == f ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: EcoColors.buyer), title: title, subtitle: sub, onTap: () => setState(() => _factory = f)),
        );
    return Scaffold(
      appBar: RoleBar(title: t('افتح حساب مشتري', 'Open a buyer account'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('اشتري خامات معاد تدويرها مفروزة ومتوزنة من ecoplus.', 'Buy sorted, weighed recycled material from ecoplus.'), style: TextStyle(color: context.eco.inkSoft)),
        SectionLabel(t('أنت إيه؟', 'Which one are you?')),
        kind(false, t('شخص بيدوّر لنفسه', 'Independent recycler'), t('كميات صغيرة، استلام من المخزن', 'Small quantities, warehouse pickup')),
        kind(true, t('مصنع', 'Factory'), t('شحنات كبيرة، عقود، توصيل، وبيع الهالك', 'Bulk batches, contracts, delivery and scrap selling')),
        const SizedBox(height: 8),
        TextField(controller: _name, decoration: InputDecoration(labelText: t('الاسم أو اسم المصنع', 'Name or factory name'))),
        const SizedBox(height: 12),
        TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t('رقم الموبايل', 'Mobile number'))),
        const SizedBox(height: 20),
        BigButton(t('التالي', 'Next'), color: EcoColors.buyer, onTap: () {
          ref.read(buyerProvider.notifier).signup(_name.text.trim(), _factory);
          pushPage(context, const _InterestsPage());
        }),
      ]),
    );
  }
}

class _InterestsPage extends ConsumerWidget {
  const _InterestsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    return Scaffold(
      appBar: RoleBar(title: t('بتدوّر على إيه؟', 'What are you after?')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('هنعرض لك الخامات دي الأول.', 'We will show these first.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 12),
        for (var i = 0; i < bMats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: _matBadge(i), title: t(bMats[i].ar, bMats[i].en), trailing: Icon(s.interests[i] ? Icons.check_circle_rounded : Icons.circle_outlined, color: EcoColors.buyer), onTap: () => ref.read(buyerProvider.notifier).toggleInterest(i)),
          ),
        const SizedBox(height: 12),
        BigButton(t('ابدأ', 'Get started'), color: EcoColors.buyer, onTap: ref.read(buyerOnboardedProvider.notifier).done),
      ]),
    );
  }
}

// ---------------------------------------------------------------- market and lot

class _MarketPage extends ConsumerWidget {
  const _MarketPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    final cat = ref.watch(_catProvider);
    final cats = [t('الكل', 'All'), for (final m in bMats) t(m.ar, m.en)];
    final list = s.market(cat);
    final name = s.name.isEmpty ? (s.factory ? t('مصنع المثال', 'Example Factory') : t('مشتري المثال', 'Example Buyer')) : s.name;
    return Scaffold(
      appBar: RoleBar(title: '${t('أهلاً', 'Welcome')}، $name', back: false, actions: [IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () => pushPage(context, const _AlertsPage()))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var i = 0; i < cats.length; i++)
              Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: ChoiceChip(label: Text(cats[i]), selected: cat == i - 1, selectedColor: EcoColors.buyer.withValues(alpha: 0.2), onSelected: (_) => ref.read(_catProvider.notifier).pick(i - 1))),
          ]),
        ),
        const SizedBox(height: 8),
        if (list.isEmpty) EmptyState(icon: Icons.inbox_rounded, title: t('مفيش حاجة في القسم ده دلوقتي.', 'Nothing in this category right now.'), body: ''),
        for (final l in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: _matBadge(l.mat),
              title: _lot(t, l),
              subtitle: '${t(l.gradeAr, l.gradeEn)} · ${_kg(t, l.avail)}',
              trailing: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(fmt(l.price), style: Theme.of(context).textTheme.titleSmall), Text('${t('جنيه', 'EGP')}/${t('كجم', 'kg')}', style: Theme.of(context).textTheme.bodySmall)]),
              onTap: () {
                ref.read(_draftProvider.notifier).set(_Draft(lot: l.id, qty: l.min));
                pushPage(context, _LotPage(l.id));
              },
            ).fadeUp(),
          ),
        Text(t('الأسعار والكميات أمثلة للتصميم.', 'Prices and quantities are design examples.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 8),
        BigButton(t('مش لاقي اللي عايزه؟ ابعت طلب', 'Not finding it? Post a request'), outlined: true, onTap: () => pushPage(context, const _RequestPage())),
      ]),
    );
  }
}

class _LotPage extends ConsumerWidget {
  const _LotPage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    final l = lotOf(id);
    final saved = s.saved.contains(id);
    final specs = [(t('الجودة', 'Grade'), t(l.gradeAr, l.gradeEn)), (t('المتاح', 'Available'), _kg(t, l.avail)), (t('أقل كمية', 'Minimum'), _kg(t, l.min)), (t('المكان', 'Location'), t('مخزن ecoplus · القاهرة', 'ecoplus warehouse · Cairo')), (t('الشكل', 'Form'), t(l.formAr, l.formEn))];
    return Scaffold(
      appBar: RoleBar(title: t('تفاصيل الدفعة', 'Lot details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _matBadge(l.mat),
            const SizedBox(height: 8),
            Text(_lot(t, l), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
            Text('${fmt(l.price)} ${t('جنيه/كجم', 'EGP/kg')}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: EcoColors.bloom)),
          ]),
        ).fadeUp(),
        const SizedBox(height: 12),
        for (final r in specs) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(r.$1, style: TextStyle(color: context.eco.inkSoft))), Text(r.$2, style: Theme.of(context).textTheme.titleSmall)])),
        const SizedBox(height: 4),
        Text(t('كل دفعة اتفرزت واتوزنت عندنا. الوزن النهائي هو المعتمد.', 'Every lot is sorted and weighed by us. The final weight is the one billed.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: BigButton(saved ? t('محفوظ', 'Saved') : t('احفظ', 'Save'), outlined: true, icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded, onTap: () {
            ref.read(buyerProvider.notifier).toggleSave(id);
            toast(context, saved ? t('اتشالت من المحفوظ', 'Removed from saved') : t('اتحفظت', 'Saved'));
          })),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: BigButton(t('اطلب', 'Order'), color: EcoColors.buyer, onTap: () => pushPage(context, const _OrderPage()))),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- order and pay

Widget _steps(int on) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [for (var i = 0; i < 3; i++) Expanded(child: Container(height: 5, margin: const EdgeInsets.symmetric(horizontal: 2), decoration: BoxDecoration(color: i < on ? EcoColors.buyer : EcoColors.buyer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(3))))]));

class _OrderPage extends ConsumerWidget {
  const _OrderPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final d = ref.watch(_draftProvider);
    final n = ref.read(_draftProvider.notifier);
    final l = lotOf(d.lot);
    Widget ful(bool delivery, String title, String sub, String fee) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row3(leading: Icon(d.delivery == delivery ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: EcoColors.buyer), title: title, subtitle: sub, trailing: Text(fee), onTap: () => n.set(d.copy(delivery: delivery))),
        );
    return Scaffold(
      appBar: RoleBar(title: t('اطلب', 'Order')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _steps(1),
        EcoCard(
          child: Column(children: [
            Row(children: [Expanded(child: Text(_lot(t, l), style: Theme.of(context).textTheme.titleSmall)), Text('${fmt(l.price)} ${t('جنيه/كجم', 'EGP/kg')}')]),
            const SizedBox(height: 12),
            Row(children: [Expanded(child: Text(t('الكمية (كجم)', 'Quantity (kg)'))), StepperField(value: d.qty, step: l.min >= 100 ? 50 : 10, min: 0, max: l.avail, onChanged: (v) => n.set(d.copy(qty: v)))]),
            const SizedBox(height: 6),
            Align(alignment: AlignmentDirectional.centerStart, child: Text('${t('المتاح', 'Available')}: ${_kg(t, l.avail)} · ${t('الأدنى', 'Min')}: ${_kg(t, l.min)}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft))),
          ]),
        ),
        SectionLabel(t('الاستلام', 'Fulfilment')),
        ful(false, t('استلام من المخزن', 'Warehouse pickup'), t('جاهز خلال يوم عمل', 'Ready within one business day'), t('مجاني', 'Free')),
        ful(true, t('توصيل', 'Delivery'), t('مصاريف توصيل ثابتة (مثال)', 'Flat delivery fee (example)'), _egp(t, deliveryFee)),
        if (!d.valid) Text(t('الكمية لازم تكون بين الأدنى والمتاح.', 'Quantity must be between the minimum and what is available.'), style: TextStyle(color: context.eco.danger)),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: Text(t('الإجمالي', 'Total'), style: TextStyle(color: context.eco.inkSoft))), Text(_egp(t, d.total), style: Theme.of(context).textTheme.titleLarge)]),
        const SizedBox(height: 12),
        BigButton(t('التالي', 'Next'), color: EcoColors.buyer, onTap: d.valid ? () => pushPage(context, const _PayPage()) : null),
      ]),
    );
  }
}

class _PayPage extends ConsumerWidget {
  const _PayPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final d = ref.watch(_draftProvider);
    final n = ref.read(_draftProvider.notifier);
    final l = lotOf(d.lot);
    final pms = [t('تحويل بنكي', 'Bank transfer'), t('محفظة موبايل', 'Mobile wallet'), t('كاش عند الاستلام', 'Cash on pickup')];
    final rows = [(t('الدفعة', 'Lot'), _lot(t, l)), (t('الكمية', 'Quantity'), _kg(t, d.qty)), (t('الاستلام', 'Fulfilment'), d.delivery ? t('توصيل', 'Delivery') : t('استلام من المخزن', 'Warehouse pickup')), (t('الإجمالي', 'Total'), _egp(t, d.total))];
    return Scaffold(
      appBar: RoleBar(title: t('راجع وادفع', 'Review and pay')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _steps(2),
        EcoCard(child: Column(children: [for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(r.$1)), Text(r.$2, style: Theme.of(context).textTheme.titleSmall)]))])),
        SectionLabel(t('طريقة الدفع', 'Payment method')),
        for (var i = 0; i < pms.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(d.pm == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: EcoColors.buyer), title: pms[i], onTap: () => n.set(d.copy(pm: i)))),
        Text(t('الدفع والفواتير تصميم لمرحلة لاحقة بأرقام مثال.', 'Payments and invoices are a later-phase design with example numbers.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('أكّد الطلب', 'Place order'), color: EcoColors.buyer, onTap: () async {
          final bn = ref.read(buyerProvider.notifier);
          if (bn.isReal) {
            final r = await bn.placeOrderReal(d.lot, d.qty);
            if (!context.mounted) return;
            if (r.id == null) {
              toast(context, r.error ?? '');
              return;
            }
            replacePage(context, _OrderDonePage(r.id!));
            return;
          }
          final id = bn.placeOrder(d.lot, d.qty, d.delivery);
          if (id < 0) return;
          replacePage(context, _OrderDonePage(id));
        }),
      ]),
    );
  }
}

class _OrderDonePage extends ConsumerWidget {
  const _OrderDonePage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_rounded, size: 84, color: EcoColors.buyer).fadeUp(),
            const SizedBox(height: 16),
            Text(t('الطلب اتسجّل', 'Order placed'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('${t('طلب رقم', 'Order')} #$id', style: TextStyle(color: context.eco.inkSoft)),
            const SizedBox(height: 24),
            BigButton(t('تابع الطلب', 'Track order'), color: EcoColors.buyer, onTap: () => replacePage(context, _OrderDetailPage(id))),
            const SizedBox(height: 8),
            BigButton(t('السوق', 'Market'), outlined: true, onTap: () {
              ref.read(buyerTabProvider.notifier).open(0);
              popToRoot(context);
            }),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- orders

class _OrdersPage extends ConsumerStatefulWidget {
  const _OrdersPage();

  @override
  ConsumerState<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends ConsumerState<_OrdersPage> {
  bool _active = true;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    final list = s.orders.where((o) => _active != o.done).toList();
    return Scaffold(
      appBar: RoleBar(title: t('طلباتي', 'Orders'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(segments: [ButtonSegment(value: true, label: Text(t('شغالة', 'Active'))), ButtonSegment(value: false, label: Text(t('اتسلمت', 'Delivered')))], selected: {_active}, onSelectionChanged: (v) => setState(() => _active = v.first)),
        const SizedBox(height: 12),
        if (list.isEmpty) EmptyState(icon: Icons.inbox_rounded, title: t('مفيش حاجة هنا.', 'Nothing here.'), body: ''),
        for (final o in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: const Icon(Icons.local_shipping_rounded, color: EcoColors.buyer), title: '#${o.id} · ${_lot(t, lotOf(o.lot))}', subtitle: '${_kg(t, o.qty)} · ${_egp(t, o.total)}', trailing: Tag(_stage(t, o.stage), color: o.done ? context.eco.primary : context.eco.amber), onTap: () => pushPage(context, _OrderDetailPage(o.id))),
          ),
      ]),
    );
  }
}

class _OrderDetailPage extends ConsumerWidget {
  const _OrderDetailPage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final o = ref.watch(buyerProvider).orders.firstWhere((x) => x.id == id);
    final c = context.eco;
    final steps = [t('الطلب اتأكد', 'Order confirmed'), t('بنوزن ونجهّز الدفعة', 'Weighing and preparing the lot'), t('جاهزة للاستلام أو خرجت للتوصيل', 'Ready for pickup or out for delivery'), t('اتسلّمت وتم الوزن النهائي', 'Delivered, final weight confirmed')];
    final l = lotOf(o.lot);
    final rows = [(t('الدفعة', 'Lot'), _lot(t, l)), (t('الكمية', 'Quantity'), _kg(t, o.qty)), (t('السعر', 'Price'), '${fmt(l.price)} ${t('جنيه/كجم', 'EGP/kg')}'), (t('التوصيل', 'Delivery'), o.delivery ? _egp(t, deliveryFee) : t('مجاني', 'Free'))];
    return Scaffold(
      appBar: RoleBar(title: t('تفاصيل الطلب', 'Order details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Expanded(child: Text('#${o.id}', style: Theme.of(context).textTheme.headlineSmall)), Tag(_stage(t, o.stage), color: o.done ? c.primary : c.amber)]),
        const SizedBox(height: 12),
        EcoCard(
          child: Column(children: [
            for (var i = 0; i < steps.length; i++)
              Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(i <= o.stage ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i <= o.stage ? EcoColors.buyer : c.inkSoft), const SizedBox(width: 10), Expanded(child: Text(steps[i], style: TextStyle(fontWeight: i == o.stage ? FontWeight.w700 : FontWeight.w400)))])),
          ]),
        ),
        const SizedBox(height: 12),
        for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(r.$1, style: TextStyle(color: c.inkSoft))), Text(r.$2)])),
        const SizedBox(height: 16),
        if (o.done) BigButton(t('شوف الفاتورة', 'View invoice'), color: EcoColors.buyer, onTap: () => pushPage(context, _InvoicePage(o.id))) else BigButton(t('كمّل خطوة (تجربة)', 'Advance a step (demo)'), outlined: true, onTap: () => ref.read(buyerProvider.notifier).advance(o.id)),
      ]),
    );
  }
}

class _InvoicePage extends ConsumerWidget {
  const _InvoicePage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final o = ref.watch(buyerProvider).orders.firstWhere((x) => x.id == id);
    final l = lotOf(o.lot);
    final rows = [(t('الدفعة', 'Lot'), _lot(t, l)), (t('الكمية', 'Quantity'), _kg(t, o.qty)), (t('السعر', 'Price'), '${fmt(l.price)} ${t('جنيه/كجم', 'EGP/kg')}'), (t('التوصيل', 'Delivery'), o.delivery ? _egp(t, deliveryFee) : t('مجاني', 'Free'))];
    return Scaffold(
      appBar: RoleBar(title: t('الفاتورة', 'Invoice')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(child: Row(children: [Expanded(child: Text('#${o.id}', style: Theme.of(context).textTheme.titleMedium)), Tag(t('مدفوع', 'Paid'), color: context.eco.primary)])),
        const SizedBox(height: 4),
        Text(t('فاتورة تجريبية.', 'Sample invoice.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 12),
        EcoCard(
          child: Column(children: [
            for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(r.$1)), Text(r.$2)])),
            const Divider(height: 24),
            Row(children: [Expanded(child: Text(t('الإجمالي', 'Total'), style: Theme.of(context).textTheme.titleSmall)), Text(_egp(t, o.total), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: context.eco.primary))]),
          ]),
        ),
        const SizedBox(height: 12),
        BigButton(t('نزّل PDF', 'Download PDF'), outlined: true, icon: Icons.download_rounded, onTap: () => toast(context, t('هتتفعّل مع السيرفر', 'Available once connected to the server'))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- saved, alerts, request

class _SavedPage extends ConsumerWidget {
  const _SavedPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    return Scaffold(
      appBar: RoleBar(title: t('المحفوظ', 'Saved'), back: false, actions: [IconButton(icon: const Icon(Icons.notifications_rounded), onPressed: () => pushPage(context, const _AlertsPage()))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (s.saved.isEmpty) EmptyState(icon: Icons.bookmark_border_rounded, title: t('لسه محفظتش حاجة. اضغط حفظ في أي دفعة.', 'Nothing saved yet. Tap Save on any lot.'), body: ''),
        for (final id in s.saved)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: _matBadge(lotOf(id).mat), title: _lot(t, lotOf(id)), subtitle: _kg(t, lotOf(id).avail), trailing: Text(fmt(lotOf(id).price), style: Theme.of(context).textTheme.titleSmall), onTap: () {
              ref.read(_draftProvider.notifier).set(_Draft(lot: id, qty: lotOf(id).min));
              pushPage(context, _LotPage(id));
            }),
          ),
      ]),
    );
  }
}

class _AlertsPage extends ConsumerWidget {
  const _AlertsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    final labels = [t('دفعة جديدة', 'New lots'), t('نزول الأسعار', 'Price drops'), t('حالة الطلب', 'Order status'), t('أخبار', 'News')];
    final feed = [(t('نزلت دفعة بلاستيك PET جديدة', 'A new PET plastic lot arrived'), t('من ساعة', '1h ago')), (t('طلب #2031 بيتجهّز', 'Order #2031 is being prepared'), t('امبارح', 'Yesterday')), (t('سعر الكرتون نزل', 'Cardboard price dropped'), t('من يومين', '2d ago'))];
    return Scaffold(
      appBar: RoleBar(title: t('التنبيهات', 'Alerts')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('نبلّغك لما تنزل دفعة بتدوّر عليها أو يتغير السعر.', 'We notify you when a lot you want arrives or a price changes.'), style: TextStyle(color: context.eco.inkSoft)),
        for (var i = 0; i < 4; i++) SwitchListTile(contentPadding: EdgeInsets.zero, value: s.prefs[i], onChanged: (_) => ref.read(buyerProvider.notifier).togglePref(i), title: Text(labels[i])),
        SectionLabel(t('آخر التنبيهات', 'Latest')),
        for (final f in feed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: f.$1, subtitle: f.$2)),
      ]),
    );
  }
}

class _RequestPage extends ConsumerStatefulWidget {
  const _RequestPage();

  @override
  ConsumerState<_RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends ConsumerState<_RequestPage> {
  int _mat = 0;
  double _qty = 200;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('ابعت طلب', 'Post a request')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('قول عايز إيه ونحاول نوفّره لك.', 'Tell us what you need and we will try to source it.'), style: TextStyle(color: context.eco.inkSoft)),
        SectionLabel(t('الخامة', 'Material')),
        Wrap(spacing: 8, children: [for (var i = 0; i < bMats.length; i++) ChoiceChip(label: Text(t(bMats[i].ar, bMats[i].en)), selected: _mat == i, onSelected: (_) => setState(() => _mat = i))]),
        const SizedBox(height: 14),
        EcoCard(child: Row(children: [Expanded(child: Text(t('الكمية (كجم)', 'Quantity (kg)'))), StepperField(value: _qty, step: 50, min: 10, max: 20000, onChanged: (v) => setState(() => _qty = v))])),
        const SizedBox(height: 12),
        TextField(keyboardType: TextInputType.number, decoration: InputDecoration(labelText: t('السعر المستهدف (اختياري)', 'Target price (optional)'))),
        const SizedBox(height: 16),
        BigButton(t('ابعت الطلب', 'Send request'), color: EcoColors.buyer, onTap: () {
          ref.read(buyerProvider.notifier).postRequest();
          toast(context, t('الطلب اتبعت', 'Request sent'));
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- contracts, scrap

class _ContractsPage extends ConsumerWidget {
  const _ContractsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    return Scaffold(
      appBar: RoleBar(title: t('العقود', 'Contracts'), actions: [
        TextButton(
          onPressed: () {
            ref.read(buyerProvider.notifier).newContract();
            toast(context, t('طلب العقد اتبعت للمراجعة', 'Contract request sent for review'));
          },
          child: Text(t('إضافة', 'Add')),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('توريد منتظم بسعر متفق عليه. أمثلة للتصميم.', 'Regular supply at an agreed price. Design examples.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 12),
        for (final c in s.contracts) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: const Icon(Icons.description_rounded, color: EcoColors.buyer), title: t(c.ar, c.en), subtitle: t(c.subAr, c.subEn), trailing: Tag(c.active ? t('ساري', 'Active') : t('مراجعة', 'In review'), color: c.active ? context.eco.primary : context.eco.amber))),
      ]),
    );
  }
}

class _ScrapPage extends ConsumerStatefulWidget {
  const _ScrapPage();

  @override
  ConsumerState<_ScrapPage> createState() => _ScrapPageState();
}

class _ScrapPageState extends ConsumerState<_ScrapPage> {
  int _mat = 0;
  double _qty = 300;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('بيع الهالك', 'Sell production scrap')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('المصنع كمان بيبيع لنا الهالك. نفس رحلة البيع: طلب، استلام، وزن، دفع.', 'Factories also sell scrap to us. Same journey: request, pickup, weigh, payout.'), style: TextStyle(color: context.eco.inkSoft)),
        SectionLabel(t('الخامة', 'Material')),
        Wrap(spacing: 8, children: [for (var i = 0; i < bMats.length; i++) ChoiceChip(label: Text(t(bMats[i].ar, bMats[i].en)), selected: _mat == i, onSelected: (_) => setState(() => _mat = i))]),
        const SizedBox(height: 14),
        EcoCard(child: Row(children: [Expanded(child: Text(t('الكمية (كجم)', 'Quantity (kg)'))), StepperField(value: _qty, step: 50, min: 10, max: 50000, onChanged: (v) => setState(() => _qty = v))])),
        const SizedBox(height: 8),
        Text(t('السعر النهائي بالوزن الفعلي. الأسعار أمثلة.', 'Final price follows the weighed amount. Prices are examples.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('ابعت طلب استلام', 'Request pickup'), color: EcoColors.buyer, onTap: () {
          ref.read(buyerProvider.notifier).postScrap();
          toast(context, t('طلب الاستلام اتبعت', 'Pickup request sent'));
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- wallet, help, settings, more

class _WalletPage extends ConsumerWidget {
  const _WalletPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    final pms = [t('تحويل بنكي', 'Bank transfer'), t('محفظة موبايل', 'Mobile wallet'), t('كاش عند الاستلام', 'Cash on pickup')];
    return Scaffold(
      appBar: RoleBar(title: t('المدفوعات', 'Payments')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('إجمالي المشتريات', 'Total purchases'), style: const TextStyle(color: EcoColors.onCanopy)),
            AnimatedSwitcher(duration: Motion.base, child: Text(_egp(t, s.spent), key: ValueKey(s.spent), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EcoColors.bloom))),
            Text('${t('عدد الطلبات', 'Orders')}: ${s.orders.length}', style: const TextStyle(color: EcoColors.onCanopy)),
          ]),
        ),
        SectionLabel(t('طريقة الدفع', 'Payment method')),
        for (final p in pms) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: const Icon(Icons.credit_card_rounded, color: EcoColors.buyer), title: p, trailing: Tag(t('شغال', 'On'), color: context.eco.primary))),
      ]),
    );
  }
}

class _SupportPage extends ConsumerWidget {
  const _SupportPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final faq = [
      (t('إزاي بتتحسب الفلوس؟', 'How is billing calculated?'), t('بالوزن النهائي × سعر الكيلو + التوصيل.', 'Final weight × price per kg + delivery.')),
      (t('ينفع أرجّع؟', 'Can I return?'), t('لو الجودة مختلفة عن الوصف بلّغنا في 24 ساعة.', 'If quality differs from the listing tell us within 24 hours.')),
      (t('إيه أقل كمية؟', 'What is the minimum?'), t('بتختلف بحسب الدفعة وموضحة في تفاصيلها.', 'It varies per lot and is shown in its details.')),
      (t('إزاي أعمل عقد؟', 'How do I set up a contract?'), t('من العقود اضغط إضافة (للمصانع).', 'From Contracts tap Add (factories).')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('المساعدة', 'Help')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final f in faq) Padding(padding: const EdgeInsets.only(bottom: 8), child: EcoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.$1, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4), Text(f.$2, style: TextStyle(color: context.eco.inkSoft))]))),
        const SizedBox(height: 8),
        BigButton(t('اتصل بالدعم', 'Call support'), color: EcoColors.buyer, icon: Icons.support_agent_rounded, onTap: () => toast(context, t('هتتفعّل مع السيرفر', 'Available once connected to the server'))),
      ]),
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('الإعدادات', 'Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(leading: const Icon(Icons.notifications_rounded, color: EcoColors.buyer), title: t('التنبيهات', 'Alerts'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => pushPage(context, const _AlertsPage())),
        const SizedBox(height: 16),
        BigButton(t('تسجيل خروج', 'Sign out'), outlined: true, icon: Icons.logout_rounded, onTap: ref.read(sessionProvider.notifier).logout),
      ]),
    );
  }
}

class _MorePage extends ConsumerWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(buyerProvider);
    Widget item(IconData i, String title, Widget page) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(i, color: EcoColors.buyer), title: title, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => pushPage(context, page)));
    final name = s.name.isEmpty ? (s.factory ? t('مصنع المثال', 'Example Factory') : t('مشتري المثال', 'Example Buyer')) : s.name;
    return Scaffold(
      appBar: RoleBar(title: t('المزيد', 'More'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(child: Row(children: [CircleAvatar(backgroundColor: EcoColors.buyer, child: Text(name.characters.first, style: const TextStyle(color: Colors.white))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.titleSmall), Text(s.factory ? t('مصنع', 'Factory') : t('شخص بيدوّر لنفسه', 'Independent recycler'), style: TextStyle(color: context.eco.inkSoft))]))])),
        const SizedBox(height: 12),
        item(Icons.account_balance_wallet_rounded, t('المدفوعات', 'Payments'), const _WalletPage()),
        if (s.factory) item(Icons.description_rounded, t('العقود', 'Contracts'), const _ContractsPage()),
        if (s.factory) item(Icons.recycling_rounded, t('بيع الهالك', 'Sell scrap'), const _ScrapPage()),
        item(Icons.chat_bubble_rounded, t('ابعت طلب', 'Post a request'), const _RequestPage()),
        item(Icons.notifications_rounded, t('التنبيهات', 'Alerts'), const _AlertsPage()),
        item(Icons.help_rounded, t('المساعدة', 'Help'), const _SupportPage()),
        item(Icons.settings_rounded, t('الإعدادات', 'Settings'), const _SettingsPage()),
      ]),
    );
  }
}
