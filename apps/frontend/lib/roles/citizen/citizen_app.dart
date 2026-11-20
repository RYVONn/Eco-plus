import 'dart:async';

import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../features/citizen/scan_screen.dart';
import '../common/kit.dart';
import 'citizen_logic.dart';
import 'citizen_map.dart';
import 'citizen_rewards.dart';

final citizenTabProvider = NotifierProvider<_IntNotifier, int>(_IntNotifier.new);
final citizenOnboardedProvider = NotifierProvider<_BoolNotifier, bool>(_BoolNotifier.new);

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

/// Citizen: onboarding, scan a bag, book a pickup, follow the shipment, see points and impact.
class CitizenApp extends ConsumerWidget {
  const CitizenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(citizenOnboardedProvider);
    if (!onboarded) return const OnboardingPage();
    return Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const _Tabs()));
  }
}

class _Tabs extends ConsumerWidget {
  const _Tabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final i = ref.watch(citizenTabProvider);
    return Scaffold(
      body: IndexedStack(index: i, children: const [HomePage(), ShipsPage(), PointsPage(), MePage(), MapPage()]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: ref.read(citizenTabProvider.notifier).open,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: t('الرئيسية', 'Home')),
          NavigationDestination(icon: const Icon(Icons.local_shipping_rounded), label: t('شحناتي', 'Shipments')),
          NavigationDestination(icon: const Icon(Icons.star_rounded), label: t('نقاطي', 'Points')),
          NavigationDestination(icon: const Icon(Icons.person_rounded), label: t('حسابي', 'Profile')),
          NavigationDestination(icon: const Icon(Icons.map_rounded), label: t('الخريطة', 'Map')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- onboarding

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _i = 0;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _addr = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    _addr.dispose();
    super.dispose();
  }

  bool get _real {
    final user = ref.read(sessionProvider).value;
    return user != null && !user.isDemo;
  }

  void _next() => setState(() => _i = (_i == 2 && _real) ? 6 : _i + 1);
  void _back() => setState(() => _i--);

  Widget _frame(BuildContext context, String title, String sub, List<Widget> body, Widget button) {
    final c = context.eco;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(color: c.inkSoft)),
      const SizedBox(height: 20),
      ...body,
      const Spacer(),
      button,
    ]);
  }

  Widget _stepPage(BuildContext context, Tx t) {
    final c = context.eco;
    switch (_i) {
      case 3:
        return _frame(
          context,
          t('رقم موبايلك', 'Your phone number'),
          t('هنبعتلك كود تأكيد.', 'We will send you a confirmation code.'),
          [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(children: [
                Container(width: 84, height: 56, alignment: Alignment.center, decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)), child: const Text('+20')),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.number,
                    maxLength: 11,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: '01X XXXX XXXX', counterText: ''),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text(t('بالمتابعة انت موافق على الشروط وسياسة الخصوصية.', 'By continuing you agree to the terms and privacy policy.'), style: TextStyle(fontSize: 12, color: c.inkSoft)),
          ],
          BigButton(t('ابعت الكود', 'Send code'), onTap: RegExp(r'^01[0-9]{9}$').hasMatch(_phone.text.trim()) ? _next : null),
        );
      case 4:
        final v = _otp.text;
        return _frame(
          context,
          t('اكتب الكود', 'Enter the code'),
          t('بعتناه على ${_phone.text}', 'Sent to ${_phone.text}'),
          [
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var k = 0; k < 4; k++)
                  Container(
                    width: 56,
                    height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surface, border: Border.all(color: k == v.length ? c.primary : c.line, width: 2), borderRadius: BorderRadius.circular(16)),
                    child: Text(k < v.length ? v[k] : '', style: Theme.of(context).textTheme.headlineSmall),
                  ),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: '----', counterText: ''),
            ),
            const SizedBox(height: 8),
            Center(child: Text(t('معاينة: أي 4 أرقام بتفتح. التأكيد بالكود هيشتغل لما الباك إند يدعمه.', 'Preview: any 4 digits work. Real code check comes with backend support.'), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.inkSoft))),
          ],
          BigButton(t('تأكيد', 'Verify'), onTap: _otp.text.length == 4 ? _next : null),
        );
      default:
        return _frame(
          context,
          t('عرّفنا بيك', 'Tell us about you'),
          t('اسمك وعنوانك عشان السواق يلاقيك.', 'Your name and address so the driver can find you.'),
          [
            TextField(controller: _name, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: t('اسمك', 'Your name'))),
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(color: const Color(0xFFE7EFE6), borderRadius: BorderRadius.circular(20)),
              alignment: Alignment.center,
              child: Icon(Icons.place_rounded, size: 44, color: c.primary),
            ),
            const SizedBox(height: 12),
            TextField(controller: _addr, decoration: InputDecoration(hintText: t('العنوان', 'Address'))),
          ],
          BigButton(t('التالي', 'Next'), onTap: _name.text.trim().isEmpty ? null : _next),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final slides = [
      (EcoColors.bloom, Icons.photo_camera_rounded, t('صوّر', 'Snap it'), t('صوّر كيس الزبالة والـAI بيقدّر المحتوى.', 'Photograph your bag and the AI estimates the contents.')),
      (EcoColors.mint, Icons.local_shipping_rounded, t('إحنا نيجي', 'We collect'), t('سواق بيوصل لحد بابك وبياخد منك الكود.', 'A driver comes to your door and takes your code.')),
      (const Color(0xFFFFE9D6), Icons.star_rounded, t('وانت تكسب', 'You earn'), t('النقاط بتتحسب من الوزن الفعلي في المخزن.', 'Points come from the real weight at the warehouse.')),
    ];
    final perms = ref.watch(citizenProvider.select((s) => s.perms));
    final permRows = [
      (Icons.photo_camera_rounded, t('الكاميرا', 'Camera'), t('عشان تصوّر الأكياس.', 'To photograph bags.')),
      (Icons.place_rounded, t('الموقع', 'Location'), t('عشان السواق يلاقي عنوانك.', 'So the driver finds you.')),
      (Icons.notifications_rounded, t('التنبيهات', 'Notifications'), t('عشان نبلغك بميعاد السواق.', 'To tell you about the driver.')),
    ];
    final onPerms = _i >= 6;
    final inSteps = _i >= 3 && _i <= 5;
    return Scaffold(
      appBar: RoleBar(title: '', back: false, actions: [
        if (_i < 3) TextButton(onPressed: () => setState(() => _i = _real ? 6 : 3), child: Text(t('تخطي', 'Skip'))),
        if (_i >= 4 && _i <= 5) TextButton(onPressed: _back, child: Text(t('رجوع', 'Back'))),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: inSteps
            ? _stepPage(context, t)
            : onPerms
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('كام صلاحية بسيطة', 'A few quick permissions'), style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(t('تقدر تغيّرهم بعدين من الإعدادات.', 'You can change them later in settings.'), style: TextStyle(color: c.inkSoft)),
                const SizedBox(height: 16),
                for (var k = 0; k < permRows.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row3(
                      leading: Icon(permRows[k].$1, color: c.primary),
                      title: permRows[k].$2,
                      subtitle: permRows[k].$3,
                      trailing: Switch(value: perms[k], onChanged: (_) => ref.read(citizenProvider.notifier).togglePerm(k)),
                    ),
                  ),
                const Spacer(),
                BigButton(t('يلا', 'Let us go'), onTap: ref.read(citizenOnboardedProvider.notifier).done),
              ])
            : Column(children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.base,
                    child: Container(
                      key: ValueKey(_i),
                      width: double.infinity,
                      decoration: BoxDecoration(color: slides[_i].$1, borderRadius: BorderRadius.circular(32)),
                      padding: const EdgeInsets.all(28),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(slides[_i].$2, size: 96, color: const Color(0xFF0D2B22)),
                        const SizedBox(height: 24),
                        Text(slides[_i].$3, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: const Color(0xFF0D2B22))),
                        const SizedBox(height: 10),
                        Text(slides[_i].$4, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF3E5A50), fontSize: 16)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < 3; k++) AnimatedContainer(duration: Motion.base, margin: const EdgeInsets.all(4), width: k == _i ? 22 : 8, height: 8, decoration: BoxDecoration(color: k == _i ? c.primary : c.line, borderRadius: BorderRadius.circular(8))),
                ]),
                const SizedBox(height: 16),
                BigButton(t('التالي', 'Next'), onTap: _next),
              ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- home

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(citizenProvider);
    final user = ref.watch(sessionProvider).value;
    final c = context.eco;
    final li = levelIndex(st.points);
    final next = li + 1 < levels.length ? levels[li + 1] : null;
    final active = st.active;
    final tips = [
      (Icons.cleaning_services_rounded, t('اغسل العلب', 'Rinse containers'), t('العلب النضيفة بتاخد نقاط أكتر.', 'Clean items earn more.')),
      (Icons.description_rounded, t('افصل الورق', 'Separate paper'), t('الورق المبلول مش بيتقبل.', 'Wet paper is not accepted.')),
      (Icons.delete_outline_rounded, t('فاضي أحسن', 'Empty is better'), t('فضّي العلب من السوائل.', 'Empty liquids first.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: '${t('أهلاً', 'Hello')}، ${user?.name ?? t('سارة', 'Sara')}', back: false, actions: [IconButton(icon: const Icon(Icons.notifications_rounded), tooltip: t('التنبيهات', 'Alerts'), onPressed: () => pushPage(context, const NotifsPage()))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          color: EcoColors.bloom,
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('عندك أكياس جاهزة؟', 'Bags ready?'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: const Color(0xFF0D2B22))),
            const SizedBox(height: 4),
            Text(t('صوّرها ونحدد ميعاد الاستلام.', 'Photograph them and we set the pickup.'), style: const TextStyle(color: Color(0xFF3E5A50))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                if (user != null && !user.isDemo) {
                  await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
                  await ref.read(citizenProvider.notifier).refresh();
                } else {
                  pushPage(context, const ScanPage());
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D2B22), foregroundColor: Colors.white),
              icon: const Icon(Icons.photo_camera_rounded),
              label: Text(t('صوّر كيس', 'Scan a bag')),
            ),
          ]),
        ).fadeUp(),
        if (active != null) ...[
          SectionLabel(t('الاستلام الجاي', 'Next pickup')),
          Row3(
            leading: Icon(Icons.local_shipping_rounded, color: c.primary),
            title: '${active.id} · ${t(active.whenAr, active.whenEn)}',
            subtitle: t('النهارده · 4 – 6 م', 'Today · 4 – 6 PM'),
            trailing: Tag(t('تتبّع', 'Track')),
            onTap: () => pushPage(context, ShipDetailPage(active.id)),
          ).fadeUp(index: 1),
        ],
        SectionLabel(t('مستواك', 'Your level')),
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Tag(t(levels[li].$2, levels[li].$3), color: c.primary),
              const Spacer(),
              Text('${st.points} ${t('نقطة', 'points')}', style: Theme.of(context).textTheme.titleMedium),
            ]),
            if (next != null) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ((st.points - levels[li].$4) / (next.$4 - levels[li].$4)).clamp(0, 1), minHeight: 10, backgroundColor: c.surfaceAlt, color: c.primary)),
              const SizedBox(height: 6),
              Text(t('فاضل ${next.$4 - st.points} نقطة لـ${next.$2}', '${next.$4 - st.points} points to ${next.$3}'), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.inkSoft)),
            ],
          ]),
        ).fadeUp(index: 2),
        SectionLabel(t('نصايح سريعة', 'Quick tips')),
        for (var i = 0; i < tips.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(tips[i].$1, color: c.primary), title: tips[i].$2, subtitle: tips[i].$3).fadeUp(index: 3 + i)),
      ]),
    );
  }
}

// ---------------------------------------------------------------- scan, analyze, result

class ScanPage extends ConsumerWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('صوّر الكيس', 'Scan the bag')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: context.eco.ink, borderRadius: BorderRadius.circular(28)),
              alignment: Alignment.center,
              child: Container(width: 220, height: 280, decoration: BoxDecoration(border: Border.all(color: EcoColors.bloom, width: 3), borderRadius: BorderRadius.circular(28))),
            ),
          ),
          const SizedBox(height: 12),
          Text(t('حط الكيس في الإطار وثبّت إيدك.', 'Place the bag in the frame and hold steady.'), style: TextStyle(color: context.eco.inkSoft)),
          const SizedBox(height: 12),
          BigButton(t('التقاط', 'Capture'), icon: Icons.photo_camera_rounded, onTap: () => replacePage(context, const AnalyzingPage())),
        ]),
      ),
    );
  }
}

class AnalyzingPage extends ConsumerStatefulWidget {
  const AnalyzingPage({super.key});

  @override
  ConsumerState<AnalyzingPage> createState() => _AnalyzingPageState();
}

class _AnalyzingPageState extends ConsumerState<AnalyzingPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2200), () {
      if (mounted) replacePage(context, const ResultPage());
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
          const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
          const SizedBox(height: 20),
          Text(t('بنحلل الكيس...', 'Analyzing the bag...'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(t('ثواني ونقولك.', 'One moment.'), style: TextStyle(color: context.eco.inkSoft)),
        ]),
      ),
    );
  }
}

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final contents = [(t('بلاستيك', 'Plastic'), 70, c.primary), (t('ورق', 'Paper'), 20, EcoColors.leaf), (t('أخرى', 'Other'), 10, c.amber)];
    return Scaffold(
      appBar: RoleBar(title: t('نتيجة التحليل', 'Analysis result')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        EcoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(t('الكيس جاهز للاستلام', 'The bag is ready for pickup'), style: Theme.of(context).textTheme.titleMedium)),
              Tag(t('ثقة عالية', 'High confidence')),
            ]),
            const SizedBox(height: 12),
            Text('${t('الكيس مليان', 'bag fill')} 78%', style: TextStyle(color: c.inkSoft)),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: 0.78, minHeight: 10, backgroundColor: c.surfaceAlt, color: c.primary)),
          ]),
        ).fadeUp(),
        SectionLabel(t('المحتوى', 'Contents')),
        EcoCard(
          child: Column(children: [
            for (final x in contents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(x.$1)),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: x.$2 / 100, minHeight: 10, backgroundColor: c.surfaceAlt, color: x.$3))),
                  SizedBox(width: 44, child: Text('${x.$2}%', textAlign: TextAlign.end)),
                ]),
              ),
            const Divider(height: 20),
            Row(children: [Expanded(child: Text(t('التلوث', 'Contamination'))), Tag(t('قليل', 'Low'))]),
          ]),
        ).fadeUp(index: 1),
        const SizedBox(height: 12),
        Text(t('ده تقدير. النقاط بتتحسب من الوزن الفعلي في المخزن.', 'This is an estimate. Points come from the real weight at the warehouse.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('اختار الميعاد', 'Choose a time'), onTap: () => pushPage(context, const SlotPage())),
        const SizedBox(height: 10),
        BigButton(t('صوّر تاني', 'Retake'), outlined: true, onTap: () => replacePage(context, const ScanPage())),
      ]),
    );
  }
}

// ---------------------------------------------------------------- slot and done

class SlotPage extends ConsumerStatefulWidget {
  const SlotPage({super.key});

  @override
  ConsumerState<SlotPage> createState() => _SlotPageState();
}

class _SlotPageState extends ConsumerState<SlotPage> {
  int _day = 0;
  int _win = 2;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final days = [(t('النهارده', 'Today'), 'النهارده', 'Today'), (t('بكره', 'Tomorrow'), 'بكره', 'Tomorrow'), (t('بعد بكره', 'Day after'), 'بعد بكره', 'Day after')];
    final wins = [(t('10 – 12 ص', '10 – 12 AM'), t('متاح', 'Open')), (t('2 – 4 م', '2 – 4 PM'), t('متاح', 'Open')), (t('4 – 6 م', '4 – 6 PM'), t('الأسرع', 'Fastest'))];
    return Scaffold(
      appBar: RoleBar(title: t('ميعاد الاستلام', 'Pickup time')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        SectionLabel(t('اليوم', 'Day')),
        Wrap(spacing: 8, children: [
          for (var i = 0; i < days.length; i++) ChoiceChip(label: Text(days[i].$1), selected: _day == i, onSelected: (_) => setState(() => _day = i)),
        ]),
        SectionLabel(t('الفترة', 'Window')),
        for (var i = 0; i < wins.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Icon(_win == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _win == i ? c.primary : c.inkSoft),
              title: wins[i].$1,
              trailing: Tag(wins[i].$2, color: i == 2 ? c.primary : c.inkSoft),
              onTap: () => setState(() => _win = i),
            ),
          ),
        const SizedBox(height: 8),
        Text(t('السواق بيجيلك في الفترة دي ومعاه كود تسليم هتديه له.', 'The driver arrives in this window. You give them the handover code.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 16),
        BigButton(t('أكّد الاستلام', 'Confirm pickup'), onTap: () {
          final id = ref.read(citizenProvider.notifier).book(days[_day].$2, days[_day].$3);
          toast(context, t('اتأكد الحجز', 'Booked'));
          replacePage(context, DonePage(id));
        }),
      ]),
    );
  }
}

class DonePage extends ConsumerWidget {
  const DonePage(this.id, {super.key});
  final String id;

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
            Text(t('اتحجز الاستلام', 'Pickup booked'), style: Theme.of(context).textTheme.headlineSmall).fadeUp(index: 1),
            const SizedBox(height: 8),
            Text('$id · ${t('هنبعتلك تنبيه لما السواق يتحرك.', 'We will alert you when the driver is on the way.')}', textAlign: TextAlign.center, style: TextStyle(color: c.inkSoft)).fadeUp(index: 2),
            const SizedBox(height: 32),
            BigButton(t('الرئيسية', 'Home'), onTap: () {
              ref.read(citizenTabProvider.notifier).open(0);
              popToRoot(context);
            }),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shipments

class ShipsPage extends ConsumerStatefulWidget {
  const ShipsPage({super.key});

  @override
  ConsumerState<ShipsPage> createState() => _ShipsPageState();
}

class _ShipsPageState extends ConsumerState<ShipsPage> {
  String _f = 'all';

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final ships = ref.watch(citizenProvider).ships.where((s) => _f == 'all' || (_f == 'act' ? !s.done : s.done)).toList();
    final filters = [('all', t('الكل', 'All')), ('act', t('شغالة', 'Active')), ('done', t('خلصت', 'Done'))];
    return Scaffold(
      appBar: RoleBar(title: t('شحناتي', 'My shipments'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Wrap(spacing: 8, children: [for (final f in filters) ChoiceChip(label: Text(f.$2), selected: _f == f.$1, onSelected: (_) => setState(() => _f = f.$1))]),
        const SizedBox(height: 12),
        if (ships.isEmpty) EmptyState(icon: Icons.inbox_rounded, title: t('مفيش شحنات هنا.', 'No shipments here.'), body: ''),
        for (final s in ships)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              title: s.id,
              subtitle: '${s.bags} ${t('أكياس', 'bags')} · ${t(s.whenAr, s.whenEn)}',
              trailing: Tag(s.done ? t('خلصت', 'Done') : t('شغالة', 'Active'), color: s.done ? context.eco.inkSoft : context.eco.primary),
              onTap: () => pushPage(context, ShipDetailPage(s.id)),
            ),
          ),
      ]),
    );
  }
}

class ShipDetailPage extends ConsumerWidget {
  const ShipDetailPage(this.id, {super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final ship = ref.watch(citizenProvider).ships.firstWhere((s) => s.id == id);
    final c = context.eco;
    final steps = [
      (t('اتحجز', 'Booked'), t('استلامك اتأكد.', 'Your pickup is confirmed.')),
      (t('السواق اتعيّن', 'Driver assigned'), t('بيجيلك 4 – 6 م.', 'Arrives 4 – 6 PM.')),
      (t('اتستلم', 'Collected'), t('السواق استلم الأكياس.', 'The driver has the bags.')),
      (t('اتوزن', 'Weighed'), t('النقاط اتضافت.', 'Points added.')),
    ];
    final adv = [t('السواق اتعيّن (تجربة)', 'Assign driver (demo)'), t('السواق وصل واستلم (تجربة)', 'Driver collected (demo)'), t('الوزن في المخزن (تجربة)', 'Warehouse weighs (demo)'), t('شوف نقاطك', 'See your points')];
    final showCode = ship.step == 1 || ship.step == 2;
    return Scaffold(
      appBar: RoleBar(title: ship.id),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Icon(i <= ship.step ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: i <= ship.step ? c.primary : c.inkSoft),
              title: steps[i].$1,
              subtitle: steps[i].$2,
            ),
          ),
        if (ship.step >= 1 && ship.step < 3) ...[
          SectionLabel(t('السواق', 'Your driver')),
          Row3(
            leading: Icon(Icons.person_rounded, color: c.primary),
            title: t('سواق 1', 'Driver 1'),
            subtitle: t('مثال · عربية 12', 'Example · Van 12'),
            trailing: IconButton(icon: const Icon(Icons.call_rounded), onPressed: () => toast(context, t('بنتصل بالسواق', 'Calling driver'))),
          ),
        ],
        if (showCode) ...[
          SectionLabel(t('كود التسليم', 'Handover code')),
          EcoCard(
            color: EcoColors.bloom,
            child: Column(children: [
              Text(ship.code ?? sampleHandoverCode, style: Theme.of(context).textTheme.displayMedium?.copyWith(color: const Color(0xFF0D2B22), letterSpacing: 10)),
              const SizedBox(height: 6),
              Text(t('اديه للسواق وقت الاستلام بس. مش بيظهر عنده.', 'Give it to the driver at pickup only. It is not shown to them.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF3E5A50))),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        BigButton(adv[ship.step], onTap: () {
          if (ship.step < 3) {
            ref.read(citizenProvider.notifier).advance(id);
            if (ship.step == 2) toast(context, '+42 ${t('نقطة', 'points')}');
          } else {
            ref.read(citizenTabProvider.notifier).open(2);
            popToRoot(context);
          }
        }),
        if (!ship.done) ...[
          const SizedBox(height: 10),
          BigButton(t('بلّغ عن مشكلة', 'Report an issue'), outlined: true, onTap: () => pushPage(context, const IssuePage())),
        ],
      ]),
    );
  }
}

class IssuePage extends ConsumerStatefulWidget {
  const IssuePage({super.key});

  @override
  ConsumerState<IssuePage> createState() => _IssuePageState();
}

class _IssuePageState extends ConsumerState<IssuePage> {
  int _i = -1;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final issues = [t('السواق اتأخر', 'Driver is late'), t('الكيس اتغيّر', 'Bag changed'), t('مش هقدر أكون موجود', 'I cannot be there'), t('حاجة تانية', 'Something else')];
    return Scaffold(
      appBar: RoleBar(title: t('بلّغ عن مشكلة', 'Report an issue')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var k = 0; k < issues.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(leading: Icon(_i == k ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: _i == k ? c.primary : c.inkSoft), title: issues[k], onTap: () => setState(() => _i = k)),
          ),
        const SizedBox(height: 12),
        BigButton(t('ابعت', 'Send'), onTap: _i < 0 ? null : () {
          toast(context, t('اتبعت البلاغ', 'Report sent'));
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

// ---------------------------------------------------------------- points

class PointsPage extends ConsumerWidget {
  const PointsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(citizenProvider);
    final c = context.eco;
    final li = levelIndex(st.points);
    return Scaffold(
      appBar: RoleBar(title: t('نقاطي', 'My points'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: EcoColors.canopyGradient, borderRadius: BorderRadius.circular(kRadius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('رصيدك', 'Your balance'), style: const TextStyle(color: EcoColors.onCanopy)),
            AnimatedSwitcher(duration: Motion.base, child: Text('${st.points}', key: ValueKey(st.points), style: Theme.of(context).textTheme.displayMedium?.copyWith(color: EcoColors.bloom))),
            Text(t(levels[li].$2, levels[li].$3), style: const TextStyle(color: EcoColors.onCanopy)),
          ]),
        ).fadeUp(),
        SectionLabel(t('المستويات', 'Levels')),
        for (var i = 0; i < levels.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: CircleAvatar(backgroundColor: i == li ? c.primary : c.surfaceAlt, child: Text(levels[i].$1, style: TextStyle(color: i == li ? Colors.white : c.ink, fontWeight: FontWeight.w700))),
              title: t(levels[i].$2, levels[i].$3),
              subtitle: i == 0 ? t('من أول نقطة', 'From the first point') : t('من ${levels[i].$4} نقطة', 'From ${levels[i].$4} points'),
              trailing: i == li ? Tag(t('مستواك', 'You are here')) : null,
            ),
          ),
        SectionLabel(t('المعادلة', 'Formula')),
        EcoCard(child: Text(t('الوزن × معامل الخامة × مضاعف المستوى', 'weight × material factor × level multiplier'))),
        Row(children: [
          Expanded(child: SectionLabel(t('السجل', 'History'))),
          TextButton(onPressed: () => pushPage(context, const LedgerPage()), child: Text(t('الكل', 'See all'))),
        ]),
        for (final r in st.ledger.take(3)) Padding(padding: const EdgeInsets.only(bottom: 8), child: _LedgerTile(r)),
        const SizedBox(height: 4),
        BigButton(t('إزاي بتتحسب؟', 'How it works'), outlined: true, onTap: () => pushPage(context, const HowPage())),
        if (ref.watch(sessionProvider).value?.isDemo ?? true) ...[
          const SizedBox(height: 8),
          BigButton(t('المكافآت (معاينة)', 'Rewards (preview)'), outlined: true, onTap: () => pushPage(context, const RewardsPage())),
        ],
      ]),
    );
  }
}

class _LedgerTile extends ConsumerWidget {
  const _LedgerTile(this.r);
  final LedgerRow r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Row3(title: t(r.titleAr, r.titleEn), subtitle: t(r.refAr, r.refEn), trailing: Text('+${r.points}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: context.eco.primary)));
  }
}

class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final rows = ref.watch(citizenProvider).ledger;
    return Scaffold(
      appBar: RoleBar(title: t('السجل', 'History')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: _LedgerTile(r)),
        const SizedBox(height: 8),
        Text(t('السجل بيتضاف فيه بس. التصحيح بسطر جديد.', 'The log is append-only. Corrections are a new row.'), style: TextStyle(color: context.eco.inkSoft)),
      ]),
    );
  }
}

class HowPage extends ConsumerWidget {
  const HowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final rows = [
      (t('الوزن هو الأساس', 'Weight is the truth'), t('النقاط بتتحسب بعد ما الموظف يوزن في المخزن، مش من تقدير الصورة.', 'Points are calculated after the employee weighs, not from the photo.')),
      (t('كل خامة ليها معامل', 'Each material has a factor'), t('البلاستيك النضيف بيطلع أعلى من الورق والكرتون.', 'Clean plastic earns more than paper and cardboard.')),
      (t('المستوى بيزوّد', 'Levels boost'), t('كل ما ترفع مستواك، المضاعف بيزيد.', 'The higher your level, the bigger the multiplier.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('إزاي بتتحسب؟', 'How it works')),
      body: ListView(padding: const EdgeInsets.all(16), children: [for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: r.$1, subtitle: r.$2))]),
    );
  }
}

// ---------------------------------------------------------------- profile and its pages

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final user = ref.watch(sessionProvider).value;
    final c = context.eco;
    final name = user?.name ?? t('سارة', 'Sara');
    return Scaffold(
      appBar: RoleBar(title: t('حسابي', 'Profile'), back: false),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row3(leading: CircleAvatar(radius: 24, backgroundColor: c.primary, child: Text(name.characters.first, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))), title: name, subtitle: '10 0000 0000'),
        const SizedBox(height: 12),
        Row3(leading: const Icon(Icons.place_rounded), title: t('عناويني', 'My addresses'), onTap: () => pushPage(context, const AddrsPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.notifications_rounded), title: t('التنبيهات', 'Notifications'), onTap: () => pushPage(context, const NotifsPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.bar_chart_rounded), title: t('أثري', 'My impact'), onTap: () => pushPage(context, const ImpactPage())),
        const SizedBox(height: 8),
        Row3(leading: const Icon(Icons.help_outline_rounded), title: t('المساعدة', 'Help'), onTap: () => pushPage(context, const HelpPage())),
        const SizedBox(height: 8),
        Row3(leading: Icon(Icons.delete_outline_rounded, color: c.danger), title: t('مسح الحساب', 'Delete account'), onTap: () => pushPage(context, const DeletePage())),
        SectionLabel(t('عندك كافيه أو محل؟', 'Own a café or shop?')),
        EcoCard(
          color: c.surfaceAlt,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('افتح حساب بيزنس.', 'Open a business account.')),
            const SizedBox(height: 10),
            BigButton(t('افتح حساب بيزنس', 'Open business account'), outlined: true, onTap: () => toast(context, t('قريباً (تجربة)', 'Coming soon (demo)'))),
          ]),
        ),
        const SizedBox(height: 16),
        BigButton(t('تسجيل خروج', 'Sign out'), outlined: true, icon: Icons.logout_rounded, onTap: ref.read(sessionProvider.notifier).logout),
      ]),
    );
  }
}

class AddrsPage extends ConsumerWidget {
  const AddrsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final st = ref.watch(citizenProvider);
    final c = context.eco;
    final addrs = [
      (t('البيت', 'Home'), t('شارع المثال، الحي الأول', 'Example St, District 1')),
      (t('الشغل', 'Work'), t('شارع المثال 2', 'Example St 2')),
      if (st.extraAddress) (t('عنوان جديد', 'New address'), t('عنوان تجريبي', 'Demo address')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('عناويني', 'My addresses')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < addrs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              leading: Icon(st.addressDefault == i ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: st.addressDefault == i ? c.primary : c.inkSoft),
              title: addrs[i].$1,
              subtitle: addrs[i].$2,
              trailing: st.addressDefault == i ? Tag(t('الأساسي', 'Default')) : null,
              onTap: () => ref.read(citizenProvider.notifier).setDefaultAddress(i),
            ),
          ),
        const SizedBox(height: 8),
        BigButton(t('أضف عنوان', 'Add address'), outlined: true, icon: Icons.add_rounded, onTap: st.extraAddress ? null : () {
          ref.read(citizenProvider.notifier).addAddress();
          toast(context, t('اتضاف عنوان (تجربة)', 'Address added (demo)'));
        }),
      ]),
    );
  }
}

class NotifsPage extends ConsumerWidget {
  const NotifsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final prefs = ref.watch(citizenProvider.select((s) => s.prefs));
    final c = context.eco;
    final alerts = [
      (Icons.local_shipping_rounded, t('السواق اتعيّن', 'Driver assigned'), t('بيجيلك النهارده 4 – 6 م.', 'Arrives today 4 – 6 PM.'), t('من 20 دقيقة', '20 min ago')),
      (Icons.star_rounded, t('+42 نقطة', '+42 points'), t('اتوزن الكيس: 4.2 كجم.', 'Weighed: 4.2 kg.'), t('امبارح', 'Yesterday')),
      (Icons.bar_chart_rounded, t('فاضل 180 نقطة', '180 points to go'), t('وتبقى جولد.', 'To reach Gold.'), t('قبل يومين', '2 days ago')),
    ];
    final labels = [t('تنبيهات الاستلام', 'Pickup alerts'), t('تنبيهات النقاط', 'Points alerts'), t('نصايح التدوير', 'Recycling tips')];
    return Scaffold(
      appBar: RoleBar(title: t('التنبيهات', 'Alerts')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (final a in alerts) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(leading: Icon(a.$1, color: c.primary), title: a.$2, subtitle: a.$3, trailing: Text(a.$4, style: Theme.of(context).textTheme.bodySmall))),
        SectionLabel(t('إعدادات التنبيهات', 'Notification settings')),
        for (var i = 0; i < labels.length; i++)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Row3(title: labels[i], trailing: Switch(value: prefs[i], onChanged: (_) => ref.read(citizenProvider.notifier).togglePref(i)))),
      ]),
    );
  }
}

class ImpactPage extends ConsumerWidget {
  const ImpactPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final mix = [(t('بلاستيك', 'Plastic'), 55, c.primary), (t('ورق', 'Paper'), 30, EcoColors.leaf), (t('كرتون', 'Cardboard'), 15, c.amber)];
    return Scaffold(
      appBar: RoleBar(title: t('أثري', 'My impact')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Kpi(value: '42', label: t('كجم اتدوّر', 'kg recycled')), const SizedBox(width: 10), Kpi(value: '63', label: t('تقدير CO2 (مثال)', 'Estimated CO2 (example)'))]),
        const SizedBox(height: 14),
        EcoCard(
          child: Column(children: [
            for (final x in mix)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  SizedBox(width: 70, child: Text(x.$1)),
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: x.$2 / 100, minHeight: 10, backgroundColor: c.surfaceAlt, color: x.$3))),
                  SizedBox(width: 44, child: Text('${x.$2}%', textAlign: TextAlign.end)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Text(t('الأرقام أمثلة لحد ما تتوثّق المعاملات.', 'Numbers are examples until factors are documented.'), style: TextStyle(color: c.inkSoft)),
      ]),
    );
  }
}

class HelpPage extends ConsumerStatefulWidget {
  const HelpPage({super.key});

  @override
  ConsumerState<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends ConsumerState<HelpPage> {
  int _open = -1;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final faq = [
      (t('إزاي النقاط بتتحسب؟', 'How are points calculated?'), t('من الوزن الفعلي في المخزن × معامل الخامة × مضاعف مستواك.', 'From the real warehouse weight × material factor × your level multiplier.')),
      (t('إيه اللي مش بتقبلوه؟', 'What do you not accept?'), t('الأكل والسوائل والزجاج المكسور والمخلفات الطبية.', 'Food, liquids, broken glass and medical waste.')),
      (t('لو مش موجود وقت الاستلام؟', 'What if I am not there?'), t('بلّغ من شاشة الشحنة وهنأجل الاستلام.', 'Report it from the shipment screen and we reschedule.')),
      (t('هل الكود بيظهر للسواق؟', 'Does the driver see the code?'), t('لا. انت اللي بتديه له.', 'No. You give it to them.')),
      (t('إزاي أمسح حسابي؟', 'How do I delete my account?'), t('من حسابي ثم مسح الحساب.', 'From Profile, then Delete account.')),
    ];
    return Scaffold(
      appBar: RoleBar(title: t('المساعدة', 'Help')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        for (var i = 0; i < faq.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row3(
              title: faq[i].$1,
              subtitle: _open == i ? faq[i].$2 : null,
              trailing: Icon(_open == i ? Icons.remove_rounded : Icons.add_rounded),
              onTap: () => setState(() => _open = _open == i ? -1 : i),
            ),
          ),
        const SizedBox(height: 8),
        BigButton(t('كلّمنا', 'Contact us'), outlined: true, onTap: () => pushPage(context, const ContactPage())),
      ]),
    );
  }
}

class ContactPage extends ConsumerWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    return Scaffold(
      appBar: RoleBar(title: t('كلّمنا', 'Contact us')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(decoration: InputDecoration(labelText: t('الموضوع', 'Subject'))),
        const SizedBox(height: 12),
        TextField(maxLines: 5, decoration: InputDecoration(labelText: t('رسالتك', 'Your message'))),
        const SizedBox(height: 16),
        BigButton(t('ابعت', 'Send'), onTap: () {
          toast(context, t('وصلتنا رسالتك', 'Message received'));
          Navigator.of(context).pop();
        }),
      ]),
    );
  }
}

class DeletePage extends ConsumerWidget {
  const DeletePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    return Scaffold(
      appBar: RoleBar(title: t('مسح الحساب', 'Delete account')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [Icon(Icons.warning_amber_rounded, color: c.danger), const SizedBox(width: 8), Text(t('الخطوة دي مش بترجع', 'This cannot be undone'), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: c.danger))]),
        const SizedBox(height: 10),
        Text(t('هنمسح بياناتك الشخصية. سجل النقاط بيتحفظ بدون اسمك لأسباب محاسبية.', 'We delete your personal data. The points log is kept without your name for accounting.'), style: TextStyle(color: c.inkSoft)),
        const SizedBox(height: 20),
        BigButton(t('امسح حسابي', 'Delete my account'), danger: true, onTap: () {
          toast(context, t('اتمسح الحساب (تجربة)', 'Account deleted (demo)'));
          ref.read(sessionProvider.notifier).logout();
        }),
      ]),
    );
  }
}
