import '../admin/admin_data.dart';

/// Factory web portal pages. All numbers and names are design examples.
const factoryRole = Cell('مصنع', 'Factory');

const factoryNav = [
  (Cell('الشراء', 'Buying'), ['overview', 'market', 'orders', 'contracts', 'requests']),
  (Cell('البيع', 'Selling'), ['scrap']),
  (Cell('الحساب', 'Account'), ['invoices', 'quality', 'team', 'settings']),
];

final factoryPages = <AdminPage>[
  AdminPage('overview', c('نظرة عامة', 'Overview'), c('مصنع النيل للتدوير', 'Nile Recycling Plant'), [
    StatsBlock([
      (c('طلبات مفتوحة', 'Open orders'), '2', ''),
      (c('مشتريات الشهر', 'Bought this month'), '6,400 kg', '+12%'),
      (c('فواتير مستحقة', 'Invoices due'), '4,000', ''),
    ]),
    BarsBlock(c('المشتريات الشهرية', 'Monthly purchases'), [(c('أغسطس', 'Aug'), 4800), (c('سبتمبر', 'Sep'), 5600), (c('أكتوبر', 'Oct'), 6400)]),
  ], acts: [c('تصفح السوق', 'Browse market')]),
  AdminPage('market', c('السوق', 'Market'), c('دفعات متاحة للشراء', 'Lots available to buy'), [
    TableBlock(c('الدفعات', 'Lots'), [c('الدفعة', 'Lot'), c('المادة', 'Material'), c('المتاح', 'Available'), c('السعر/كجم', 'Price/kg')], [1, 1.5, 1, 1], [
      [s('L-101'), c('PET نضيف', 'Clean PET'), s('3,200 kg'), s('10.5')],
      [s('L-102'), c('كرتون مضغوط', 'Baled cardboard'), s('5,000 kg'), s('3.8')],
      [s('L-103'), c('ألومنيوم', 'Aluminium'), s('900 kg'), s('44.0')],
    ]),
  ], acts: [c('اطلب دفعة', 'Order a lot')]),
  AdminPage('orders', c('الطلبات', 'Orders'), c('طلبات الشراء وحالتها', 'Purchase orders and status'), [
    TableBlock(c('الطلبات', 'Orders'), [c('رقم', 'No.'), c('المادة', 'Material'), c('الكمية', 'Qty'), c('الحالة', 'Status')], [1, 1.5, 1, 1.5], [
      [s('#2031'), c('PET نضيف', 'Clean PET'), s('1,000 kg'), wn('في الطريق', 'On the way')],
      [s('#2028'), c('كرتون مضغوط', 'Baled cardboard'), s('2,000 kg'), wn('قيد التجهيز', 'Preparing')],
      [s('#2024'), c('ألومنيوم', 'Aluminium'), s('300 kg'), ok('اتسلم', 'Delivered')],
    ]),
  ]),
  AdminPage('contracts', c('العقود', 'Contracts'), c('توريد شهري ثابت', 'Fixed monthly supply'), [
    TableBlock(c('العقود', 'Contracts'), [c('العقد', 'Contract'), c('الكمية', 'Qty'), c('السعر', 'Price'), c('الحالة', 'Status')], [2, 1, 1, 1], [
      [c('PET نضيف شهري', 'Clean PET monthly'), s('2,000 kg'), s('10.5'), ok('ساري', 'Active')],
    ]),
  ], acts: [c('عقد جديد', 'New contract')]),
  AdminPage('requests', c('طلبات خاصة', 'Requests'), c('اطلب مادة مش موجودة', 'Ask for a material not listed'), [
    CardsBlock(c('طلباتك', 'Your requests'), [
      (c('HDPE نضيف 1,500 كجم', 'Clean HDPE 1,500 kg'), c('منتظر عروض', 'Waiting for offers'), 'warn'),
    ]),
  ], acts: [c('طلب جديد', 'New request')]),
  AdminPage('scrap', c('بيع الخردة', 'Sell scrap'), c('بيع مخلفات المصنع', 'Sell your plant scrap'), [
    TableBlock(c('الاستلامات', 'Pickups'), [c('رقم', 'No.'), c('المادة', 'Material'), c('الحالة', 'Status')], [1, 2, 1.5], [
      [s('#S-14'), c('خردة حديد', 'Scrap iron'), wn('مجدول', 'Scheduled')],
      [s('#S-11'), c('كرتون', 'Cardboard'), ok('اتسلم', 'Delivered')],
    ]),
  ], acts: [c('اطلب استلام', 'Request pickup')]),
  AdminPage('invoices', c('الفواتير', 'Invoices'), c('المدفوع والمستحق', 'Paid and due'), [
    TableBlock(c('الفواتير', 'Invoices'), [c('رقم', 'No.'), c('المبلغ', 'Amount'), c('الحالة', 'Status')], [1.5, 1, 1], [
      [s('INV-318'), s('4,000'), wn('مستحقة', 'Due')],
      [s('INV-310'), s('4,500'), ok('مدفوعة', 'Paid')],
    ]),
  ]),
  AdminPage('quality', c('الجودة', 'Quality'), c('تقارير فحص الدفعات', 'Lot inspection reports'), [
    CardsBlock(c('التقارير', 'Reports'), [
      (c('الطلب #2024', 'Order #2024'), c('مطابق للمواصفات', 'Meets specification'), 'ok'),
      (c('الطلب #2028', 'Order #2028'), c('رطوبة أعلى من المعتاد', 'Moisture above normal'), 'warn'),
    ]),
  ]),
  AdminPage('team', c('الفريق', 'Team'), c('مين يقدر يشتري ويشوف', 'Who can buy and view'), [
    TableBlock(c('الأعضاء', 'Members'), [c('الاسم', 'Name'), c('الدور', 'Role'), c('الحالة', 'Status')], [1.5, 1.5, 1], [
      [c('أنت', 'You'), c('مالك', 'Owner'), ok('نشط', 'Active')],
      [c('هبة', 'Heba'), c('مشتريات', 'Purchasing'), ok('نشط', 'Active')],
    ]),
  ], acts: [c('ادعو عضو', 'Invite member')]),
  AdminPage('settings', c('الإعدادات', 'Settings'), c('الحساب والتنبيهات', 'Account and alerts'), [
    CardsBlock(c('الإعدادات', 'Settings'), [
      (c('بيانات المصنع', 'Plant details'), c('الاسم والعنوان والسجل', 'Name, address and registration'), 'ok'),
      (c('المواد المهتم بيها', 'Interests'), c('اختار المواد اللي توصلك تنبيهاتها', 'Choose materials you want alerts for'), 'ok'),
    ]),
  ]),
];
