import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/kit.dart';
import 'citizen_logic.dart';

class _Item {
  const _Item(this.id, this.cat, this.cost, this.color, this.icon, this.nameAr, this.nameEn, this.shortAr, this.shortEn, this.longAr, this.longEn, this.code);
  final String id, nameAr, nameEn, shortAr, shortEn, longAr, longEn, code;
  final int cat, cost;
  final Color color;
  final IconData icon;
}

/// Preview catalogue. Rewards and redemption are outside the MVP; partners, amounts and codes are placeholders.
const _items = [
  _Item('coffee', 1, 150, Color(0xFFC9F25A), Icons.coffee_rounded, 'قهوة مجانية', 'Free coffee', 'مشروب ساخن من كافيه شريك', 'One hot drink at a partner café', 'مشروب ساخن واحد من كافيه شريك. اسم الشريك بيتحدد قبل الإطلاق.', 'One hot drink at a partner café. The partner name is set before launch.', 'ECO-7K3Q-92'),
  _Item('credit', 2, 200, Color(0xFFDDF1E7), Icons.smartphone_rounded, 'رصيد موبايل', 'Mobile credit', 'رصيد على خطك', 'Top up your line', 'رصيد على رقمك. القيمة بتتحدد قبل الإطلاق.', 'Credit on your number. The amount is set before launch.', 'ECO-4M8D-17'),
  _Item('grocery', 3, 250, Color(0xFFFFE3CF), Icons.shopping_basket_rounded, 'خصم سوبرماركت', 'Grocery discount', 'خصم على مشترياتك', 'Discount on your basket', 'خصم على فاتورة من سوبرماركت شريك.', 'A discount on a bill at a partner supermarket.', 'ECO-9T2X-55'),
  _Item('tree', 4, 100, Color(0xFFCDEFD9), Icons.park_rounded, 'ازرع شجرة', 'Plant a tree', 'نقطك بتتحول لشجرة', 'Turn points into a tree', 'نقطك بتروح لمبادرة زراعة. الجهة بتتحدد قبل الإطلاق.', 'Your points go to a planting initiative. The organization is set before launch.', 'ECO-2P6L-08'),
  _Item('cinema', 3, 400, Color(0xFFE1EDFC), Icons.local_movies_rounded, 'تذكرة سينما', 'Cinema ticket', 'فيلم على حسابنا', 'A movie on us', 'تذكرة سينما واحدة من شريك.', 'One cinema ticket from a partner.', 'ECO-5H1V-63'),
  _Item('school', 4, 120, Color(0xFFEFE9FF), Icons.favorite_rounded, 'سلة تدوير لمدرسة', 'Recycling bin for a school', 'تبرع بنقطك', 'Donate your points', 'نقطك بتموّل سلة تدوير في مدرسة.', 'Your points fund a recycling bin at a school.', 'ECO-8Z4N-31'),
];

class _Voucher {
  const _Voucher(this.item, this.code, this.used);
  final _Item item;
  final String code;
  final bool used;
}

/// Preview-only rewards and wallet. Spending here is local and never touches the points ledger.
class RewardsPage extends ConsumerStatefulWidget {
  const RewardsPage({super.key});

  @override
  ConsumerState<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends ConsumerState<RewardsPage> {
  bool _mine = false;
  int _cat = 0;
  int _spent = 0;
  final List<_Voucher> _vouchers = [_Voucher(_items[0], 'ECO-1A2B-03', true)];

  void _open(_Item it, int balance) {
    final t = ref.read(txProvider);
    final c = context.eco;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(16)), child: Icon(it.icon, color: c.ink)),
              const SizedBox(width: 12),
              Expanded(child: Text(t(it.nameAr, it.nameEn), style: Theme.of(context).textTheme.titleLarge)),
              Text('${it.cost}', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 12),
            Text(t(it.longAr, it.longEn), style: TextStyle(color: c.inkSoft)),
            const SizedBox(height: 16),
            BigButton(
              it.cost > balance ? '${t('ناقصك', 'Need')} ${it.cost - balance} ${t('نقطة', 'more points')}' : t('استبدل', 'Redeem'),
              onTap: it.cost > balance
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      setState(() {
                        _spent += it.cost;
                        _vouchers.insert(0, _Voucher(it, it.code, false));
                      });
                      _ticket(it);
                    },
            ),
          ]),
        ),
      ),
    );
  }

  void _ticket(_Item it) {
    final t = ref.read(txProvider);
    final c = context.eco;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 34, backgroundColor: EcoColors.bloom, child: Icon(Icons.check_rounded, size: 40, color: c.ink)),
            const SizedBox(height: 12),
            Text(t('تم الاستبدال', 'Redeemed'), style: Theme.of(context).textTheme.headlineSmall),
            Text(t(it.nameAr, it.nameEn), style: TextStyle(color: c.inkSoft)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(16)),
              child: Text(it.code, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 2, color: c.primary)),
            ),
            const SizedBox(height: 10),
            Text(t('كود تجريبي. المكافآت برّه الـMVP.', 'Sample code. Rewards are outside the MVP.'), style: TextStyle(color: c.inkSoft, fontSize: 12)),
            const SizedBox(height: 12),
            BigButton(t('انسخ الكود', 'Copy code'), outlined: true, onTap: () {
              Clipboard.setData(ClipboardData(text: it.code));
              toast(context, t('اتنسخ', 'Copied'));
            }),
            const SizedBox(height: 8),
            BigButton(t('قسايمي', 'My vouchers'), onTap: () {
              Navigator.pop(ctx);
              setState(() => _mine = true);
            }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final balance = ref.watch(citizenProvider.select((s) => s.points)) - _spent;
    final cats = [t('الكل', 'All'), t('أكل وشرب', 'Food and drink'), t('موبايل', 'Mobile'), t('تسوق', 'Shopping'), t('خير', 'Give back')];
    final list = [for (final it in _items) if (_cat == 0 || it.cat == _cat) it];
    return Scaffold(
      appBar: RoleBar(title: t('المكافآت', 'Rewards')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(28)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('رصيدك', 'Your balance'), style: const TextStyle(color: Color(0xFFB9D3C8))),
            const SizedBox(height: 4),
            Text('$balance', style: Theme.of(context).textTheme.displaySmall?.copyWith(color: EcoColors.bloom)),
            const SizedBox(height: 8),
            Tag(t('معاينة: برّه الـMVP', 'Preview: outside the MVP')),
          ]),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: [ButtonSegment(value: false, label: Text(t('الكتالوج', 'Catalogue'))), ButtonSegment(value: true, label: Text('${t('قسايمي', 'Mine')} (${_vouchers.length})'))],
          selected: {_mine},
          onSelectionChanged: (v) => setState(() => _mine = v.first),
        ),
        const SizedBox(height: 12),
        if (!_mine) ...[
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cats.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ChoiceChip(label: Text(cats[i]), selected: _cat == i, onSelected: (_) => setState(() => _cat = i)),
            ),
          ),
          const SizedBox(height: 8),
          for (final it in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row3(
                leading: Container(width: 52, height: 52, decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(16)), child: Icon(it.icon, color: c.ink)),
                title: t(it.nameAr, it.nameEn),
                subtitle: it.cost > balance ? '${t('ناقصك', 'Need')} ${it.cost - balance}' : t(it.shortAr, it.shortEn),
                trailing: Text('${it.cost}', style: Theme.of(context).textTheme.titleMedium),
                onTap: () => _open(it, balance),
              ),
            ),
        ] else
          for (final v in _vouchers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row3(
                leading: Container(width: 52, height: 52, decoration: BoxDecoration(color: v.item.color, borderRadius: BorderRadius.circular(16)), child: Icon(v.item.icon, color: c.ink)),
                title: t(v.item.nameAr, v.item.nameEn),
                subtitle: v.code,
                trailing: Tag(v.used ? t('اتستخدم', 'Used') : t('جاهز', 'Ready')),
              ),
            ),
      ]),
    );
  }
}
