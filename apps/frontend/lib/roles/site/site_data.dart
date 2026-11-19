/// Public website content. Numbers and prices are design examples.
typedef P = (String, String);

sealed class Blk {
  const Blk();
}

class SiteHero extends Blk {
  const SiteHero(this.h1, this.em, this.p, this.b1, this.go1, {this.light = false, this.b2, this.go2});
  final P h1, em, p, b1;
  final String go1;
  final bool light;
  final P? b2;
  final String? go2;
}

class H2 extends Blk {
  const H2(this.t);
  final P t;
}

class Cards extends Blk {
  const Cards(this.items);

  /// number, title, description
  final List<(P, P, P)> items;
}

class Band extends Blk {
  const Band(this.t, this.btn, this.go);
  final P t, btn;
  final String go;
}

class Marquee extends Blk {
  const Marquee();
}

class FaqBlk extends Blk {
  const FaqBlk();
}

class PricingBlk extends Blk {
  const PricingBlk();
}

const siteNav = [
  ('how', ('إزاي بتشتغل', 'How it works')),
  ('sell', ('للبيع', 'Sell')),
  ('buy', ('للشراء', 'Buy')),
  ('price', ('الأسعار', 'Prices')),
  ('about', ('عننا', 'About')),
];

const sitePages = <String, List<Blk>>{
  'home': [
    SiteHero(('صوّر الخامة.', 'Snap it.'), ('إحنا نيجي وانت تكسب.', 'We collect. You earn.'), ('سوق للخامات المعاد تدويرها. بيت، كافيه أو مصنع: صوّر اللي عندك وخد نقاط أو فلوس.', 'A marketplace for recyclable material. Home, café or factory: photograph what you have and earn points or cash.'), ('ابدأ', 'Get started'), 'contact', b2: ('إزاي؟', 'How?'), go2: 'how'),
    Marquee(),
    H2(('تلات خطوات', 'Three steps')),
    Cards([
      (('1', '1'), ('صوّر', 'Snap'), ('الصورة بتحدد النوع والكمية.', 'The photo detects type and amount.')),
      (('2', '2'), ('إحنا نيجي', 'We collect'), ('سواق يستلم وموظف يوزن.', 'A driver collects and staff weigh.')),
      (('3', '3'), ('تكسب', 'You earn'), ('نقاط أو فلوس بالوزن الفعلي.', 'Points or cash by weighed amount.')),
    ]),
    Band(('بتبيع أو بتشتري؟', 'Selling or buying?'), ('كلمنا', 'Talk to us'), 'contact'),
  ],
  'how': [
    SiteHero(('من الصورة', 'From photo'), ('للفلوس.', 'to payout.'), ('أربع خطوات والوزن الفعلي هو الحقيقة.', 'Four steps, and the weighed value is the truth.'), ('ابدأ', 'Get started'), 'contact', light: true),
    Cards([
      (('1', '1'), ('صوّر', 'Snap'), ('وحدد الميعاد.', 'And pick a time.')),
      (('2', '2'), ('السواق', 'Driver'), ('يستلم بكود لا يظهر له.', 'Collects with a code it never sees.')),
      (('3', '3'), ('المخزن', 'Warehouse'), ('يستلم من السواق ويصوّر ويوزن.', 'Receives from the driver, photographs and weighs.')),
      (('4', '4'), ('الدفع', 'Payout'), ('نقاط أو فلوس.', 'Points or cash.')),
    ]),
    FaqBlk(),
  ],
  'sell': [
    SiteHero(('اللي عندك', 'What you have'), ('ليه قيمة.', 'has value.'), ('مواطن أو كافيه أو مصنع: نفس الخطوات، تصوّر وتاخد نقاط أو فلوس.', 'Household, café or factory: same steps. Photograph and take points or cash.'), ('سجّل', 'Register'), 'contact'),
    Cards([
      (('•', '•'), ('بيت', 'Home'), ('نقاط زي كارت ولاء.', 'Points like a loyalty card.')),
      (('•', '•'), ('كافيه ومطعم', 'Café and restaurant'), ('جدول متكرر وكشف شهري.', 'Recurring schedule and monthly statement.')),
      (('•', '•'), ('مصنع', 'Factory'), ('بيع الهالك بالوزن.', 'Sell scrap by weight.')),
    ]),
  ],
  'buy': [
    SiteHero(('اشتري', 'Buy sorted'), ('خامة مفروزة.', 'material.'), ('مصنع أو بتدوّر لنفسك: دفعات متوزنة وأسعار واضحة.', 'A factory or recycling yourself: weighed batches and clear prices.'), ('سجّل كمشتري', 'Register as a buyer'), 'contact', light: true),
    Cards([
      (('1', '1'), ('تصفّح', 'Browse'), ('بلاستيك وورق وكرتون ومعادن.', 'Plastic, paper, cardboard, metal.')),
      (('2', '2'), ('اطلب', 'Order'), ('استلام أو توصيل.', 'Pickup or delivery.')),
    ]),
  ],
  'price': [
    SiteHero(('أسعار', 'Clear'), ('واضحة.', 'prices.'), ('أمثلة للتصميم ولسه هتتحدد.', 'Design examples, still to be set.'), ('اسأل', 'Ask'), 'contact'),
    PricingBlk(),
  ],
  'about': [
    SiteHero(('إيكو بلس', 'About'), ('من AZTEAC.', 'ecoplus.'), ('بدأ مشروع جامعي وبقى سوق حقيقي للخامات في مصر.', 'Started as a university project, now a real materials market in Egypt.'), ('كلمنا', 'Talk to us'), 'contact', light: true),
    Cards([
      (('1', '1'), ('وزن صادق', 'Honest weight'), ('الوزن الفعلي هو الحقيقة.', 'The weighed value is the truth.')),
      (('2', '2'), ('خصوصية', 'Privacy'), ('كود التسليم مبيظهرش للسواق.', 'The handover code is never shown to the driver.')),
    ]),
  ],
  'contact': [
    SiteHero(('يلا', 'Let’s'), ('نبدأ.', 'start.'), ('سواء بتبيع خامات أو بتشتري.', 'Whether you sell material or buy it.'), ('إزاي بتشتغل', 'How it works'), 'how', light: true),
  ],
};

const siteFaqs = <(P, P)>[
  (('إزاي بتتحسب الفلوس أو النقاط؟', 'How are money or points calculated?'), ('بعد ما الموظف يوزن. النقاط للمواطنين = الوزن × معامل الخامة × مضاعف المستوى. والبيزنس بالوزن × سعر الكيلو.', 'After staff weigh. Citizen points = weight × material factor × level multiplier. Businesses are paid weight × price per kg.')),
  (('هل المكافآت متاحة؟', 'Are rewards available?'), ('النقاط شغالة زي كارت ولاء، والاسترداد في مرحلة لاحقة.', 'Points work like a loyalty card; redemption comes in a later phase.')),
  (('بتغطوا فين؟', 'Where do you operate?'), ('هنبدأ بمناطق محددة. سيب بياناتك ونبلّغك.', 'We start in selected zones. Leave your details and we will tell you.')),
  (('إيه الخامات؟', 'Which materials?'), ('بلاستيك وورق وكرتون ومعادن.', 'Plastic, paper, cardboard and metal.')),
];

const sitePrices = <(P, String, String, String)>[
  (('بلاستيك', 'Plastic'), '8', '5.6', '11'),
  (('ورق', 'Paper'), '4', '2.8', '6'),
  (('كرتون', 'Cardboard'), '3', '2.1', '4.5'),
  (('معادن', 'Metal'), '20', '14', '26'),
];

const siteKinds = <P>[
  ('مواطن', 'Household'),
  ('كافيه أو مطعم', 'Café or restaurant'),
  ('مصنع', 'Factory'),
  ('مشتري خامات', 'Material buyer'),
  ('شريك آخر', 'Other'),
];
