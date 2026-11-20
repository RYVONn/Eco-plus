import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/kit.dart';

class _Pin {
  const _Pin(this.x, this.y, this.warehouse, this.mats, this.nameAr, this.nameEn, this.dist, this.matsAr, this.matsEn, this.hoursAr, this.hoursEn);
  final double x, y;
  final bool warehouse;
  final List<int> mats;
  final String nameAr, nameEn, dist, matsAr, matsEn, hoursAr, hoursEn;
}

/// Sample points until real locations exist.
const _pins = [
  _Pin(0.62, 0.30, false, [1, 2], 'نقطة تجميع 1', 'Drop-off point 1', '350', 'بلاستيك، ورق، كرتون', 'Plastic, paper, cardboard', '9 ص – 9 م', '9 AM – 9 PM'),
  _Pin(0.26, 0.55, false, [3, 4], 'نقطة تجميع 2', 'Drop-off point 2', '800', 'زجاج، معادن', 'Glass, metal', '10 ص – 8 م', '10 AM – 8 PM'),
  _Pin(0.76, 0.70, true, [1, 2, 3, 4], 'مخزن المثال', 'Example warehouse', '1500', 'كل الخامات', 'All materials', '8 ص – 4 م', '8 AM – 4 PM'),
  _Pin(0.38, 0.80, false, [1], 'نقطة تجميع 3', 'Drop-off point 3', '1200', 'بلاستيك', 'Plastic', '24 ساعة', '24 hours'),
];

class _RoadsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE7EFE6));
    final park = Paint()..color = const Color(0xFFCFE8D2);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(size.width * .05, size.height * .08, size.width * .3, size.height * .14), const Radius.circular(18)), park);
    final big = Paint()..color = Colors.white..strokeWidth = 16..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final small = Paint()..color = Colors.white..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawLine(Offset(0, h * .33), Offset(w, h * .33), big);
    canvas.drawLine(Offset(w * .5, 0), Offset(w * .5, h), big);
    final path = Path()..moveTo(0, h * .55)..cubicTo(w * .25, h * .5, w * .65, h * .6, w, h * .5);
    canvas.drawPath(path, big);
    canvas.drawLine(Offset(w * .22, 0), Offset(w * .22, h * .9), small);
    canvas.drawLine(Offset(w * .8, 0), Offset(w * .8, h * .85), small);
    canvas.drawLine(Offset(0, h * .15), Offset(w, h * .15), small);
    canvas.drawLine(Offset(0, h * .75), Offset(w, h * .75), small);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Nearby drop-off points and warehouses on a stylized map. Preview data.
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  int _filter = 0;
  int? _sel;

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(txProvider);
    final c = context.eco;
    final filters = [t('الكل', 'All'), t('بلاستيك', 'Plastic'), t('ورق', 'Paper'), t('زجاج', 'Glass'), t('معادن', 'Metal')];
    final shown = [for (var i = 0; i < _pins.length; i++) if (_filter == 0 || _pins[i].mats.contains(_filter)) i];
    final sel = _sel != null && shown.contains(_sel) ? _pins[_sel!] : null;
    return Scaffold(
      appBar: RoleBar(title: t('الخريطة', 'Map'), back: false),
      body: Column(children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(label: Text(filters[i]), selected: _filter == i, onSelected: (_) => setState(() {
              _filter = i;
              _sel = null;
            })),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _RoadsPainter())),
              Positioned(left: box.maxWidth * .5 - 9, top: box.maxHeight * .5 - 9, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFF1E6FD9), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)))),
              for (final i in shown)
                Positioned(
                  left: box.maxWidth * _pins[i].x - 22,
                  top: box.maxHeight * _pins[i].y - 44,
                  child: GestureDetector(
                    onTap: () => setState(() => _sel = i),
                    child: AnimatedScale(
                      scale: _sel == i ? 1.25 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(_pins[i].warehouse ? Icons.warehouse_rounded : Icons.recycling_rounded, size: 44, color: _pins[i].warehouse ? c.ink : c.primary),
                    ),
                  ),
                ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: EcoCard(
                  child: sel == null
                      ? Row(children: [Icon(Icons.place_rounded, color: c.primary), const SizedBox(width: 10), Expanded(child: Text('${shown.length} ${t('أماكن قريبة منك', 'places near you')}'))])
                      : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t(sel.nameAr, sel.nameEn), style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text('${sel.dist} ${t('م', 'm')} · ${t(sel.hoursAr, sel.hoursEn)}', style: TextStyle(color: c.inkSoft)),
                          Text(t(sel.matsAr, sel.matsEn), style: TextStyle(color: c.inkSoft)),
                          const SizedBox(height: 10),
                          BigButton(t('وصّلني', 'Take me there'), onTap: () => toast(context, t('الاتجاهات هتشتغل مع الخرائط الحقيقية.', 'Directions come with the real map.'))),
                        ]),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}
