import 'admin_pages_acc.dart';
import 'admin_pages_ops.dart';
import 'admin_data.dart';

final adminSysPages = <AdminPage>[
  AdminPage('pricing', c('الأسعار والقواعد', 'Prices and rules'), c('كلها أمثلة لحد ما تتحدد', 'All placeholders until real quotes'), [
    TableBlock(c('سعر الشراء من البائعين', 'Seller buy prices'), [c('الخامة', 'Material'), c('نضيفة', 'Clean'), c('مخلوطة', 'Mixed'), c('معامل النقاط', 'Points factor')], [2, 1.4, 1.4, 1.6], [
      [c('بلاستيك', 'Plastic'), s('8'), s('5.6'), s('1.0')],
      [c('ورق', 'Paper'), s('4'), s('2.8'), s('0.6')],
      [c('كرتون', 'Cardboard'), s('3'), s('2.1'), s('0.5')],
      [c('معادن', 'Metal'), s('20'), s('14'), c('غير محدد', 'Unset')],
    ]),
    TableBlock(c('مضاعف المستوى', 'Level multiplier'), [c('المستوى', 'Level'), c('المضاعف', 'Multiplier')], [2, 2], [
      [c('برونزي', 'Bronze'), s('1.0')],
      [c('فضي', 'Silver'), s('1.2')],
    ]),
  ], acts: [c('عدّل', 'Edit')]),
  AdminPage('reports', c('التقارير', 'Reports'), c('الأثر والأداء', 'Impact and performance'), [
    StatsBlock([(c('كجم الشهر', 'kg this month'), '5190', '+9%'), (c('استلامات', 'Pickups'), '1042', '+6%'), (c('نسبة الرفض', 'Rejection rate'), '3.1%', '-0.4')]),
    BarsBlock(c('الكجم الشهري', 'Monthly kg'), [(c('أغسطس', 'Aug'), 3900), (c('سبتمبر', 'Sep'), 4420), (c('أكتوبر', 'Oct'), 4760), (c('نوفمبر', 'Nov'), 5190)]),
  ], acts: [c('صدّر PDF', 'Export PDF')]),
  AdminPage('support', c('الدعم', 'Support'), c('تذاكر العملاء', 'Customer tickets'), [
    TableBlock(c('التذاكر', 'Tickets'), [c('الرقم', 'ID'), c('من', 'From'), c('الموضوع', 'Subject'), c('الأولوية', 'Priority'), c('الحالة', 'Status')], [1, 1.6, 3, 1.2, 1.4], [
      [s('T-310'), c('سارة', 'Sara'), c('السواق مجاش', 'Driver did not come'), c('عالية', 'High'), wn('مفتوحة', 'Open')],
      [s('T-309'), c('كافيه المثال', 'Example Café'), c('استفسار عن فاتورة', 'Invoice question'), c('عادية', 'Normal'), ok('اتحلت', 'Resolved')],
    ]),
  ]),
  AdminPage('audit', c('سجل المراجعة', 'Audit log'), c('مين عمل إيه', 'Who did what'), [
    TableBlock(c('السجل', 'Log'), [c('الوقت', 'Time'), c('المستخدم', 'User'), c('الإجراء', 'Action'), c('الهدف', 'Target')], [1.4, 1.6, 3, 1.6], [
      [s('10:44'), c('مشرف', 'Supervisor'), c('صحح قيد', 'Posted correction'), s('L-9039')],
      [s('10:20'), c('أدمن', 'Admin'), c('عرض دفعة للبيع', 'Listed a lot'), s('B-PL-06')],
      [s('09:00'), c('أدمن', 'Admin'), c('أضاف سواق', 'Added driver'), s('Driver 6')],
    ]),
  ]),
  AdminPage('settings', c('الإعدادات', 'Settings'), c('الفريق والمناطق', 'Team and zones'), [
    CardsBlock(c('الإدارة', 'Administration'), [
      (c('الصلاحيات', 'Roles'), c('أدمن، مشرف، دعم، مالية', 'Admin, supervisor, support, finance'), 'ok'),
      (c('مناطق التشغيل', 'Service zones'), c('شمال، وسط، جنوب، شرق', 'North, central, south, east'), 'ok'),
      (c('التنبيهات', 'Notifications'), c('واتساب وبريد وتطبيق', 'WhatsApp, email and app'), 'ok'),
      (c('الإيقاف المؤقت', 'Feature flags'), c('المكافآت والاسترداد خارج الإصدار الأول', 'Rewards and redemption are outside the MVP'), 'warn'),
    ]),
  ]),
];

final adminPages = <AdminPage>[...adminOpsPages, ...adminAccPages, ...adminSysPages];
