import 'admin_data.dart';

final adminOpsPages = <AdminPage>[
  AdminPage('overview', c('نظرة عامة', 'Overview'), c('حالة التشغيل النهارده (أرقام مثال)', 'Today operations (example numbers)'), [
    StatsBlock([(c('استلامات النهارده', 'Pickups today'), '46', '+8'), (c('سواقين في وردية', 'Drivers on shift'), '9', '/ 12'), (c('كجم اتوزنت', 'kg weighed'), '1284', '+11%'), (c('طلبات شراء مفتوحة', 'Open buyer orders'), '7', '')]),
    BarsBlock(c('الكجم حسب الخامة (الأسبوع ده)', 'kg by material (this week)'), [(c('بلاستيك', 'Plastic'), 2140), (c('كرتون', 'Cardboard'), 1760), (c('ورق', 'Paper'), 980), (c('معادن', 'Metal'), 310)]),
    TableBlock(c('آخر النشاط', 'Recent activity'), [c('الحدث', 'Event'), c('من', 'By'), c('الوقت', 'Time'), c('الحالة', 'Status')], [3, 2, 1.5, 1.5], [
      [c('استلام #1052 اتوزن', 'Pickup #1052 weighed'), c('موظف 1', 'Employee 1'), s('10:42'), ok('تمام', 'OK')],
      [c('دفعة PL-07 اتقفلت', 'Batch PL-07 closed'), c('موظف 2', 'Employee 2'), s('10:15'), ok('تمام', 'OK')],
      [c('سواق 4 اتأخر', 'Driver 4 delayed'), c('النظام', 'System'), s('09:58'), wn('متابعة', 'Watch')],
      [c('طلب شراء #2031 اتأكد', 'Buyer order #2031 confirmed'), c('مصنع المثال', 'Example Factory'), s('09:30'), ok('تمام', 'OK')],
      [c('شحنة مرفوضة #1047', 'Shipment #1047 rejected'), c('موظف 1', 'Employee 1'), s('09:05'), bd('مرفوضة', 'Rejected')],
    ]),
  ], acts: [c('تصدير', 'Export')]),
  AdminPage('live', c('التشغيل المباشر', 'Live operations'), c('السواقين والمسارات دلوقتي', 'Drivers and routes right now'), [
    MapBlock(c('الخريطة', 'Map')),
    TableBlock(c('المسارات النشطة', 'Active routes'), [c('السواق', 'Driver'), c('العربية', 'Van'), c('المحطات', 'Stops'), c('التقدم', 'Progress'), c('الوصول المتوقع', 'ETA'), c('الحالة', 'Status')], [2, 1.4, 1, 1.4, 1.4, 1.4], [
      [c('سواق 1', 'Driver 1'), s('Van 12'), s('4 / 9'), s('44%'), s('11:20'), ok('في الطريق', 'On route')],
      [c('سواق 2', 'Driver 2'), s('Van 7'), s('7 / 8'), s('88%'), s('10:50'), ok('في الطريق', 'On route')],
      [c('سواق 4', 'Driver 4'), s('Van 3'), s('2 / 10'), s('20%'), s('12:10'), wn('متأخر', 'Delayed')],
      [c('سواق 6', 'Driver 6'), s('Van 9'), s('0 / 6'), s('0%'), s('-'), wn('لسه ما بدأش', 'Not started')],
    ]),
  ]),
  AdminPage('pickups', c('الاستلامات', 'Pickups'), c('كل طلبات الاستلام. اضغط صف للتفاصيل.', 'All pickup requests. Click a row for details.'), [
    TableBlock(c('الاستلامات', 'Pickups'), [c('الرقم', 'ID'), c('العميل', 'Customer'), c('النوع', 'Type'), c('السواق', 'Driver'), c('الكجم', 'kg'), c('الحالة', 'Status')], [1, 2.2, 1.4, 1.6, 1, 1.6], [
      [s('#1052'), c('كافيه المثال', 'Example Café'), c('بيزنس', 'Business'), c('سواق 1', 'Driver 1'), s('10.4'), ok('اتوزن', 'Weighed')],
      [s('#1051'), c('سارة', 'Sara'), c('مواطن', 'Citizen'), c('سواق 2', 'Driver 2'), s('5'), wn('في الطريق', 'On the way')],
      [s('#1050'), c('عمر', 'Omar'), c('مواطن', 'Citizen'), s('-'), s('7'), wn('مستني سواق', 'Awaiting driver')],
      [s('#1049'), c('كافيه المثال', 'Example Café'), c('بيزنس', 'Business'), c('سواق 1', 'Driver 1'), s('7'), ok('مجدول', 'Scheduled')],
      [s('#1048'), c('مطعم المثال', 'Example Restaurant'), c('بيزنس', 'Business'), c('سواق 4', 'Driver 4'), s('8'), wn('متأخر', 'Delayed')],
      [s('#1047'), c('عميل 7', 'Customer 7'), c('مواطن', 'Citizen'), c('سواق 2', 'Driver 2'), s('3'), bd('مرفوضة', 'Rejected')],
    ]),
  ], acts: [c('استلام جديد', 'New pickup')]),
  AdminPage('drivers', c('السواقين', 'Drivers'), c('الفريق والمستندات', 'Team and documents'), [
    TableBlock(c('السواقين', 'Drivers'), [c('الاسم', 'Name'), c('العربية', 'Van'), c('المنطقة', 'Zone'), c('محطات النهارده', 'Stops today'), c('الحالة', 'Status')], [2, 1.4, 1.8, 1.4, 1.6], [
      [c('سواق 1', 'Driver 1'), s('Van 12'), c('شمال', 'North'), s('4 / 9'), ok('في وردية', 'On shift')],
      [c('سواق 2', 'Driver 2'), s('Van 7'), c('وسط', 'Central'), s('7 / 8'), ok('في وردية', 'On shift')],
      [c('سواق 3', 'Driver 3'), s('Van 5'), c('جنوب', 'South'), s('-'), wn('إجازة', 'Off')],
      [c('سواق 4', 'Driver 4'), s('Van 3'), c('شرق', 'East'), s('2 / 10'), wn('متأخر', 'Delayed')],
    ]),
    CardsBlock(c('مستندات قاربت تخلص', 'Documents expiring'), [(c('تأمين Van 3', 'Insurance Van 3'), c('ينتهي خلال 12 يوم', 'Expires in 12 days'), 'warn'), (c('رخصة سواق 2', 'License Driver 2'), c('سارية لحد 2027', 'Valid until 2027'), 'ok')]),
  ], acts: [c('سواق جديد', 'Add driver')]),
  AdminPage('warehouse', c('المخزن والدفعات', 'Warehouse and batches'), c('الدفعات المفتوحة والمقفولة', 'Open and closed batches'), [
    StatsBlock([(c('شحنات مستنية', 'Waiting shipments'), '12', ''), (c('دفعات مفتوحة', 'Open batches'), '4', ''), (c('دفعات للبيع', 'Listed batches'), '3', '')]),
    TableBlock(c('الدفعات', 'Batches'), [c('الكود', 'Code'), c('الخامة', 'Material'), c('كجم', 'kg'), c('السعة', 'Capacity'), c('الحالة', 'Status')], [1.4, 1.6, 1, 1, 1.6], [
      [s('B-PL-07'), c('بلاستيك', 'Plastic'), s('312'), s('500'), ok('مفتوحة', 'Open')],
      [s('B-PA-08'), c('ورق', 'Paper'), s('180'), s('400'), ok('مفتوحة', 'Open')],
      [s('B-CB-09'), c('كرتون', 'Cardboard'), s('410'), s('500'), wn('قربت تتملي', 'Almost full')],
      [s('B-MT-10'), c('معادن', 'Metal'), s('40'), s('100'), ok('مفتوحة', 'Open')],
      [s('B-PL-06'), c('بلاستيك', 'Plastic'), s('500'), s('500'), ok('اتعرضت للبيع', 'Listed')],
    ]),
  ]),
  AdminPage('lots', c('الدفعات المعروضة', 'Marketplace lots'), c('اللي بيشوفه المشترين في السوق', 'What buyers see on the market'), [
    TableBlock(c('المعروض', 'Listed'), [c('الدفعة', 'Lot'), c('الجودة', 'Grade'), c('المتاح كجم', 'Avail. kg'), c('السعر', 'Price/kg'), c('أقل كمية', 'Min'), c('الحالة', 'Status')], [2, 1.6, 1.2, 1.2, 1.2, 1.4], [
      [c('PET نضيف', 'Clean PET'), c('نضيف', 'Clean'), s('1800'), s('11'), s('500'), ok('معروض', 'Listed')],
      [c('بلاستيك مخلوط', 'Mixed plastic'), c('مخلوط', 'Mixed'), s('240'), s('7'), s('20'), ok('معروض', 'Listed')],
      [c('ورق أبيض', 'White paper'), c('نضيف', 'Clean'), s('600'), s('6'), s('100'), ok('معروض', 'Listed')],
      [c('كرتون بالات', 'Baled cardboard'), c('نضيف', 'Clean'), s('2400'), s('4.5'), s('500'), wn('قرب يخلص', 'Low stock')],
    ]),
    CardsBlock(c('ملاحظة', 'Note'), [(c('الأسعار أمثلة', 'Prices are examples'), c('لسه هتتحدد بعد عروض أسعار حقيقية.', 'To be set after real quotes.'), 'warn')]),
  ], acts: [c('اعرض دفعة', 'List a lot')]),
  AdminPage('orders', c('طلبات الشراء', 'Buyer orders'), c('من المصانع والمشترين', 'From factories and buyers'), [
    TableBlock(c('الطلبات', 'Orders'), [c('الرقم', 'ID'), c('المشتري', 'Buyer'), c('الدفعة', 'Lot'), c('كجم', 'kg'), c('الاستلام', 'Fulfilment'), c('الحالة', 'Status')], [1, 2, 1.8, 1, 1.4, 1.6], [
      [s('#2031'), c('مصنع المثال', 'Example Factory'), c('PET نضيف', 'Clean PET'), s('500'), c('توصيل', 'Delivery'), wn('بنجهّز', 'Preparing')],
      [s('#2030'), c('ورشة تدوير', 'Recycling workshop'), c('علب ألومنيوم', 'Aluminium cans'), s('20'), c('استلام', 'Pickup'), ok('جاهز', 'Ready')],
      [s('#2024'), c('مصنع المثال', 'Example Factory'), c('كرتون بالات', 'Baled cardboard'), s('1000'), c('استلام', 'Pickup'), ok('اتسلّم', 'Delivered')],
    ]),
  ]),
  AdminPage('requests', c('طلبات المشترين الخاصة', 'Buyer requests'), c('اللي مش موجود في السوق', 'What is not on the market'), [
    TableBlock(c('الطلبات', 'Requests'), [c('من', 'From'), c('الخامة', 'Material'), c('الكمية', 'Qty'), c('السعر المستهدف', 'Target'), c('الحالة', 'Status')], [2, 1.6, 1.2, 1.4, 1.6], [
      [c('مصنع المثال', 'Example Factory'), s('HDPE'), s('2000 kg'), s('-'), wn('جديد', 'New')],
      [c('ورشة تدوير', 'Recycling workshop'), c('ورق', 'Paper'), s('300 kg'), s('5'), ok('اتوفّر', 'Sourced')],
    ]),
  ]),
];
