import 'admin_data.dart';

final adminAccPages = <AdminPage>[
  AdminPage('accounts', c('كل الحسابات', 'All accounts'), c('كل المستخدمين بكل أدوارهم. اضغط صف وادخل على حسابه عشان تساعده.', 'Every user in every role. Click a row and open their account to help them.'), [
    StatsBlock([(c('حسابات نشطة دلوقتي', 'Active now'), '31', ''), (c('مواطنين', 'Citizens'), '1204', ''), (c('بيزنس', 'Businesses'), '38', ''), (c('مشترين ومصانع', 'Buyers and factories'), '17', '')]),
    TableBlock(
      c('الحسابات', 'Accounts'),
      [c('الاسم', 'Name'), c('الدور', 'Role'), c('آخر نشاط', 'Last activity'), c('منذ', 'When'), c('الحالة', 'Status')],
      [2, 1.6, 3, 1.2, 1.6],
      [
        [c('سارة', 'Sara'), c('مواطن', 'Citizen'), c('صوّرت بلاستيك وحجزت استلام #1051', 'Scanned plastic, booked pickup #1051'), s('10 min'), ok('نشط', 'Active')],
        [c('عمر', 'Omar'), c('مواطن', 'Citizen'), c('السواق مجاش، فتح تذكرة T-310', 'Driver no-show, opened ticket T-310'), s('25 min'), bd('محتاج مساعدة', 'Needs help')],
        [c('كافيه المثال', 'Example Café'), c('بيزنس', 'Business'), c('اختار نقاط بدل فلوس لاستلام #1049', 'Chose points over cash for #1049'), s('1 h'), ok('نشط', 'Active')],
        [c('مطعم المثال', 'Example Restaurant'), c('بيزنس', 'Business'), c('استلام #1048 متأخر', 'Pickup #1048 delayed'), s('2 h'), wn('متابعة', 'Watch')],
        [c('مصنع المثال', 'Example Factory'), c('مصنع', 'Factory'), c('طلب شراء #2031 بيتجهّز', 'Order #2031 being prepared'), s('3 h'), ok('نشط', 'Active')],
        [c('ورشة تدوير', 'Recycling workshop'), c('مشتري', 'Buyer'), c('بيدوّر على HDPE ومش لاقي', 'Searching for HDPE, not found'), s('5 h'), wn('متابعة', 'Watch')],
        [c('سواق 4', 'Driver 4'), c('سواق', 'Driver'), c('محطة 2 من 10، متأخر', 'Stop 2 of 10, delayed'), s('now'), wn('متأخر', 'Delayed')],
        [c('موظف 1', 'Employee 1'), c('موظف مخزن', 'Warehouse staff'), c('وزن #1052 وصوّر الميزان', 'Weighed #1052 and photographed scale'), s('20 min'), ok('نشط', 'Active')],
      ],
      keys: ['citizen', 'citizen', 'business', 'business', 'factory', 'buyer', 'driver', 'employee'],
      acts: [
        ('صوّرت 3 أغراض|حجزت استلام #1051|اتضاف 36 نقطة', 'Scanned 3 items|Booked pickup #1051|Earned 36 points'),
        ('اتفتحت تذكرة T-310|السواق ما وصلش|مستني رد', 'Opened T-310|Driver did not arrive|Awaiting reply'),
        ('طلب استلام #1049|اختار نقاط|راجع الأسعار', 'Requested #1049|Chose points|Viewed prices'),
        ('استلام #1048 متأخر|سواق 4 على الطريق', 'Pickup #1048 delayed|Driver 4 on the way'),
        ('طلب #2031|دفع تحويل بنكي|تابع الحالة', 'Order #2031|Paid by transfer|Tracked status'),
        ('بحث HDPE|ابعت طلب خاص', 'Searched HDPE|Sent special request'),
        ('وردية شغالة|محطة 2/10|3 أكياس', 'On shift|Stop 2/10|3 bags'),
        ('استلم من سواق 1|وزن #1052|صوّر الميزان', 'Received from Driver 1|Weighed #1052|Photographed scale'),
      ],
    ),
  ]),
  AdminPage('users', c('المواطنين', 'Citizens'), c('الحسابات والنقاط', 'Accounts and points'), [
    TableBlock(c('المواطنين', 'Citizens'), [c('الاسم', 'Name'), c('المستوى', 'Level'), c('النقاط', 'Points'), c('شحنات', 'Shipments'), c('الحالة', 'Status')], [2, 1.4, 1.2, 1.2, 1.4], [
      [c('سارة', 'Sara'), c('فضي', 'Silver'), s('1240'), s('18'), ok('نشط', 'Active')],
      [c('عمر', 'Omar'), c('برونزي', 'Bronze'), s('310'), s('4'), ok('نشط', 'Active')],
      [c('منى', 'Mona'), c('ذهبي', 'Gold'), s('3980'), s('52'), ok('نشط', 'Active')],
      [c('عميل 7', 'Customer 7'), c('برونزي', 'Bronze'), s('40'), s('1'), wn('مراجعة', 'Review')],
    ]),
  ]),
  AdminPage('businesses', c('البيزنس والكافيهات', 'Businesses and cafés'), c('الاتفاقيات والفروع', 'Agreements and branches'), [
    TableBlock(c('الحسابات', 'Accounts'), [c('الاسم', 'Name'), c('الفروع', 'Branches'), c('الاتفاقية', 'Agreement'), c('كجم/شهر', 'kg/month'), c('مستحق له', 'Owed'), c('الحالة', 'Status')], [2, 1, 1.6, 1.2, 1.2, 1.4], [
      [c('كافيه المثال', 'Example Café'), s('2'), c('موقّعة', 'Signed'), s('142'), s('312'), ok('نشط', 'Active')],
      [c('مطعم المثال', 'Example Restaurant'), s('1'), c('موقّعة', 'Signed'), s('96'), s('184'), ok('نشط', 'Active')],
      [c('مصنع صغير', 'Small plant'), s('1'), c('مراجعة', 'In review'), s('-'), s('-'), wn('مراجعة', 'Review')],
    ]),
  ], acts: [c('بيزنس جديد', 'Add business')]),
  AdminPage('buyers', c('المصانع والمشترين', 'Factories and buyers'), c('المصانع والأفراد اللي بيشتروا', 'Factories and individuals who buy'), [
    TableBlock(c('المشترين', 'Buyers'), [c('الاسم', 'Name'), c('النوع', 'Type'), c('العقد', 'Contract'), c('طلبات', 'Orders'), c('إجمالي', 'Total'), c('الحالة', 'Status')], [2, 1.4, 1.6, 1, 1.2, 1.4], [
      [c('مصنع المثال', 'Example Factory'), c('مصنع', 'Factory'), c('PET شهري', 'Monthly PET'), s('6'), s('5800'), ok('نشط', 'Active')],
      [c('ورشة تدوير', 'Recycling workshop'), c('فرد', 'Individual'), s('-'), s('2'), s('640'), ok('نشط', 'Active')],
    ]),
  ]),
  AdminPage('ledger', c('سجل النقاط والمبالغ', 'Ledger'), c('إضافة فقط. مفيش تعديل أو مسح.', 'Append-only. No edits or deletes.'), [
    TableBlock(c('الحركات', 'Entries'), [c('الحركة', 'Entry'), c('النوع', 'Type'), c('المرجع', 'Ref'), c('القيمة', 'Amount'), c('بواسطة', 'By'), c('الوقت', 'Time')], [1.2, 1.4, 1.4, 1.4, 1.6, 1.2], [
      [s('L-9041'), c('نقاط', 'Points'), s('#1051'), s('+36'), c('موظف 1', 'Employee 1'), s('10:42')],
      [s('L-9040'), c('مبلغ', 'Payout'), s('#1052'), s('+56 EGP'), c('موظف 1', 'Employee 1'), s('10:40')],
      [s('L-9039'), c('تصحيح', 'Correction'), s('L-9031'), s('-12'), c('مشرف', 'Supervisor'), s('09:12')],
      [s('L-9038'), c('نقاط', 'Points'), s('#1050'), s('+24'), c('موظف 2', 'Employee 2'), s('08:55')],
    ]),
  ]),
];
