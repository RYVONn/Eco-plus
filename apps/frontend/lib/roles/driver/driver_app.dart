import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session.dart';
import '../common/kit.dart';
import 'driver_logic.dart';

const _orange = EcoColors.driver;

final driverTabProvider = NotifierProvider<_TabNotifier, int>(_TabNotifier.new);

class _TabNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void open(int i) => state = i;
}

/// Driver: vehicle check, today's route, handover code, proof photo, and handing the bags to the warehouse.
class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) => Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _Tabs()));
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final i = ref.watch(driverTabProvider);
    return Scaffold(
      body: IndexedStack(index: i, children: const [RoutePage(), ShiftsPage(), WeekPage(), MePage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: ref.read(driverTabProvider.notifier).open,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.route_rounded), label: t('المسار', 'Route')),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: t('الورديات', 'Shifts')),
          NavigationDestination(icon: const Icon(Icons.bar_chart_rounded), label: t('يومي', 'Week')),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: t('حسابي', 'Profile')),
        ],
      ),
    );
  }
}

String _name(Tx t, Stop s) => t(s.nameAr, s.nameEn);

// ---------------------------------------------------------------- route and shift start

class RoutePage extends ConsumerWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final started = ref.watch(driverProvider.select((s) => s.started));
    return started ? const _RouteView() : const _ShiftStartView();
  }
}

class _ShiftStartView extends ConsumerWidget {
  const _ShiftStartView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    final c = context.eco;
    final checks = [
      t('الفرامل والكاوتش تمام', 'Brakes and tires OK'),
      t('البنزين كفاية', 'Fuel is enough'),
      t('أكياس وقفازات متوفرة', 'Bags and gloves available'),
      t('الموبايل والشاحن', 'Phone and charger'),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('بداية الوردية', 'Start shift'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(
          leading: const Icon(Icons.local_shipping_rounded, color: _orange),
          title: t('عربية 12', 'Van 12'),
          subtitle: t('المنطقة الشمالية · مثال', 'North zone · example'),
          trailing: Tag(t('متعيّنة', 'Assigned'), color: _orange),
        ).fadeUp(),
        SectionLabel(t('فحص العربية', 'Vehicle check')),
        for (var i = 0; i < checks.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              title: checks[i],
              leading: Icon(st.checks[i] ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: st.checks[i] ? _orange : c.inkSoft),
              onTap: () => ref.read(driverProvider.notifier).toggleCheck(i),
            ),
          ),
        const SizedBox(height: 12),
        BigButton(t('ابدأ الوردية', 'Start shift'), color: _orange, onTap: st.ready ? ref.read(driverProvider.notifier).start : null),
      ]),
    );
  }
}

class _RouteView extends ConsumerWidget {
  const _RouteView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    final c = context.eco;
    final total = st.stops.length;
    final denom = total == 0 ? 1 : total;
    final handled = total - st.count(StopStatus.todo);
    final done = st.count(StopStatus.done);
    return Scaffold(
      appBar: RoleBar(title: t('مسار النهارده', 'Today route'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Text('${t('خلصت', 'Completed')} $done/$total', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text('${(done / denom * 100).round()}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _orange)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: handled / denom, minHeight: 10, backgroundColor: c.surfaceAlt, color: _orange)),
        const SizedBox(height: 16),
        for (var i = 0; i < st.stops.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StopRow(i).fadeUp(index: i),
          ),
        const SizedBox(height: 8),
        BigButton(t('إنهاء الوردية', 'End shift'), color: _orange, onTap: st.allHandled ? () => pushPage(context, const SummaryPage()) : null),
      ]),
    );
  }
}

class _StopRow extends ConsumerWidget {
  const _StopRow(this.i);
  final int i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    final p = st.stops[i];
    final status = st.status[i];
    final isNext = i == st.nextIndex;
    final c = context.eco;
    final (label, color) = switch (status) {
      StopStatus.done => (t('اتقفلت', 'Closed'), c.primary),
      StopStatus.skipped => (t('اتأجّلت', 'Deferred'), c.inkSoft),
      StopStatus.todo => isNext ? (t('المحطة الجاية', 'Next stop'), _orange) : ('—', c.inkSoft),
    };
    return Row3(
      leading: CircleAvatar(backgroundColor: isNext ? _orange : c.surfaceAlt, child: Text('${i + 1}', style: TextStyle(color: isNext ? Colors.white : c.ink, fontWeight: FontWeight.w700))),
      title: _name(t, p),
      subtitle: '${t(p.addrAr, p.addrEn)} · ${p.bags} ${t('أكياس', 'bags')}',
      trailing: Tag(label, color: color),
      onTap: status == StopStatus.todo ? () => pushPage(context, StopPage(i)) : null,
    );
  }
}

// ---------------------------------------------------------------- stop, code, proof, skip

class StopPage extends ConsumerWidget {
  const StopPage(this.i, {super.key});
  final int i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final p = ref.watch(driverProvider).stops[i];
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: '${t('محطة', 'Stop')} ${i + 1}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(_name(t, p), style: Theme.of(context).textTheme.headlineSmall),
        Text(t(p.addrAr, p.addrEn), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 14),
        Row(children: [
          Kpi(value: '${p.bags}', label: t('أكياس', 'bags')),
          const SizedBox(width: 10),
          Kpi(value: p.eta, label: t('وصول', 'ETA')),
          const SizedBox(width: 10),
          Kpi(value: '${p.kg.round()}', label: t('كجم تقدير', 'est. kg')),
        ]),
        SectionLabel(t('ملاحظات', 'Notes')),
        EcoCard(child: Text(t(p.noteAr, p.noteEn))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: BigButton(t('افتح الملاحة', 'Open navigation'), outlined: true, icon: Icons.navigation_rounded, onTap: () => toast(context, t('بنفتح الملاحة', 'Opening navigation')))),
          const SizedBox(width: 10),
          Expanded(child: BigButton(t('اتصل بالعميل', 'Call customer'), outlined: true, icon: Icons.call_rounded, onTap: () => toast(context, t('بنتصل بالعميل', 'Calling customer')))),
        ]),
        const SizedBox(height: 12),
        BigButton(t('وصلت · اطلب الكود', 'Arrived · enter code'), color: _orange, onTap: () => pushPage(context, CodePage(i))),
        const SizedBox(height: 10),
        BigButton(t('مفيش حد / مفيش أكياس', 'Nobody / no bags'), outlined: true, danger: true, onTap: () => pushPage(context, SkipPage(i))),
      ]),
    );
  }
}

class CodePage extends ConsumerStatefulWidget {
  const CodePage(this.i, {super.key});
  final int i;

  @override
  ConsumerState<CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<CodePage> {
  final _code = TextEditingController();
  bool _bad = false;
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final sessionUser = ref.watch(sessionProvider).value;
    final preview = sessionUser == null || sessionUser.isDemo;
    return Scaffold(
      appBar: RoleBar(title: t('كود التسليم', 'Handover code')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('العميل بيديك الكود 4 أرقام. اكتبه هنا. الكود مش بيظهر عندك.', 'The customer gives you a 4 digit code. You never see it in the app.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 20),
        TextField(
          controller: _code,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: preview ? 4 : 6,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 12),
          onChanged: (_) => setState(() {
            _bad = false;
            _err = null;
          }),
          decoration: InputDecoration(counterText: '', errorText: _err ?? (_bad ? t('الكود غلط. اطلب من العميل يراجعه.', 'Wrong code. Ask the customer to check.') : null)),
        ),
        if (preview) Padding(padding: const EdgeInsets.only(top: 8), child: Text(t('للتجربة: $demoHandoverCode', 'For the demo: $demoHandoverCode'), textAlign: TextAlign.center, style: TextStyle(color: c.inkSoft))),
        const SizedBox(height: 20),
        BigButton(t('تأكيد الكود', 'Verify code'), color: _orange, onTap: _busy || _code.text.length < (preview ? 4 : 6) ? null : () async {
          if (preview) {
            if (_code.text == demoHandoverCode) {
              replacePage(context, ProofPage(widget.i));
            } else {
              setState(() => _bad = true);
            }
            return;
          }
          setState(() => _busy = true);
          final err = await ref.read(driverProvider.notifier).collect(widget.i, _code.text);
          if (!mounted) return;
          setState(() {
            _busy = false;
            _err = err;
          });
          if (err == null && context.mounted) replacePage(context, ProofPage(widget.i));
        }),
      ]),
    );
  }
}

class ProofPage extends ConsumerStatefulWidget {
  const ProofPage(this.i, {super.key});
  final int i;

  @override
  ConsumerState<ProofPage> createState() => _ProofPageState();
}

class _ProofPageState extends ConsumerState<ProofPage> {
  late int _bags = ref.read(driverProvider).stops[widget.i].bags;
  bool _photo = false;

  Future<void> _takePhoto() async {
    final n = ref.read(driverProvider.notifier);
    if (!n.isReal) {
      setState(() => _photo = true);
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 82);
    if (file == null) return;
    final err = await n.sendProof(widget.i, await file.readAsBytes(), file.name.isEmpty ? 'proof.jpg' : file.name);
    if (!mounted) return;
    if (err != null) {
      toast(context, err);
      return;
    }
    setState(() => _photo = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('إثبات الاستلام', 'Proof of pickup')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('صوّر الأكياس قبل ما تحمّلها.', 'Photograph the bags before loading.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 14),
        PhotoSlot(taken: _photo, onTap: _takePhoto, takeLabel: t('اضغط للتصوير', 'Tap to take photo'), doneLabel: t('اتصوّرت الأكياس', 'Photo captured')),
        SectionLabel(t('عدد الأكياس', 'Bag count')),
        Center(child: StepperField(value: _bags.toDouble(), min: 1, onChanged: (v) => setState(() => _bags = v.round()))),
        const SizedBox(height: 20),
        BigButton(t('أكّد الاستلام', 'Confirm pickup'), color: _orange, onTap: _photo ? () {
          ref.read(driverProvider.notifier).complete(widget.i, _bags);
          toast(context, t('اتأكد الاستلام', 'Pickup confirmed'));
          replacePage(context, StopDonePage(widget.i));
        } : null),
      ]),
    );
  }
}

class StopDonePage extends ConsumerWidget {
  const StopDonePage(this.i, {super.key});
  final int i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final allDone = ref.watch(driverProvider.select((s) => s.allHandled));
    final c = context.eco;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 96, height: 96, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 52, color: _orange)).fadeUp(),
            const SizedBox(height: 20),
            Text(t('اتسجّل الاستلام', 'Pickup recorded'), style: Theme.of(context).textTheme.headlineSmall).fadeUp(index: 1),
            const SizedBox(height: 8),
            Text(t('العميل هيتبلّغ.', 'The customer will be notified.'), style: TextStyle(color: c.inkSoft)).fadeUp(index: 2),
            const SizedBox(height: 32),
            BigButton(allDone ? t('إنهاء الوردية', 'End shift') : t('رجوع للمسار', 'Back to route'), color: _orange, onTap: () {
              final nav = Navigator.of(context);
              nav.popUntil((r) => r.isFirst);
              if (allDone) nav.push(MaterialPageRoute<void>(builder: (_) => const SummaryPage()));
            }),
          ]),
        ),
      ),
    );
  }
}

class SkipPage extends ConsumerStatefulWidget {
  const SkipPage(this.i, {super.key});
  final int i;

  @override
  ConsumerState<SkipPage> createState() => _SkipPageState();
}

class _SkipPageState extends ConsumerState<SkipPage> {
  int _reason = -1;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final reasons = [t('مفيش حد', 'Nobody home'), t('مفيش أكياس', 'No bags'), t('الكيس مش مطابق', 'Bag does not match'), t('العميل طلب التأجيل', 'Customer postponed')];
    return Scaffold(
      appBar: RoleBar(title: t('مفيش حد / مفيش أكياس', 'Nobody / no bags')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var k = 0; k < reasons.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              title: reasons[k],
              leading: Icon(_reason == k ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _reason == k ? _orange : c.inkSoft),
              onTap: () => setState(() => _reason = k),
            ),
          ),
        const SizedBox(height: 12),
        BigButton(t('أكّد وبلّغ', 'Confirm and report'), color: _orange, onTap: _reason < 0 ? null : () {
          ref.read(driverProvider.notifier).skip(widget.i);
          toast(context, t('اتبلّغ الأدمن', 'Admin notified'));
          popToRoot(context);
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- end of shift

class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    return Scaffold(
      appBar: RoleBar(title: t('ملخص الوردية', 'Shift summary')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Kpi(value: '${st.count(StopStatus.done)}', label: t('محطة', 'stops')),
          const SizedBox(width: 10),
          Kpi(value: '${st.bagsCollected}', label: t('أكياس', 'bags')),
          const SizedBox(width: 10),
          Kpi(value: '${st.count(StopStatus.skipped)}', label: t('محطات اتأجلت', 'Deferred stops'), color: context.eco.amber),
        ]),
        const SizedBox(height: 14),
        Text(t('سلّم الأكياس للمخزن للوزن.', 'Hand the bags to the warehouse for weighing.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 20),
        BigButton(t('سلّم للمخزن', 'Hand over to warehouse'), color: _orange, onTap: () => pushPage(context, const HandoverPage())),
      ]),
    );
  }
}

class HandoverPage extends ConsumerWidget {
  const HandoverPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('التسليم للمخزن', 'Warehouse handover')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('خلّي موظف المخزن يمسح الكود ويعدّ الأكياس معاك ويصوّرها.', 'Let the warehouse employee scan this code, count the bags with you and photograph them.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 16),
        EcoCard(
          child: Column(children: [
            const Icon(Icons.qr_code_2_rounded, size: 140, color: Color(0xFF0D2B22)),
            const SizedBox(height: 8),
            Text('${st.bagsCollected} ${t('أكياس', 'bags')}', style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
        const SizedBox(height: 14),
        Center(child: Tag(st.warehouseOk ? t('الموظف استلم وصوّر', 'Employee received and photographed') : t('مستني تأكيد الموظف', 'Waiting for employee'), color: st.warehouseOk ? c.primary : c.amber)),
        const SizedBox(height: 14),
        if (!st.warehouseOk) BigButton(t('الموظف أكّد (تجربة)', 'Employee confirmed (demo)'), outlined: true, onTap: ref.read(driverProvider.notifier).confirmWarehouse),
        const SizedBox(height: 10),
        BigButton(t('اقفل الوردية', 'Close shift'), color: _orange, onTap: st.warehouseOk ? () {
          ref.read(driverProvider.notifier).finishShift();
          toast(context, t('اتقفلت الوردية', 'Shift closed'));
          ref.read(driverTabProvider.notifier).open(1);
          popToRoot(context);
        } : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------- shifts, week, profile

class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final rows = [
      (t('امبارح', 'Yesterday'), 9, 21),
      (t('الإثنين', 'Monday'), 11, 26),
      (t('الأحد', 'Sunday'), 8, 17),
      (t('السبت', 'Saturday'), 10, 22),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('ورديّاتي', 'My shifts'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(title: r.$1, subtitle: '${r.$2} ${t('محطة', 'stops')} · ${r.$3} ${t('أكياس', 'bags')}', trailing: Tag(t('اتقفلت', 'Closed'))),
          ),
      ]),
    );
  }
}

class WeekPage extends ConsumerWidget {
  const WeekPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(driverProvider);
    final c = context.eco;
    final done = st.count(StopStatus.done);
    final values = [9, 11, 8, 10, 12, done + 6];
    final days = t.ar ? ['س', 'ح', 'ن', 'ث', 'ر', 'خ'] : ['Sa', 'Su', 'Mo', 'Tu', 'We', 'Th'];
    return Scaffold(
      appBar: RoleBar(title: t('يومي', 'My week'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('الأسبوع ده', 'This week'), style: TextStyle(color: c.inkSoft)),
            Text('${50 + done} ${t('محطة', 'stops')}', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: _orange)),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        AnimatedContainer(duration: Motion.slow, curve: Motion.curve, height: values[i] / 14 * 96, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8))),
                        const SizedBox(height: 4),
                        Text(days[i], style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(t('أجر السواق لسه هيتحدد. الأرقام هنا عدد المحطات بس.', 'Driver pay is still to be defined. Numbers show stop counts only.'), style: TextStyle(color: c.inkSoft)),
      ]),
    );
  }
}

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final user = ref.watch(sessionProvider).value;
    return Scaffold(
      appBar: RoleBar(title: t('حسابي', 'Profile'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(
          leading: CircleAvatar(radius: 24, backgroundColor: _orange, child: Text(t('س', 'D'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          title: user?.name ?? t('السواق 1', 'Driver 1'),
          subtitle: t('سواق', 'Driver'),
        ),
        const SizedBox(height: 14),
        Row3(leading: const Icon(Icons.local_shipping_rounded), title: t('العربية والمستندات', 'Vehicle and documents'), onTap: () => pushPage(context, const VehiclePage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.notifications_rounded), title: t('التنبيهات', 'Notifications'), onTap: () => pushPage(context, const NotifsPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.help_outline_rounded), title: t('المساعدة', 'Help'), onTap: () => pushPage(context, const HelpPage())),
        const SizedBox(height: 20),
        BigButton(t('تسجيل خروج', 'Sign out'), outlined: true, icon: Icons.logout_rounded, onTap: ref.read(sessionProvider.notifier).logout),
      ]),
    );
  }
}

class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final docs = [
      (t('رخصة القيادة', 'Driver license'), t('سارية لحد 2027', 'Valid until 2027'), true),
      (t('رخصة العربية', 'Vehicle license'), t('سارية لحد 2026', 'Valid until 2026'), true),
      (t('التأمين', 'Insurance'), t('ينتهي قريب', 'Expiring soon'), false),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('العربية والمستندات', 'Vehicle and documents')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final d in docs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(title: d.$1, subtitle: d.$2, trailing: Tag(d.$3 ? t('سليم', 'OK') : t('محتاج تجديد', 'Renew'), color: d.$3 ? context.eco.primary : context.eco.amber)),
          ),
      ]),
    );
  }
}

class NotifsPage extends ConsumerWidget {
  const NotifsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final prefs = ref.watch(driverProvider.select((s) => s.prefs));
    final labels = [t('مسار جديد', 'New route'), t('تغيير في الاستلام', 'Pickup changes'), t('رسائل الدعم', 'Support messages')];
    return Scaffold(
      appBar: RoleBar(title: t('التنبيهات', 'Notifications')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(title: labels[i], trailing: Switch(value: prefs[i], activeThumbColor: _orange, onChanged: (_) => ref.read(driverProvider.notifier).togglePref(i))),
          ),
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
      (t('العميل مش عارف الكود؟', 'Customer does not know the code?'), t('اطلب منه يفتح شاشة الشحنة في تطبيقه.', 'Ask them to open the shipment screen in their app.')),
      (t('الكود بيطلع غلط؟', 'Code keeps failing?'), t('بعد 3 محاولات بلّغ الدعم.', 'After 3 tries contact support.')),
      (t('فيه كيس مش مطابق؟', 'A bag does not match?'), t('اختار عدم المطابقة وصوّره.', 'Choose does-not-match and photograph it.')),
      (t('العربية فيها مشكلة؟', 'Vehicle problem?'), t('بلّغ الدعم قبل ما تكمل.', 'Tell support before continuing.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('المساعدة', 'Help')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final q in qa) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: q.$1, subtitle: q.$2)),
        const SizedBox(height: 12),
        BigButton(t('اتصل بالدعم', 'Call support'), icon: Icons.call_rounded, color: _orange, onTap: () => toast(context, t('بنتصل بالدعم', 'Calling support'))),
      ]),
    );
  }
}
