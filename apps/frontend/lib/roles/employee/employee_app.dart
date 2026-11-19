import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/session.dart';
import '../common/kit.dart';
import '../common/qr_camera.dart';
import 'employee_logic.dart';

/// Which tab of the employee app is open. A notifier so "go to batches" works from any screen.
final employeeTabProvider = NotifierProvider<_TabNotifier, int>(_TabNotifier.new);

class _TabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void open(int i) => state = i;
}

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
void _replace(BuildContext context, Widget page) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
void _home(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

/// Warehouse employee: receive from the driver, weigh with a scale photo, build and close batches.
class EmployeeApp extends StatelessWidget {
  const EmployeeApp({super.key});

  @override
  Widget build(BuildContext context) => Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _Tabs()));
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final i = ref.watch(employeeTabProvider);
    return Scaffold(
      body: IndexedStack(index: i, children: const [QueuePage(), BatchesPage(), StockPage(), MePage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: ref.read(employeeTabProvider.notifier).open,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.list_alt_rounded), label: t('الشحنات', 'Queue')),
          NavigationDestination(icon: const Icon(Icons.inventory_2_rounded), label: t('الدفعات', 'Batches')),
          NavigationDestination(icon: const Icon(Icons.warehouse_rounded), label: t('المخزون', 'Stock')),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: t('حسابي', 'Profile')),
        ],
      ),
    );
  }
}

String _who(Tx t, EmpShip s) => t(s.whoAr, s.whoEn);
String _kind(Tx t, EmpShip s) => s.biz ? t('بيزنس', 'Business') : t('مواطن', 'Citizen');
String _reward(Tx t, EmpShip s, double v) => s.biz ? '${fmt(v)} ${t('جنيه', 'EGP')}' : '${fmt(v)} ${t('نقطة', 'pts')}';

(String, Color) _statusOf(Tx t, BuildContext context, ShipStatus s) => switch (s) {
      ShipStatus.waiting => (t('مستنية', 'Waiting'), context.eco.amber),
      ShipStatus.weighed => (t('اتوزنت', 'Weighed'), context.eco.primary),
      ShipStatus.rejected => (t('مرفوضة', 'Rejected'), context.eco.danger),
    };

// ---------------------------------------------------------------- queue

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(employeeProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('شحنات مستنية', 'Shipments waiting'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('مخزن القاهرة · مثال', 'Cairo warehouse · example'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.inkSoft)),
        const SizedBox(height: 12),
        Row(children: [
          Kpi(value: '${st.count(ShipStatus.waiting)}', label: t('مستنية', 'waiting'), color: c.amber),
          const SizedBox(width: 10),
          Kpi(value: '${st.count(ShipStatus.weighed)}', label: t('اتوزنت', 'weighed')),
          const SizedBox(width: 10),
          Kpi(value: '${st.count(ShipStatus.rejected)}', label: t('مرفوضة', 'rejected'), color: c.danger),
        ]).fadeUp(),
        const SizedBox(height: 16),
        BigButton(t('مسح', 'Scan'), icon: Icons.qr_code_scanner_rounded, onTap: () => _push(context, const ScanPage())).fadeUp(index: 1),
        const SizedBox(height: 12),
        for (var i = 0; i < st.ships.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ShipRow(st.ships[i]).fadeUp(index: i + 2),
          ),
      ]),
    );
  }
}

class _ShipRow extends ConsumerWidget {
  const _ShipRow(this.ship);
  final EmpShip ship;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final (label, color) = _statusOf(t, context, ship.status);
    final kg = totalKg(ship.weights ?? ship.est);
    return Row3(
      leading: CircleAvatar(backgroundColor: context.eco.surfaceAlt, child: Text('${ship.id % 100}', style: TextStyle(color: context.eco.primary, fontWeight: FontWeight.w700))),
      title: _who(t, ship),
      subtitle: '${_kind(t, ship)} · ${fmt(kg)} ${t('كجم', 'kg')} · #${ship.id}',
      trailing: Tag(label, color: color),
      onTap: ship.status == ShipStatus.waiting ? () => _push(context, ReceivePage(ship.id)) : () => toast(context, label),
    );
  }
}

// ---------------------------------------------------------------- scan

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _code = TextEditingController();
  bool _notFound = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _open(int id) => _replace(context, ReceivePage(id));

  bool _busy = false;
  String? _err;

  Future<void> _lookup(String code) async {
    if (_busy || code.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await ref.read(employeeProvider.notifier).lookupQr(code);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.id != null) {
      _open(r.id!);
    } else {
      setState(() => _err = r.error);
    }
  }

  void _find() {
    if (ref.read(employeeProvider.notifier).isReal) {
      _lookup(_code.text);
      return;
    }
    final id = int.tryParse(_code.text.trim());
    final ship = id == null ? null : ref.read(employeeProvider).byId(id);
    if (ship == null || ship.status != ShipStatus.waiting) {
      setState(() => _notFound = true);
      return;
    }
    _open(ship.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final waiting = ref.watch(employeeProvider).ships.where((s) => s.status == ShipStatus.waiting).toList();
    final real = ref.read(employeeProvider.notifier).isReal;
    return Scaffold(
      appBar: RoleBar(title: t('مسح الشحنة', 'Scan shipment')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (real)
          QrCamera(hint: t('وجّه الكاميرا على كود الشحنة', 'Point the camera at the shipment code'), onCode: _lookup)
        else
        Pressable(
          onTap: waiting.isEmpty ? null : () => _open(waiting.first.id),
          child: Container(
            height: 260,
            decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(24)),
            child: Stack(alignment: Alignment.center, children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(border: Border.all(color: EcoColors.bloom, width: 3), borderRadius: BorderRadius.circular(24)),
              ),
              Positioned(bottom: 18, child: Text(t('وجّه الكاميرا على كود الشحنة', 'Point the camera at the shipment code'), style: const TextStyle(color: Colors.white))),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          keyboardType: real ? TextInputType.text : TextInputType.number,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {
            _notFound = false;
            _err = null;
          }),
          onSubmitted: (_) => _find(),
          decoration: InputDecoration(labelText: real ? t('اكتب كود الشحنة (ECO-...)', 'Type shipment code (ECO-...)') : t('اكتب رقم الشحنة', 'Type shipment number'), prefixIcon: const Icon(Icons.tag_rounded)),
        ),
        if (_notFound) Padding(padding: const EdgeInsets.only(top: 10), child: Text(t('الرقم مش موجود في قايمة النهارده.', 'That number is not in today list.'), style: TextStyle(color: c.danger))),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_err!, style: TextStyle(color: c.danger))),
        const SizedBox(height: 16),
        BigButton(t('افتح الشحنة', 'Open shipment'), onTap: _busy ? null : _find),
      ]),
    );
  }
}

// ---------------------------------------------------------------- receive from driver

class ReceivePage extends ConsumerStatefulWidget {
  const ReceivePage(this.id, {super.key});
  final int id;

  @override
  ConsumerState<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends ConsumerState<ReceivePage> {
  late double _bags = (ref.read(employeeProvider).byId(widget.id)?.biz ?? false) ? 3 : 1;
  bool _photo = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final ship = ref.watch(employeeProvider).byId(widget.id)!;
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('استلام من السواق', 'Receive from driver')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('راجع الأكياس مع السواق وصوّرها قبل الوزن.', 'Check the bags with the driver and photograph them before weighing.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 14),
        Row3(
          leading: Icon(Icons.local_shipping_rounded, color: c.primary),
          title: '${t('السواق', 'Driver')}: ${t('سواق 1', 'Driver 1')}',
          subtitle: '${_who(t, ship)} · #${ship.id}',
        ),
        SectionLabel(t('عدد الأكياس', 'Bags received')),
        Center(child: StepperField(value: _bags, min: 1, onChanged: (v) => setState(() => _bags = v))),
        const SizedBox(height: 16),
        PhotoSlot(taken: _photo, onTap: () => setState(() => _photo = !_photo), takeLabel: t('صوّر الأكياس المستلمة', 'Photograph received bags'), doneLabel: t('اتصوّرت ✓', 'Photo added ✓')),
        const SizedBox(height: 20),
        BigButton(t('استلمت وابدأ الوزن', 'Received, start weighing'), onTap: _photo ? () {
          toast(context, t('اتسجّل استلامك من السواق', 'Receipt from driver recorded'));
          _replace(context, WeighPage(widget.id));
        } : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------- weigh

class WeighPage extends ConsumerStatefulWidget {
  const WeighPage(this.id, {super.key});
  final int id;

  @override
  ConsumerState<WeighPage> createState() => _WeighPageState();
}

class _WeighPageState extends ConsumerState<WeighPage> {
  late final List<double> _w = [...ref.read(employeeProvider).byId(widget.id)!.est];
  bool _photo = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final ship = ref.watch(employeeProvider).byId(widget.id)!;
    final c = context.eco;
    final total = totalKg(_w);
    return Scaffold(
      appBar: RoleBar(title: t('الوزن', 'Weigh')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${_who(t, ship)} · ${_kind(t, ship)}', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(t('الوزن اللي بتدخله هو المعتمد للحساب. التقدير للمقارنة بس.', 'The weight you enter is the one used. The estimate is for comparison only.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 12),
        for (var i = 0; i < mats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EcoCard(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: mats[i].color, borderRadius: BorderRadius.circular(12)), alignment: Alignment.center, child: Text(mats[i].code, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0D2B22)))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t(mats[i].ar, mats[i].en), style: Theme.of(context).textTheme.titleSmall),
                    Text('${t('تقدير', 'Est.')} ${fmt(ship.est[i])} ${t('كجم', 'kg')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
                  ]),
                ),
                StepperField(value: _w[i], step: 0.5, onChanged: (v) => setState(() => _w[i] = v)),
              ]),
            ),
          ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${t('الإجمالي', 'Total')}: ${fmt(total)} ${t('كجم', 'kg')}', style: Theme.of(context).textTheme.titleLarge)),
        PhotoSlot(taken: _photo, onTap: () => setState(() => _photo = !_photo), takeLabel: t('صوّر الميزان بالوزن', 'Photograph the scale reading'), doneLabel: t('صورة الميزان اتحفظت ✓', 'Scale photo saved ✓')),
        const SizedBox(height: 16),
        BigButton(t('التالي', 'Next'), onTap: _photo && total > 0 ? () => _push(context, ConfirmPage(widget.id, [..._w])) : null),
        const SizedBox(height: 10),
        BigButton(t('ارفض', 'Reject'), outlined: true, danger: true, onTap: () => _push(context, RejectPage(widget.id))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- confirm and done

class ConfirmPage extends ConsumerWidget {
  const ConfirmPage(this.id, this.weights, {super.key});
  final int id;
  final List<double> weights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final ship = ref.watch(employeeProvider).byId(id)!;
    final c = context.eco;
    final result = ship.biz ? payoutFor(weights) : pointsFor(weights, ship.level);
    return Scaffold(
      appBar: RoleBar(title: t('تأكيد الوزن', 'Confirm weights')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(children: [
            for (var i = 0; i < mats.length; i++)
              if (weights[i] > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text('${t(mats[i].ar, mats[i].en)} · ${fmt(weights[i])} ${t('كجم', 'kg')}')),
                    Text(ship.biz ? '× ${fmt(mats[i].price)} ${t('سعر الكيلو', 'per kg')}' : '× ${fmt(mats[i].factor)} ${t('معامل', 'factor')}', style: TextStyle(color: c.inkSoft)),
                  ]),
                ),
            if (!ship.biz && ship.level != 1) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Expanded(child: Text(t('مضاعف المستوى', 'level multiplier'))), Text('× ${fmt(ship.level)}')])),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(ship.biz ? t('مبلغ البائع', 'Seller payout') : t('نقاط العميل', 'Customer points'), style: Theme.of(context).textTheme.titleMedium)),
              Text(_reward(t, ship, result), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: c.primary)),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        Text(t('الحفظ عملية واحدة: كله يتسجّل أو مفيش حاجة. ولو اتكرر الإرسال مش هيتسجّل مرتين.', 'Saving is one all-or-nothing step. Sending twice does not record twice.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 20),
        BigButton(t('احفظ الوزن', 'Save weights'), onTap: () async {
          final n = ref.read(employeeProvider.notifier);
          if (n.isReal) {
            final err = await n.weighReal(id, weights);
            if (!context.mounted) return;
            if (err != null) {
              toast(context, err);
              return;
            }
          } else {
            n.saveWeights(id, weights);
          }
          _replace(context, DonePage(id));
        }),
      ]),
    );
  }
}

class DonePage extends ConsumerWidget {
  const DonePage(this.id, {super.key});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 96, height: 96, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 52, color: c.primary)).fadeUp(),
            const SizedBox(height: 20),
            Text(t('اتسجّل الوزن', 'Weights saved'), style: Theme.of(context).textTheme.headlineSmall).fadeUp(index: 1),
            const SizedBox(height: 8),
            Text(t('اتضاف للدفعة المناسبة واتسجّل في السجل.', 'Added to the matching batch and written to the ledger.'), textAlign: TextAlign.center, style: TextStyle(color: c.inkSoft)).fadeUp(index: 2),
            const SizedBox(height: 32),
            BigButton(t('الشحنة اللي بعدها', 'Next shipment'), onTap: () => _home(context)),
            const SizedBox(height: 10),
            BigButton(t('الدفعات', 'Batches'), outlined: true, onTap: () {
              ref.read(employeeTabProvider.notifier).open(1);
              _home(context);
            }),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- reject

class RejectPage extends ConsumerStatefulWidget {
  const RejectPage(this.id, {super.key});
  final int id;

  @override
  ConsumerState<RejectPage> createState() => _RejectPageState();
}

class _RejectPageState extends ConsumerState<RejectPage> {
  int _reason = -1;
  bool _photo = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final reasons = [
      t('خامات متّسخة أو مخلوطة', 'Dirty or mixed materials'),
      t('مواد خطرة', 'Hazardous items'),
      t('مش مطابقة للوصف', 'Does not match description'),
      t('كمية صفر', 'Nothing to weigh'),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('رفض الشحنة', 'Reject shipment')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('اختار السبب وصوّر. العميل هيتبلّغ.', 'Pick a reason and take a photo. The customer is notified.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 12),
        for (var i = 0; i < reasons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              title: reasons[i],
              leading: Icon(_reason == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _reason == i ? context.eco.primary : context.eco.inkSoft),
              onTap: () => setState(() => _reason = i),
            ),
          ),
        const SizedBox(height: 8),
        PhotoSlot(taken: _photo, onTap: () => setState(() => _photo = !_photo), takeLabel: t('صوّر المشكلة', 'Photograph the issue'), doneLabel: t('اتصوّرت ✓', 'Photo added ✓')),
        const SizedBox(height: 20),
        BigButton(t('أكّد الرفض', 'Confirm rejection'), danger: true, onTap: _reason >= 0 && _photo ? () async {
          final n = ref.read(employeeProvider.notifier);
          if (n.isReal) {
            final err = await n.rejectReal(widget.id, reasons[_reason]);
            if (!context.mounted) return;
            if (err != null) {
              toast(context, err);
              return;
            }
          } else {
            n.reject(widget.id);
          }
          toast(context, t('اتسجّل الرفض', 'Rejection recorded'));
          _home(context);
        } : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------- batches

class BatchesPage extends ConsumerWidget {
  const BatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final batches = ref.watch(employeeProvider).batches;
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('الدفعات', 'Batches'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('كل خامة ليها دفعة مفتوحة. لما تتقفل بتتعرض للبيع.', 'Each material has an open batch. When closed it is listed for sale.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 12),
        for (var i = 0; i < batches.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _BatchCard(batches[i], onTap: () => _push(context, BatchDetailPage(i))).fadeUp(index: i),
          ),
      ]),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  const _BatchCard(this.b, {required this.onTap});
  final EmpBatch b;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final m = mats[b.mat];
    final (label, color) = b.closed ? (t('اتقفلت', 'Closed'), c.inkSoft) : b.fill > 0.8 ? (t('قربت تتملي', 'Almost full'), c.amber) : (t('مفتوحة', 'Open'), c.primary);
    return EcoCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${t(m.ar, m.en)} · ${b.code}', style: Theme.of(context).textTheme.titleSmall)),
          Tag(label, color: color),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: b.fill.clamp(0, 1), minHeight: 10, backgroundColor: c.surfaceAlt, color: color)),
        const SizedBox(height: 6),
        Text('${fmt(b.kg)} / ${fmt(m.capacity)} ${t('كجم', 'kg')}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
      ]),
    );
  }
}

class BatchDetailPage extends ConsumerWidget {
  const BatchDetailPage(this.index, {super.key});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final b = ref.watch(employeeProvider).batches[index];
    final m = mats[b.mat];
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('تفاصيل الدفعة', 'Batch details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t(m.ar, m.en)} · ${b.code}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('${fmt(b.kg)} ${t('كجم', 'kg')}', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: c.primary)),
          ]),
        ),
        SectionLabel(t('الشحنات المكوّنة', 'Source shipments')),
        for (final s in b.sources) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: '#${s.$1}', trailing: Text('${fmt(s.$2)} ${t('كجم', 'kg')}'))),
        const SizedBox(height: 8),
        Text(t('قفل الدفعة بيطلعها في السوق بالوزن الحالي.', 'Closing lists the batch on the market at its current weight.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('اقفل واعرض للبيع', 'Close and list for sale'), onTap: b.closed ? null : () {
          ref.read(employeeProvider.notifier).closeBatch(index);
          toast(context, t('اتقفلت واتعرضت للبيع', 'Closed and listed for sale'));
        }),
        const SizedBox(height: 10),
        BigButton(t('اطبع ملصق', 'Print label'), outlined: true, icon: Icons.print_rounded, onTap: () => _push(context, LabelPage(index))),
      ]),
    );
  }
}

class LabelPage extends ConsumerWidget {
  const LabelPage(this.index, {super.key});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final b = ref.watch(employeeProvider).batches[index];
    final m = mats[b.mat];
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('ملصق الدفعة', 'Batch label')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          color: Colors.white,
          child: Column(children: [
            QrImageView(data: b.code, size: 190),
            const SizedBox(height: 8),
            Text(b.code, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: const Color(0xFF0D2B22))),
            Text('${t(m.ar, m.en)} · ${fmt(b.kg)} ${t('كجم', 'kg')}', style: const TextStyle(color: Color(0xFF3E5A50))),
          ]),
        ),
        const SizedBox(height: 12),
        Text(t('الكود بيفتح تفاصيل الدفعة للمشتري.', 'The code opens batch details for the buyer.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('اطبع ملصق', 'Print label'), icon: Icons.print_rounded, onTap: () => toast(context, t('بنبعت للطابعة', 'Sending to printer'))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- stock, shift, history

class StockPage extends ConsumerWidget {
  const StockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(employeeProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('المخزون', 'Stock'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < st.batches.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EcoCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t(mats[i].ar, mats[i].en), style: Theme.of(context).textTheme.titleSmall)),
                  Text('${fmt(st.batches[i].kg)} ${t('كجم', 'kg')}', style: Theme.of(context).textTheme.titleMedium),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: st.batches[i].fill.clamp(0, 1), minHeight: 8, backgroundColor: c.surfaceAlt, color: c.primary)),
                const SizedBox(height: 4),
                Text(t('في الدفعة المفتوحة', 'in open batch'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
              ]),
            ).fadeUp(index: i),
          ),
        const SizedBox(height: 6),
        BigButton(t('ملخص الوردية', 'Shift summary'), outlined: true, onTap: () => _push(context, const ShiftPage())),
      ]),
    );
  }
}

class ShiftPage extends ConsumerWidget {
  const ShiftPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(employeeProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('ملخص الوردية', 'Shift summary')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Kpi(value: fmt(st.kgToday), label: t('كجم اتوزنت', 'kg weighed')),
          const SizedBox(width: 10),
          Kpi(value: '${st.count(ShipStatus.rejected)}', label: t('مرفوضة', 'rejected'), color: c.danger),
          const SizedBox(width: 10),
          Kpi(value: '${st.ledger}', label: t('حركات في السجل', 'ledger entries')),
        ]),
        const SizedBox(height: 14),
        Text(t('السجل بيتضاف له بس ومفيش تعديل أو مسح.', 'The ledger is append-only: no edits or deletes.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 20),
        BigButton(t('اقفل الوردية', 'Close shift'), onTap: st.shiftClosed ? null : () {
          ref.read(employeeProvider.notifier).closeShift();
          toast(context, t('اتقفلت الوردية', 'Shift closed'));
        }),
      ]),
    );
  }
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final ships = ref.watch(employeeProvider).ships;
    return Scaffold(
      appBar: RoleBar(title: t('السجل', 'History')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final s in ships)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Builder(builder: (context) {
              final (label, color) = _statusOf(t, context, s.status);
              return Row3(title: '${_who(t, s)} · #${s.id}', subtitle: '${fmt(totalKg(s.weights ?? s.est))} ${t('كجم', 'kg')}', trailing: Tag(label, color: color));
            }),
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- profile and help

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final user = ref.watch(sessionProvider).value;
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('حسابي', 'Profile'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(
          leading: CircleAvatar(radius: 24, backgroundColor: c.primary, child: Text(t('م', 'E'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          title: user?.name ?? t('موظف 1', 'Employee 1'),
          subtitle: t('موظف مخزن', 'Warehouse employee'),
        ),
        const SizedBox(height: 14),
        Row3(leading: const Icon(Icons.history_rounded), title: t('السجل', 'History'), onTap: () => _push(context, const HistoryPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.summarize_rounded), title: t('ملخص الوردية', 'Shift summary'), onTap: () => _push(context, const ShiftPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.help_outline_rounded), title: t('المساعدة', 'Help'), onTap: () => _push(context, const HelpPage())),
        const SizedBox(height: 20),
        BigButton(t('تسجيل خروج', 'Sign out'), outlined: true, icon: Icons.logout_rounded, onTap: ref.read(sessionProvider.notifier).logout),
      ]),
    );
  }
}

class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final qa = [
      (t('الوزن اتسجل غلط؟', 'Wrong weight saved?'), t('مفيش تعديل. بلّغ المشرف لعمل حركة تصحيح.', 'No edits. Tell the supervisor to post a correcting entry.')),
      (t('مفيش إنترنت؟', 'No connection?'), t('المسح بيشتغل والحفظ بيستنى الاتصال.', 'Scanning works and saving waits for connection.')),
      (t('خامة مش معروفة؟', 'Unknown material?'), t('ارفض الشحنة واختار مش مطابقة.', 'Reject and pick does-not-match.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('المساعدة', 'Help')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final q in qa) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: q.$1, subtitle: q.$2)),
      ]),
    );
  }
}
