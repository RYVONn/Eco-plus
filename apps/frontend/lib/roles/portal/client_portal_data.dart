import '../admin/admin_data.dart';

/// Business web portal pages. All numbers and names are design examples.
const clientRole = Cell('بيزنس', 'Business');

const clientNav = [
  (Cell('الشغل', 'Work'), ['overview', 'pickups', 'request', 'branches']),
  (Cell('الفلوس', 'Money'), ['wallet', 'statements', 'prices']),
  (Cell('الأثر والفريق', 'Impact and team'), ['impact', 'team', 'settings']),
];

final clientPages = <AdminPage>[
  AdminPage('overview', c('نظرة عامة', 'Overview'), c('الكافيه المثال', 'Example Café'), [
    StatsBlock([
      (c('الرصيد', 'Balance'), '1,240', ''),
      (c('كجم الشهر ده', 'kg this month'), '142', '+9%'),
      (c('الاستلام الجاي', 'Next pickup'), c('بكرة 10:00', 'Tomorrow 10:00').ar, ''),
    ]),
    BarsBlock(c('الكميات الشهرية', 'Monthly kg'), [(c('أغسطس', 'Aug'), 102), (c('سبتمبر', 'Sep'), 114), (c('أكتوبر', 'Oct'), 142)]),
  ], acts: [c('اطلب استلام', 'Request pickup')]),
  AdminPage('pickups', c('الاستلامات', 'Pickups'), c('كل الاستلامات وحالتها', 'All pickups and status'), [
    TableBlock(c('الاستلامات', 'Pickups'), [c('رقم', 'No.'), c('الفرع', 'Branch'), c('الحالة', 'Status'), c('الوزن', 'Weight')], [1, 2, 1.5, 1], [
      [s('#P-412'), c('فرع المعادي', 'Maadi branch'), wn('في الطريق', 'On the way'), s('—')],
      [s('#P-398'), c('فرع المعادي', 'Maadi branch'), ok('اتسلم', 'Delivered'), s('48 kg')],
      [s('#P-377'), c('فرع الزمالك', 'Zamalek branch'), ok('اتسلم', 'Delivered'), s('52 kg')],
    ]),
  ]),
  AdminPage('request', c('طلب استلام', 'Request pickup'), c('اختار الفرع والمواد والوقت', 'Pick branch, materials and time'), [
    CardsBlock(c('خطوات الطلب', 'How it works'), [
      (c('1. الفرع والمواد', '1. Branch and materials'), c('اختار الفرع واكتب الكمية التقريبية', 'Choose the branch and estimate the amount'), 'ok'),
      (c('2. الميعاد', '2. Time'), c('اختار يوم وفترة مناسبة', 'Choose a day and time slot'), 'ok'),
      (c('3. الوزن والدفع', '3. Weighing and payment'), c('الفلوس بتتحسب من الوزن الفعلي بعد الوزن', 'Money is paid from the weighed amount only'), 'ok'),
    ]),
  ], acts: [c('ابعت الطلب', 'Send request')]),
  AdminPage('branches', c('الفروع', 'Branches'), c('مواقع الاستلام', 'Pickup locations'), [
    TableBlock(c('الفروع', 'Branches'), [c('الفرع', 'Branch'), c('العنوان', 'Address'), c('الحالة', 'Status')], [1.5, 2.5, 1], [
      [c('المعادي', 'Maadi'), c('شارع 9، المعادي', 'Street 9, Maadi'), ok('شغال', 'Active')],
      [c('الزمالك', 'Zamalek'), c('شارع 26 يوليو', '26 July St.'), ok('شغال', 'Active')],
    ]),
  ], acts: [c('أضف فرع', 'Add branch')]),
  AdminPage('wallet', c('المحفظة', 'Wallet'), c('الرصيد والحركات', 'Balance and movements'), [
    StatsBlock([(c('الرصيد', 'Balance'), '1,240', ''), (c('اتحول الشهر ده', 'Paid out this month'), '312', '')]),
    TableBlock(c('الحركات', 'Movements'), [c('التاريخ', 'Date'), c('البيان', 'Details'), c('المبلغ', 'Amount')], [1, 2.5, 1], [
      [s('12/10'), c('استلام #P-398', 'Pickup #P-398'), ok('+ 120', '+ 120')],
      [s('05/10'), c('تحويل لحسابك', 'Payout to your account'), bd('- 300', '- 300')],
    ]),
  ], acts: [c('اسحب الرصيد', 'Withdraw')]),
  AdminPage('statements', c('كشوف الحساب', 'Statements'), c('ملخص شهري', 'Monthly summary'), [
    TableBlock(c('الشهور', 'Months'), [c('الشهر', 'Month'), c('الكمية', 'Weight'), c('المبلغ', 'Amount')], [1.5, 1, 1], [
      [c('أكتوبر', 'October'), s('133 kg'), s('312')],
      [c('سبتمبر', 'September'), s('114 kg'), s('268')],
      [c('أغسطس', 'August'), s('102 kg'), s('241')],
    ]),
  ], acts: [c('نزّل PDF', 'Download PDF')]),
  AdminPage('prices', c('الأسعار', 'Prices'), c('سعر الكيلو حسب المادة (أمثلة)', 'Price per kg by material (examples)'), [
    TableBlock(c('الأسعار', 'Prices'), [c('المادة', 'Material'), c('السعر', 'Price')], [2, 1], [
      [c('بلاستيك PET', 'PET plastic'), s('8.0')],
      [c('كرتون', 'Cardboard'), s('3.5')],
      [c('ألومنيوم', 'Aluminium'), s('42.0')],
    ]),
  ]),
  AdminPage('impact', c('الأثر', 'Impact'), c('أثرك البيئي', 'Your environmental impact'), [
    StatsBlock([(c('كجم اتدوّر', 'kg recycled'), '358', ''), (c('كربون موفّر', 'CO2 saved'), '420 kg', '')]),
    BarsBlock(c('شهريًا', 'Monthly'), [(c('أغسطس', 'Aug'), 102), (c('سبتمبر', 'Sep'), 114), (c('أكتوبر', 'Oct'), 133), (c('نوفمبر', 'Nov'), 142)]),
  ], acts: [c('شهادة الأثر', 'Impact certificate')]),
  AdminPage('team', c('الفريق', 'Team'), c('مين يقدر يطلب ويشوف', 'Who can request and view'), [
    TableBlock(c('الأعضاء', 'Members'), [c('الاسم', 'Name'), c('الدور', 'Role'), c('الحالة', 'Status')], [1.5, 1.5, 1], [
      [c('أنت', 'You'), c('مالك', 'Owner'), ok('نشط', 'Active')],
      [c('منى', 'Mona'), c('مدير فرع', 'Branch manager'), ok('نشط', 'Active')],
    ]),
  ], acts: [c('ادعو عضو', 'Invite member')]),
  AdminPage('settings', c('الإعدادات', 'Settings'), c('الحساب والتنبيهات', 'Account and alerts'), [
    CardsBlock(c('الإعدادات', 'Settings'), [
      (c('بيانات الشركة', 'Company details'), c('الاسم والعنوان والسجل', 'Name, address and registration'), 'ok'),
      (c('التنبيهات', 'Notifications'), c('اختار توصلك إزاي', 'Choose how you hear from us'), 'ok'),
    ]),
  ]),
];
