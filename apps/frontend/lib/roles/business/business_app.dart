import 'dart:async';

import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../features/citizen/scan_screen.dart';
import '../common/kit.dart';
import 'business_logic.dart';

final bizTabProvider = NotifierProvider<_IntNotifier, int>(_IntNotifier.new);
final bizOnboardedProvider = NotifierProvider<_BoolNotifier, bool>(_BoolNotifier.new);
final _sellProvider = NotifierProvider<_SellNotifier, _Sell>(_SellNotifier.new);

class _IntNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void open(int i) => state = i;
}

class _BoolNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void done() => state = true;
}

/// What the seller is building in the sell flow. Reset after a request is placed.
class _Sell {
  const _Sell({this.qty = const [0, 0, 0, 0], this.reward = Reward.cash, this.photo = false, this.branch = 0, this.recurring = false, this.days = const [false, false, false, false, false, false, false], this.win = 2});
  final List<double> qty;
  final Reward reward;
  final bool photo;
  final int branch;
  final bool recurring;
  final List<bool> days;
  final int win;
  double get kg => qty.fold(0.0, (a, b) => a + b);

  _Sell copy({List<double>? qty, Reward? reward, bool? photo, int? branch, bool? recurring, List<bool>? days, int? win}) =>
      _Sell(qty: qty ?? this.qty, reward: reward ?? this.reward, photo: photo ?? this.photo, branch: branch ?? this.branch, recurring: recurring ?? this.recurring, days: days ?? this.days, win: win ?? this.win);
}

class _SellNotifier extends Notifier<_Sell> {
  @override
  _Sell build() => const _Sell();
  void set(_Sell s) => state = s;
  void reset() => state = const _Sell();
}

/// Business seller (café, restaurant, shop, factory scrap): photograph, choose cash or points, book pickups, wallet and invoices.
class BusinessApp extends ConsumerWidget {
  const BusinessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(bizOnboardedProvider);
    return Navigator(
      key: ValueKey(onboarded),
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => onboarded ? const _Tabs() : const _SignupPage()),
    );
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final i = ref.watch(bizTabProvider);
    return Scaffold(
      body: IndexedStack(index: i, children: const [_HomePage(), _PickupsPage(), _WalletPage(), _MorePage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: ref.read(bizTabProvider.notifier).open,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: t('الرئيسية', 'Home')),
          NavigationDestination(icon: const Icon(Icons.local_shipping_rounded), label: t('الاستلامات', 'Pickups')),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet_rounded), label: t('المحفظة', 'Wallet')),
          NavigationDestination(icon: const Icon(Icons.menu_rounded), label: t('المزيد', 'More')),
        ],
      ),
    );
  }
}

String _bizName(Tx t, BizState s) => s.name.trim().isEmpty ? t('الكافيه المثال', 'Example Café') : s.name.trim();
String _egp(Tx t, num v) => '${fmt(v)} ${t('جنيه', 'EGP')}';
String _kg(Tx t, num v) => '${fmt(v)} ${t('كجم', 'kg')}';
String _stage(Tx t, int s) => [t('اتجدولت', 'Scheduled'), t('السواق متعيّن', 'Driver assigned'), t('اتجمّعت', 'Collected'), t('اتوزنت', 'Weighed')][s];
String _matName(Tx t, int i) => t(bMats[i].ar, bMats[i].en);

// ---------------------------------------------------------------- sign up

class _SignupPage extends ConsumerStatefulWidget {
  const _SignupPage();

  @override
  ConsumerState<_SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<_SignupPage> {
  final _name = TextEditingController();
  int _type = 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final types = [t('كافيه', 'Café'), t('مطعم', 'Restaurant'), t('مصنع', 'Factory'), t('محل', 'Shop')];
    return Scaffold(
      appBar: RoleBar(title: t('افتح حساب البيزنس', 'Open a business account'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('بيع الخامات اللي بتطلع من شغلك وإحنا نيجي نستلمها.', 'Sell the materials your business produces and we come to collect.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        TextField(controller: _name, decoration: InputDecoration(labelText: t('اسم المكان', 'Business name'))),
        const SizedBox(height: 12),
        TextField(keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: t('رقم الموبايل', 'Mobile number'))),
        SectionLabel(t('نوع النشاط', 'Business type')),
        Wrap(spacing: 8, children: [for (var i = 0; i < types.length; i++) ChoiceChip(label: Text(types[i]), selected: _type == i, onSelected: (_) => setState(() => _type = i))]),
        const SizedBox(height: 20),
        BigButton(t('التالي', 'Next'), onTap: () {
          ref.read(businessProvider.notifier).signup(_name.text, _type);
          pushPage(context, const _BranchSetupPage());
        }),
      ]),
    );
  }
}

class _BranchSetupPage extends ConsumerWidget {
  const _BranchSetupPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('أول فرع', 'First branch')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('ده المكان اللي السواق هيستلم منه.', 'This is where the driver will collect from.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        TextField(decoration: InputDecoration(labelText: t('اسم الفرع', 'Branch name'))),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: t('العنوان', 'Address'))),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: t('اسم المسؤول عن التسليم', 'Handover contact'))),
        const SizedBox(height: 10),
        Text(t('هتحدد الموقع على الخريطة بعد الإنشاء.', 'You will pin the location on the map after setup.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 20),
        BigButton(t('التالي', 'Next'), onTap: () => pushPage(context, const _AgreementPage())),
      ]),
    );
  }
}

class _AgreementPage extends ConsumerStatefulWidget {
  const _AgreementPage();

  @override
  ConsumerState<_AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends ConsumerState<_AgreementPage> {
  bool _ok = false;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final rows = [
      t('الخامات المقبولة وشروط النضافة موضحة في شاشة الأسعار.', 'Accepted materials and cleanliness rules are listed on the prices screen.'),
      t('الدفع بحسب الوزن الفعلي بعد الوزن عندنا، مش التقدير.', 'Payment follows the weight we measure, not your estimate.'),
      t('الأسعار بتتغير وبتتأكد وقت الوزن.', 'Prices change and are confirmed at weighing.'),
      t('ممكن تلغي أي استلام قبل وصول السواق.', 'You can cancel a pickup any time before the driver arrives.'),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('اتفاقية البيع', 'Selling agreement')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(Icons.check_rounded, color: context.eco.primary), title: r)),
        const SizedBox(height: 8),
        Text(t('نص الاتفاقية نموذج للتصميم ولسه محتاج مراجعة قانونية.', 'Agreement text is a design sample and still needs legal review.'), style: TextStyle(color: context.eco.inkSoft)),
        const SizedBox(height: 12),
        CheckboxListTile(contentPadding: EdgeInsets.zero, value: _ok, onChanged: (v) => setState(() => _ok = v ?? false), title: Text(t('قريت الاتفاقية وموافق', 'I read and accept the agreement'))),
        const SizedBox(height: 8),
        BigButton(t('ابدأ', 'Get started'), onTap: _ok ? ref.read(bizOnboardedProvider.notifier).done : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------- home and pickups

class _HomePage extends ConsumerWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final c = context.eco;
    final next = s.next;
    return Scaffold(
      appBar: RoleBar(title: '${t('أهلاً', 'Welcome')}، ${_bizName(t, s)}', back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('الرصيد', 'Balance'), style: const TextStyle(color: EcoColors.onCanopy)),
            AnimatedSwitcher(duration: Motion.base, child: Text(_egp(t, s.balance), key: ValueKey(s.balance), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EcoColors.bloom))),
            const SizedBox(height: 4),
            Text('${t('قيد الوزن', 'Pending')}: ${_egp(t, s.pending)}', style: const TextStyle(color: EcoColors.onCanopy)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: FilledButton(onPressed: () => pushPage(context, const _ScanPage()), style: FilledButton.styleFrom(backgroundColor: EcoColors.bloom, foregroundColor: const Color(0xFF0D2B22)), child: Text(t('بيع', 'Sell')))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => pushPage(context, const _PricesPage()), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), child: Text(t('الأسعار', 'Prices')))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => pushPage(context, const _InvoicesPage()), style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), child: Text(t('الفواتير', 'Invoices')))),
            ]),
          ]),
        ).fadeUp(),
        const SizedBox(height: 12),
        Row(children: [Kpi(value: fmt(136 + s.weighedKg), label: t('كجم اتحولت', 'kg recycled')), const SizedBox(width: 10), Kpi(value: '${6 + s.pickups.where((p) => p.done).length}', label: t('استلام اتوزن', 'pickups weighed'))]).fadeUp(index: 1),
        SectionLabel(t('الاستلام الجاي', 'Next pickup')),
        if (next == null)
          EcoCard(child: Text(t('مفيش استلامات جاية. اضغط بيع.', 'No upcoming pickups. Tap Sell.')))
        else
          Row3(leading: Icon(Icons.local_shipping_rounded, color: c.primary), title: '#${next.id} · ${t(next.whenAr, next.whenEn)}', subtitle: '${t(s.branches[next.branch].ar, s.branches[next.branch].en)} · ${_kg(t, next.kg)}', trailing: Tag(_stage(t, next.stage)), onTap: () => pushPage(context, _PickupDetailPage(next.id))),
        SectionLabel(t('أسعار النهارده', 'Today prices')),
        SizedBox(
          height: 92,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final m in bMats)
              Container(
                width: 120,
                margin: const EdgeInsetsDirectional.only(end: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(16)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t(m.ar, m.en), style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700)), Text('${fmt(m.price)} ${t('جنيه', 'EGP')}', style: const TextStyle(color: Color(0xFF3E5A50)))]),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(t('الأسعار أمثلة للتصميم ولسه هتتحدد.', 'Prices are design examples and will be set later.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
      ]),
    );
  }
}

class _PickupsPage extends ConsumerStatefulWidget {
  const _PickupsPage();

  @override
  ConsumerState<_PickupsPage> createState() => _PickupsPageState();
}

class _PickupsPageState extends ConsumerState<_PickupsPage> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final list = s.pickups.where((p) => _upcoming != p.done).toList();
    return Scaffold(
      appBar: RoleBar(title: t('الاستلامات', 'Pickups'), back: false, actions: [IconButton(icon: const Icon(Icons.repeat_rounded), tooltip: t('متكرر', 'Recurring'), onPressed: () => pushPage(context, const _RecurringPage()))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: true, label: Text(t('جاية', 'Upcoming'))), ButtonSegment(value: false, label: Text(t('سابقة', 'Past')))],
          selected: {_upcoming},
          onSelectionChanged: (v) => setState(() => _upcoming = v.first),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty) EmptyState(icon: Icons.inbox_rounded, title: t('مفيش حاجة هنا.', 'Nothing here.'), body: ''),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(title: '#${p.id} · ${t(p.whenAr, p.whenEn)}', subtitle: '${t(s.branches[p.branch].ar, s.branches[p.branch].en)} · ${_kg(t, p.kg)}', trailing: Tag(_stage(t, p.stage), color: p.done ? context.eco.primary : context.eco.amber), onTap: () => pushPage(context, _PickupDetailPage(p.id))),
          ),
        const SizedBox(height: 8),
        BigButton(t('بيع', 'Sell'), icon: Icons.add_rounded, onTap: () => pushPage(context, const _ScanPage())),
      ]),
    );
  }
}

// ---------------------------------------------------------------- scan and sell flow

class _ScanPage extends ConsumerWidget {
  const _ScanPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('صوّر الخامات', 'Photograph materials')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(28)),
              child: Center(child: Container(width: 220, height: 280, decoration: BoxDecoration(border: Border.all(color: EcoColors.bloom, width: 3), borderRadius: BorderRadius.circular(28)))),
            ),
          ),
          const SizedBox(height: 12),
          Text(t('حط الخامات في الإطار وثبّت إيدك.', 'Place the materials in the frame and hold steady.'), style: TextStyle(color: c.inkSoft)),
          const SizedBox(height: 12),
          BigButton(t('صوّر', 'Capture'), icon: Icons.photo_camera_rounded, onTap: () => pushPage(context, const _AnalyzingPage())),
          const SizedBox(height: 8),
          BigButton(t('أدخل الكميات يدوي', 'Enter quantities manually'), outlined: true, onTap: () {
            ref.read(_sellProvider.notifier).reset();
            pushPage(context, const _Sell1Page());
          }),
        ]),
      ),
    );
  }
}

class _AnalyzingPage extends ConsumerStatefulWidget {
  const _AnalyzingPage();

  @override
  ConsumerState<_AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends ConsumerState<_AnalyzingPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      ref.read(_sellProvider.notifier).set(const _Sell(qty: [6, 0, 4, 0], photo: true));
      replacePage(context, const _Sell1Page());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 56, height: 56, child: CircularProgressIndicator()),
          const SizedBox(height: 18),
          Text(t('بنحلل الصورة…', 'Analyzing the photo…'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(t('التقدير مبدئي، والوزن الفعلي هو اللي بيتحاسب.', 'This is an estimate; the weighed amount is what counts.'), style: TextStyle(color: context.eco.inkSoft)),
        ]),
      ),
    );
  }
}

class _Sell1Page extends ConsumerWidget {
  const _Sell1Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(_sellProvider);
    final n = ref.read(_sellProvider.notifier);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('الخامات (1/4)', 'Materials (1/4)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < bMats.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EcoCard(
              child: Row(children: [
                Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: bMats[i].color, borderRadius: BorderRadius.circular(12)), child: Text(bMats[i].code, style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_matName(t, i), style: Theme.of(context).textTheme.titleSmall), Text('${fmt(bMats[i].price)} ${t('جنيه/كجم', 'EGP/kg')}', style: TextStyle(color: c.inkSoft))])),
                StepperField(value: s.qty[i], step: 0.5, max: 500, onChanged: (v) => n.set(s.copy(qty: [for (var k = 0; k < 4; k++) k == i ? v : s.qty[k]]))),
              ]),
            ),
          ),
        SectionLabel(t('تاخد إيه؟', 'What do you want?')),
        Row(children: [
          for (final r in Reward.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: SizedBox(width: double.infinity, child: Text(r == Reward.cash ? t('فلوس', 'Cash') : t('نقاط', 'Points'), textAlign: TextAlign.center)),
                  selected: s.reward == r,
                  onSelected: (_) => n.set(s.copy(reward: r)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        EcoCard(
          color: EcoColors.bloom,
          child: Text(
            s.reward == Reward.cash ? '${t('تقدير', 'Estimate')}: ${_egp(t, estimate(s.qty))}' : '${t('تقدير', 'Estimate')}: ${fmt(pointsOf(s.qty))} ${t('نقطة', 'pts')}',
            style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 6),
        Text(t('الدفع الفعلي بعد الوزن عندنا.', 'You are paid after we weigh.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('التالي', 'Next'), onTap: s.kg > 0 ? () => pushPage(context, const _Sell2Page()) : null),
      ]),
    );
  }
}

class _Sell2Page extends ConsumerWidget {
  const _Sell2Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(_sellProvider);
    final b = ref.watch(businessProvider);
    final n = ref.read(_sellProvider.notifier);
    return Scaffold(
      appBar: RoleBar(title: t('الصورة والفرع (2/4)', 'Photo and branch (2/4)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PhotoSlot(taken: s.photo, onTap: () => n.set(s.copy(photo: true)), takeLabel: t('صوّر الخامات', 'Photograph materials'), doneLabel: t('الصورة اتسجلت', 'Photo captured')),
        const SizedBox(height: 12),
        TextField(maxLines: 2, decoration: InputDecoration(labelText: t('ملاحظة للسواق (اختياري)', 'Note for the driver (optional)'))),
        SectionLabel(t('الفرع', 'Branch')),
        for (var i = 0; i < b.branches.length; i++)
          if (b.branches[i].on)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row3(
                leading: Icon(s.branch == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: context.eco.primary),
                title: t(b.branches[i].ar, b.branches[i].en),
                subtitle: t(b.branches[i].addrAr, b.branches[i].addrEn),
                onTap: () => n.set(s.copy(branch: i)),
              ),
            ),
        const SizedBox(height: 12),
        BigButton(t('التالي', 'Next'), onTap: s.photo ? () => pushPage(context, const _Sell3Page()) : null),
      ]),
    );
  }
}

class _Sell3Page extends ConsumerWidget {
  const _Sell3Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(_sellProvider);
    final n = ref.read(_sellProvider.notifier);
    final days = [t('سبت', 'Sat'), t('أحد', 'Sun'), t('اتنين', 'Mon'), t('تلات', 'Tue'), t('أربع', 'Wed'), t('خميس', 'Thu'), t('جمعة', 'Fri')];
    final wins = [t('9 ص – 12 م', '9 AM – 12 PM'), t('12 – 4 م', '12 – 4 PM'), t('4 – 8 م', '4 – 8 PM')];
    return Scaffold(
      appBar: RoleBar(title: t('الميعاد (3/4)', 'Schedule (3/4)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: false, label: Text(t('مرة واحدة', 'Once'))), ButtonSegment(value: true, label: Text(t('متكرر', 'Recurring')))],
          selected: {s.recurring},
          onSelectionChanged: (v) => n.set(s.copy(recurring: v.first)),
        ),
        if (s.recurring) ...[
          SectionLabel(t('الأيام', 'Days')),
          Wrap(spacing: 8, children: [for (var i = 0; i < 7; i++) FilterChip(label: Text(days[i]), selected: s.days[i], onSelected: (v) => n.set(s.copy(days: [for (var k = 0; k < 7; k++) k == i ? v : s.days[k]])))]),
        ],
        SectionLabel(t('الفترة', 'Time window')),
        for (var i = 0; i < wins.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: Icon(s.win == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: context.eco.primary), title: wins[i], onTap: () => n.set(s.copy(win: i))),
          ),
        const SizedBox(height: 12),
        BigButton(t('التالي', 'Next'), onTap: () => pushPage(context, const _Sell4Page())),
      ]),
    );
  }
}

class _Sell4Page extends ConsumerWidget {
  const _Sell4Page();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(_sellProvider);
    final b = ref.watch(businessProvider);
    final wins = [(t('9 ص – 12 م', '9 AM – 12 PM')), t('12 – 4 م', '12 – 4 PM'), t('4 – 8 م', '4 – 8 PM')];
    return Scaffold(
      appBar: RoleBar(title: t('المراجعة (4/4)', 'Review (4/4)')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < bMats.length; i++)
              if (s.qty[i] > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(_matName(t, i))), Text(_kg(t, s.qty[i]))])),
            const Divider(),
            Row(children: [Expanded(child: Text(t('الإجمالي', 'Total'))), Text(_kg(t, s.kg), style: Theme.of(context).textTheme.titleMedium)]),
          ]),
        ),
        const SizedBox(height: 8),
        Row3(title: t(b.branches[s.branch].ar, b.branches[s.branch].en), subtitle: '${wins[s.win]} · ${s.recurring ? t('متكرر', 'Recurring') : t('مرة واحدة', 'Once')}'),
        const SizedBox(height: 8),
        EcoCard(color: EcoColors.bloom, child: Text(s.reward == Reward.cash ? '${t('تقدير', 'Estimate')}: ${_egp(t, estimate(s.qty))}' : '${t('تقدير', 'Estimate')}: ${fmt(pointsOf(s.qty))} ${t('نقطة', 'pts')}', style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700))),
        const SizedBox(height: 6),
        Text(t('الدفع الفعلي بعد الوزن.', 'Actual payment after weighing.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('اطلب الاستلام', 'Request pickup'), onTap: () async {
          final n = ref.read(businessProvider.notifier);
          if (n.isReal) {
            await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => ScanScreen(reward: s.reward == Reward.cash ? 'cash' : 'points')));
            await n.refresh();
            if (!context.mounted) return;
            ref.read(_sellProvider.notifier).reset();
            Navigator.of(context).popUntil((r) => r.isFirst);
            return;
          }
          final id = n.createPickup(items: s.qty, branch: s.branch, whenAr: 'بكرة ${wins[s.win]}', whenEn: 'Tomorrow ${wins[s.win]}', reward: s.reward);
          ref.read(_sellProvider.notifier).reset();
          replacePage(context, _SellDonePage(id));
        }),
      ]),
    );
  }
}

class _SellDonePage extends ConsumerWidget {
  const _SellDonePage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_rounded, size: 84, color: context.eco.primary).fadeUp(),
            const SizedBox(height: 16),
            Text(t('الطلب اتسجل', 'Request placed'), style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text('#$id', style: TextStyle(color: context.eco.inkSoft)),
            const SizedBox(height: 24),
            BigButton(t('تابع الاستلام', 'Track pickup'), onTap: () => replacePage(context, _PickupDetailPage(id))),
            const SizedBox(height: 8),
            BigButton(t('الرئيسية', 'Home'), outlined: true, onTap: () => popToRoot(context)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- pickup detail and receipt

class _PickupDetailPage extends ConsumerWidget {
  const _PickupDetailPage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final c = context.eco;
    final p = s.pickups.firstWhere((x) => x.id == id);
    final steps = [t('اتجدولت', 'Scheduled'), t('السواق متعيّن', 'Driver assigned'), t('اتجمّعت', 'Collected'), t('اتوزنت', 'Weighed')];
    return Scaffold(
      appBar: RoleBar(title: '${t('استلام', 'Pickup')} #${p.id}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(title: t(p.whenAr, p.whenEn), subtitle: t(s.branches[p.branch].ar, s.branches[p.branch].en), trailing: Tag(steps[p.stage])),
        SectionLabel(t('المراحل', 'Progress')),
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Icon(i <= p.stage ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i <= p.stage ? c.primary : c.inkSoft),
              const SizedBox(width: 10),
              Text(steps[i], style: TextStyle(fontWeight: i == p.stage ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
        if (!p.done && p.stage >= 1) ...[
          SectionLabel(t('كود التسليم', 'Handover code')),
          EcoCard(child: Center(child: Text('4821', style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 6, color: c.primary)))),
          const SizedBox(height: 4),
          Text(t('اديه للسواق وقت الاستلام بس.', 'Give it to the driver at pickup only.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
        ],
        SectionLabel(t('الخامات', 'Items')),
        for (var i = 0; i < bMats.length; i++)
          if (p.items[i] > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [Expanded(child: Text(_matName(t, i))), Text(p.done ? '${fmt(p.weighed![i])} / ${_kg(t, p.items[i])}' : _kg(t, p.items[i]))]),
            ),
        const SizedBox(height: 16),
        if (p.done)
          BigButton(t('الإيصال', 'Receipt'), onTap: () => pushPage(context, _ReceiptPage(p.id)))
        else
          BigButton(t('المرحلة الجاية (تجربة)', 'Next stage (demo)'), outlined: true, onTap: () => ref.read(businessProvider.notifier).advance(p.id)),
      ]),
    );
  }
}

class _ReceiptPage extends ConsumerWidget {
  const _ReceiptPage(this.id);
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final p = s.pickups.firstWhere((x) => x.id == id);
    final w = p.weighed ?? p.items;
    return Scaffold(
      appBar: RoleBar(title: t('الإيصال', 'Receipt')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('#${p.id}', style: Theme.of(context).textTheme.titleMedium),
            Text(t(s.branches[p.branch].ar, s.branches[p.branch].en), style: TextStyle(color: context.eco.inkSoft)),
            const Divider(height: 24),
            for (var i = 0; i < bMats.length; i++)
              if (w[i] > 0) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text('${_matName(t, i)} · ${_kg(t, w[i])}')), Text(_egp(t, w[i] * bMats[i].price))])),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Text(p.reward == Reward.cash ? t('الإجمالي', 'Total') : t('النقاط', 'Points'), style: Theme.of(context).textTheme.titleSmall)),
              Text(p.reward == Reward.cash ? _egp(t, estimate(w)) : '${fmt(pointsOf(w))} ${t('نقطة', 'pts')}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.eco.primary)),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Text(t('محسوب على الوزن الفعلي عندنا.', 'Calculated from the weight we measured.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- wallet

class _WalletPage extends ConsumerWidget {
  const _WalletPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    return Scaffold(
      appBar: RoleBar(title: t('المحفظة', 'Wallet'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('الرصيد المتاح', 'Available balance'), style: const TextStyle(color: EcoColors.onCanopy)),
            AnimatedSwitcher(duration: Motion.base, child: Text(_egp(t, s.balance), key: ValueKey(s.balance), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EcoColors.bloom))),
            const SizedBox(height: 4),
            Text('${t('قيد الوزن', 'Pending')}: ${_egp(t, s.pending)} · ${fmt(s.points)} ${t('نقطة', 'pts')}', style: const TextStyle(color: EcoColors.onCanopy)),
          ]),
        ).fadeUp(),
        const SizedBox(height: 12),
        BigButton(t('اسحب رصيد', 'Withdraw'), icon: Icons.south_west_rounded, onTap: () => pushPage(context, const _PayoutPage())),
        SectionLabel(t('آخر الحركات', 'Recent activity')),
        for (final x in s.txs.take(3)) _TxRow(x),
        TextButton(onPressed: () => pushPage(context, const _TxnsPage()), child: Text(t('كل الحركات', 'All activity'))),
      ]),
    );
  }
}

class _TxRow extends ConsumerWidget {
  const _TxRow(this.x);
  final BTx x;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final plus = x.value >= 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row3(
        leading: Icon(plus ? Icons.south_east_rounded : Icons.north_east_rounded, color: plus ? context.eco.primary : context.eco.danger),
        title: t(x.ar, x.en),
        subtitle: t(x.whenAr, x.whenEn),
        trailing: Text('${plus ? '+' : '-'}${fmt(x.value.abs())}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: plus ? context.eco.primary : context.eco.danger)),
      ),
    );
  }
}

class _TxnsPage extends ConsumerWidget {
  const _TxnsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    return Scaffold(appBar: RoleBar(title: t('كل الحركات', 'All activity')), body: ListView(padding: const EdgeInsets.all(16), children: [for (final x in s.txs) _TxRow(x)]));
  }
}

class _PayoutPage extends ConsumerStatefulWidget {
  const _PayoutPage();

  @override
  ConsumerState<_PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends ConsumerState<_PayoutPage> {
  int _amt = 1;
  int _method = 0;
  static const _amounts = [200.0, 500.0, 1000.0, -1.0];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final amount = _amounts[_amt] < 0 ? s.balance : _amounts[_amt];
    final methods = [t('تحويل بنكي', 'Bank transfer'), t('محفظة موبايل', 'Mobile wallet'), t('كاش مع السواق', 'Cash with driver')];
    final ok = amount > 0 && amount <= s.balance;
    return Scaffold(
      appBar: RoleBar(title: t('سحب رصيد', 'Withdraw')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${t('المتاح', 'Available')}: ${_egp(t, s.balance)}', style: TextStyle(color: context.eco.inkSoft)),
        SectionLabel(t('المبلغ', 'Amount')),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < _amounts.length; i++) ChoiceChip(label: Text(_amounts[i] < 0 ? t('الكل', 'All') : fmt(_amounts[i])), selected: _amt == i, onSelected: (_) => setState(() => _amt = i)),
        ]),
        SectionLabel(t('الطريقة', 'Method')),
        for (var i = 0; i < methods.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: Icon(_method == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: context.eco.primary), title: methods[i], onTap: () => setState(() => _method = i)),
          ),
        if (!ok) Text(t('المبلغ أكبر من رصيدك.', 'Amount is above your balance.'), style: TextStyle(color: context.eco.danger)),
        const SizedBox(height: 12),
        BigButton('${t('اسحب', 'Withdraw')} ${fmt(amount)}', onTap: ok
            ? () {
                ref.read(businessProvider.notifier).withdraw(amount);
                toast(context, t('الطلب اتسجل', 'Withdrawal requested'));
                Navigator.of(context).pop();
              }
            : null),
      ]),
    );
  }
}

// ---------------------------------------------------------------- prices, branches, recurring

class _PricesPage extends ConsumerStatefulWidget {
  const _PricesPage();

  @override
  ConsumerState<_PricesPage> createState() => _PricesPageState();
}

class _PricesPageState extends ConsumerState<_PricesPage> {
  bool _clean = true;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final k = _clean ? 1.0 : 0.7;
    return Scaffold(
      appBar: RoleBar(title: t('الأسعار', 'Prices')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: true, label: Text(t('نضيف', 'Clean'))), ButtonSegment(value: false, label: Text(t('مخلوط', 'Mixed')))],
          selected: {_clean},
          onSelectionChanged: (v) => setState(() => _clean = v.first),
        ),
        const SizedBox(height: 12),
        for (final m in bMats)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(12)), child: Text(m.code, style: const TextStyle(color: Color(0xFF0D2B22), fontWeight: FontWeight.w700))),
              title: t(m.ar, m.en),
              subtitle: t(m.trendAr, m.trendEn),
              trailing: Text('${fmt(m.price * k)} ${t('جنيه/كجم', 'EGP/kg')}', style: Theme.of(context).textTheme.titleSmall),
            ),
          ),
        Text(t('المخلوط بياخد 70% من سعر النضيف. الأسعار أمثلة للتصميم.', 'Mixed pays 70% of the clean price. Prices are design examples.'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.eco.inkSoft)),
      ]),
    );
  }
}

class _BranchesPage extends ConsumerWidget {
  const _BranchesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    return Scaffold(
      appBar: RoleBar(title: t('الفروع', 'Branches')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < s.branches.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Icon(Icons.storefront_rounded, color: context.eco.primary),
              title: t(s.branches[i].ar, s.branches[i].en),
              subtitle: t(s.branches[i].addrAr, s.branches[i].addrEn),
              trailing: Tag(s.branches[i].on ? t('شغال', 'Active') : t('موقوف', 'Paused'), color: s.branches[i].on ? context.eco.primary : context.eco.inkSoft),
              onTap: () => pushPage(context, _BranchDetailPage(i)),
            ),
          ),
        BigButton(t('أضف فرع', 'Add branch'), icon: Icons.add_rounded, onTap: () => pushPage(context, const _AddBranchPage())),
      ]),
    );
  }
}

class _BranchDetailPage extends ConsumerWidget {
  const _BranchDetailPage(this.index);
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final b = s.branches[index];
    return Scaffold(
      appBar: RoleBar(title: t(b.ar, b.en)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(leading: Icon(Icons.place_rounded, color: context.eco.primary), title: t(b.addrAr, b.addrEn)),
        const SizedBox(height: 8),
        Row3(leading: Icon(Icons.repeat_rounded, color: context.eco.primary), title: b.schedAr == null ? t('مفيش جدول متكرر', 'No recurring schedule') : t(b.schedAr!, b.schedEn!)),
        const SizedBox(height: 8),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: b.on, onChanged: (_) => ref.read(businessProvider.notifier).toggleBranch(index), title: Text(t('الفرع شغال', 'Branch active'))),
        const SizedBox(height: 8),
        BigButton(t('بيع من الفرع ده', 'Sell from this branch'), onTap: () {
          ref.read(_sellProvider.notifier).set(_Sell(branch: index));
          pushPage(context, const _ScanPage());
        }),
      ]),
    );
  }
}

class _AddBranchPage extends ConsumerStatefulWidget {
  const _AddBranchPage();

  @override
  ConsumerState<_AddBranchPage> createState() => _AddBranchPageState();
}

class _AddBranchPageState extends ConsumerState<_AddBranchPage> {
  final _name = TextEditingController();
  final _addr = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('فرع جديد', 'New branch')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _name, decoration: InputDecoration(labelText: t('اسم الفرع', 'Branch name'))),
        const SizedBox(height: 12),
        TextField(controller: _addr, decoration: InputDecoration(labelText: t('العنوان', 'Address'))),
        const SizedBox(height: 16),
        BigButton(t('حفظ', 'Save'), onTap: () {
          if (_name.text.trim().isEmpty) return;
          ref.read(businessProvider.notifier).addBranch(_name.text.trim(), _addr.text.trim());
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

class _RecurringPage extends ConsumerWidget {
  const _RecurringPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final rec = [for (final b in s.branches) if (b.schedAr != null) b];
    return Scaffold(
      appBar: RoleBar(title: t('الاستلامات المتكررة', 'Recurring pickups')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (rec.isEmpty) EmptyState(icon: Icons.repeat_rounded, title: t('مفيش جدول متكرر.', 'No recurring schedule.'), body: ''),
        for (final b in rec) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(Icons.repeat_rounded, color: context.eco.primary), title: t(b.ar, b.en), subtitle: t(b.schedAr!, b.schedEn!))),
        const SizedBox(height: 8),
        BigButton(t('جدول جديد', 'New schedule'), icon: Icons.add_rounded, onTap: () {
          ref.read(_sellProvider.notifier).set(const _Sell(recurring: true));
          pushPage(context, const _ScanPage());
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- invoices and certificate

const _invoices = [('أكتوبر', 'October', 312.0), ('سبتمبر', 'September', 268.0), ('أغسطس', 'August', 241.0)];

class _InvoicesPage extends ConsumerWidget {
  const _InvoicesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('الفواتير', 'Invoices')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < _invoices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: Icon(Icons.receipt_long_rounded, color: context.eco.primary), title: t(_invoices[i].$1, _invoices[i].$2), trailing: Text(_egp(t, _invoices[i].$3), style: Theme.of(context).textTheme.titleSmall), onTap: () => pushPage(context, _InvoiceDetailPage(i))),
          ),
      ]),
    );
  }
}

class _InvoiceDetailPage extends ConsumerWidget {
  const _InvoiceDetailPage(this.index);
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final inv = _invoices[index];
    final rows = [
      (t('بلاستيك', 'Plastic'), inv.$3 * 0.5),
      (t('كرتون', 'Cardboard'), inv.$3 * 0.3),
      (t('ورق', 'Paper'), inv.$3 * 0.2),
    ];
    return Scaffold(
      appBar: RoleBar(title: '${t('فاتورة', 'Invoice')} ${t(inv.$1, inv.$2)}'),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(children: [
            for (final r in rows) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(r.$1)), Text(_egp(t, r.$2))])),
            const Divider(height: 24),
            Row(children: [Expanded(child: Text(t('الإجمالي', 'Total'), style: Theme.of(context).textTheme.titleSmall)), Text(_egp(t, inv.$3), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.eco.primary))]),
          ]),
        ),
        const SizedBox(height: 12),
        BigButton(t('نزّل PDF', 'Download PDF'), icon: Icons.download_rounded, outlined: true, onTap: () => toast(context, t('هتتفعّل مع السيرفر', 'Available once connected to the server'))),
      ]),
    );
  }
}

class _CertificatePage extends ConsumerWidget {
  const _CertificatePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    return Scaffold(
      appBar: RoleBar(title: t('شهادة الاستدامة', 'Sustainability certificate')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(children: [
            const LogoMark(size: 56, onDark: true),
            const SizedBox(height: 14),
            Text(_bizName(t, s), style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(t('أعاد تدوير', 'Recycled'), style: const TextStyle(color: EcoColors.onCanopy)),
            Text(_kg(t, 136 + s.weighedKg), style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EcoColors.bloom)),
          ]),
        ),
        const SizedBox(height: 12),
        BigButton(t('شارك', 'Share'), icon: Icons.ios_share_rounded, outlined: true, onTap: () => toast(context, t('هتتفعّل مع السيرفر', 'Available once connected to the server'))),
      ]),
    );
  }
}

// ---------------------------------------------------------------- team, notifications, support, settings, more

class _TeamPage extends ConsumerWidget {
  const _TeamPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    return Scaffold(
      appBar: RoleBar(title: t('الفريق', 'Team')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final m in s.team)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Icon(Icons.person_rounded, color: context.eco.primary),
              title: t(m.ar, m.en),
              subtitle: m.invited ? t('دعوة معلّقة', 'Invite pending') : null,
              trailing: Tag(m.owner ? t('مالك', 'Owner') : (m.manager ? t('مدير', 'Manager') : t('موظف', 'Staff'))),
            ),
          ),
        BigButton(t('ادعُ عضو', 'Invite member'), icon: Icons.person_add_rounded, onTap: () => pushPage(context, const _InvitePage())),
      ]),
    );
  }
}

class _InvitePage extends ConsumerStatefulWidget {
  const _InvitePage();

  @override
  ConsumerState<_InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<_InvitePage> {
  final _email = TextEditingController();
  bool _manager = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('دعوة عضو', 'Invite member')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: t('البريد الإلكتروني', 'Email'))),
        const SizedBox(height: 12),
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: false, label: Text(t('موظف', 'Staff'))), ButtonSegment(value: true, label: Text(t('مدير', 'Manager')))],
          selected: {_manager},
          onSelectionChanged: (v) => setState(() => _manager = v.first),
        ),
        const SizedBox(height: 16),
        BigButton(t('ابعت الدعوة', 'Send invite'), onTap: () {
          if (_email.text.trim().isEmpty) return;
          ref.read(businessProvider.notifier).invite(_email.text.trim(), _manager);
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

class _NotifsPage extends ConsumerWidget {
  const _NotifsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final rows = [
      (Icons.local_shipping_rounded, t('السواق في الطريق لاستلام #1052', 'Driver is on the way for pickup #1052'), t('من 10 دقايق', '10 min ago')),
      (Icons.scale_rounded, t('استلام #1041 اتوزن وأُضيف 56 جنيه', 'Pickup #1041 weighed, 56 EGP added'), t('امبارح', 'Yesterday')),
      (Icons.trending_up_rounded, t('سعر البلاستيك طلع', 'Plastic price went up'), t('من يومين', '2 days ago')),
    ];
    return Scaffold(appBar: RoleBar(title: t('الإشعارات', 'Notifications')), body: ListView(padding: const EdgeInsets.all(16), children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(r.$1, color: context.eco.primary), title: r.$2, subtitle: r.$3))]));
  }
}

class _SupportPage extends ConsumerWidget {
  const _SupportPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final faq = [
      (t('إمتى بتتحاسب؟', 'When am I paid?'), t('بعد ما نوزن الخامات عندنا، على الوزن الفعلي.', 'After we weigh the materials, based on the actual weight.')),
      (t('إيه الخامات المقبولة؟', 'What materials are accepted?'), t('بلاستيك وورق وكرتون ومعادن نضيفة.', 'Clean plastic, paper, cardboard and metal.')),
      (t('ألغي استلام؟', 'Cancel a pickup?'), t('قبل وصول السواق من شاشة الاستلام.', 'Before the driver arrives, from the pickup screen.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('الدعم', 'Support')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final f in faq) Padding(padding: const EdgeInsets.only(bottom: 8), child: EcoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.$1, style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 4), Text(f.$2, style: TextStyle(color: context.eco.inkSoft))]))),
        const SizedBox(height: 8),
        BigButton(t('كلّم الدعم', 'Contact support'), icon: Icons.support_agent_rounded, onTap: () => toast(context, t('هتتفعّل مع السيرفر', 'Available once connected to the server'))),
      ]),
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final s = ref.watch(businessProvider);
    final labels = [t('تحديثات الاستلام', 'Pickup updates'), t('الدفع والرصيد', 'Payments and balance'), t('العروض', 'Offers'), t('تغيّر الأسعار', 'Price changes')];
    return Scaffold(
      appBar: RoleBar(title: t('الإعدادات', 'Settings')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionLabel(t('الإشعارات', 'Notifications')),
        for (var i = 0; i < 4; i++) SwitchListTile(contentPadding: EdgeInsets.zero, value: s.prefs[i], onChanged: (_) => ref.read(businessProvider.notifier).togglePref(i), title: Text(labels[i])),
      ]),
    );
  }
}

class _MorePage extends ConsumerWidget {
  const _MorePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    Widget item(IconData i, String title, Widget page) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(i, color: c.primary), title: title, trailing: const Icon(Icons.chevron_right_rounded), onTap: () => pushPage(context, page)));
    return Scaffold(
      appBar: RoleBar(title: t('المزيد', 'More'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        item(Icons.storefront_rounded, t('الفروع', 'Branches'), const _BranchesPage()),
        item(Icons.sell_rounded, t('الأسعار', 'Prices'), const _PricesPage()),
        item(Icons.repeat_rounded, t('الاستلامات المتكررة', 'Recurring pickups'), const _RecurringPage()),
        item(Icons.receipt_long_rounded, t('الفواتير', 'Invoices'), const _InvoicesPage()),
        item(Icons.workspace_premium_rounded, t('شهادة الاستدامة', 'Sustainability certificate'), const _CertificatePage()),
        item(Icons.group_rounded, t('الفريق', 'Team'), const _TeamPage()),
        item(Icons.notifications_rounded, t('الإشعارات', 'Notifications'), const _NotifsPage()),
        item(Icons.support_agent_rounded, t('الدعم', 'Support'), const _SupportPage()),
        item(Icons.settings_rounded, t('الإعدادات', 'Settings'), const _SettingsPage()),
        const SizedBox(height: 8),
        BigButton(t('خروج', 'Sign out'), outlined: true, onTap: () => ref.read(sessionProvider.notifier).logout()),
      ]),
    );
  }
}
