import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../admin/admin_data.dart';
import '../business/business_logic.dart';
import '../buyer/buyer_logic.dart';
import 'client_portal_data.dart';
import 'factory_portal_data.dart';
import 'portal_shell.dart';

bool _real(WidgetRef ref) {
  final user = ref.watch(sessionProvider).value;
  return user != null && !user.isDemo;
}

List<AdminPage> _swap(List<AdminPage> pages, Map<String, List<Block>> blocks) => [
      for (final p in pages) blocks.containsKey(p.id) ? AdminPage(p.id, p.title, p.sub, blocks[p.id]!, acts: p.acts) : p,
    ];

Cell _stage(int stage) => switch (stage) {
      3 => ok('اتوزن', 'Weighed'),
      2 => wn('اتسلم للمخزن', 'Collected'),
      1 => wn('في الطريق', 'On the way'),
      _ => wn('مجدول', 'Scheduled'),
    };

/// Business web portal. In real mode the pickups page shows the account's real shipments.
class ClientPortalApp extends ConsumerWidget {
  const ClientPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pages = clientPages;
    if (_real(ref)) {
      final pickups = ref.watch(businessProvider).pickups;
      pages = _swap(clientPages, {
        'pickups': [
          TableBlock(c('الاستلامات', 'Pickups'), [c('رقم', 'No.'), c('التاريخ', 'Date'), c('الحالة', 'Status'), c('الوزن', 'Weight')], [1.5, 1.5, 2, 1.5], [
            for (final p in pickups) [s('#${p.id}'), s(p.whenEn), _stage(p.stage), s(p.done ? '${fmtKg(p.kg)} kg' : '—')],
          ]),
        ],
      });
    }
    return PortalShell(role: clientRole, accent: EcoColors.buyer, nav: clientNav, pages: pages);
  }
}

/// Factory web portal. In real mode the market and orders pages show the live catalogue and the factory's orders.
class FactoryPortalApp extends ConsumerWidget {
  const FactoryPortalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var pages = factoryPages;
    if (_real(ref)) {
      final orders = ref.watch(buyerProvider).orders;
      final current = lots;
      pages = _swap(factoryPages, {
        'market': [
          TableBlock(c('الدفعات', 'Lots'), [c('الدفعة', 'Lot'), c('المادة', 'Material'), c('المتاح', 'Available'), c('السعر/كجم', 'Price/kg')], [1.5, 3, 2, 2], [
            for (final l in current) [s('L-${l.id}'), s(l.en), s('${fmtKg(l.avail)} kg'), s(l.price.toStringAsFixed(1))],
          ]),
        ],
        'orders': [
          TableBlock(c('الطلبات', 'Orders'), [c('رقم', 'No.'), c('المادة', 'Material'), c('الكمية', 'Qty'), c('الحالة', 'Status')], [1.5, 3, 2, 2], [
            for (final o in orders) [s('#${o.id}'), s(lotOf(o.lot).en), s('${fmtKg(o.qty)} kg'), _stage(o.stage)],
          ]),
        ],
      });
    }
    return PortalShell(role: factoryRole, accent: EcoColors.buyer, nav: factoryNav, pages: pages);
  }
}

String fmtKg(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
