import 'package:eco_ui/eco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/strings.dart';

/// Picks the Arabic or English text for the current language.
class Tx {
  const Tx(this.ar);
  final bool ar;
  String call(String a, String e) => ar ? a : e;
}

final txProvider = Provider<Tx>((ref) => Tx(ref.watch(arabicProvider)));

/// 6 -> "6", 6.5 -> "6.5". Digits are always Western (0-9), also in Arabic.
String fmt(num v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)));
}

/// App bar used by every role screen: back arrow when there is one, title, language switch.
class RoleBar extends ConsumerWidget implements PreferredSizeWidget {
  const RoleBar({super.key, required this.title, this.back = true, this.actions = const []});
  final String title;
  final bool back;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return AppBar(
      automaticallyImplyLeading: false,
      leading: back && Navigator.of(context).canPop() ? IconButton(icon: const BackButtonIcon(), onPressed: () => Navigator.of(context).pop()) : null,
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      actions: [
        ...actions,
        TextButton(onPressed: ref.read(arabicProvider.notifier).toggle, child: Text(s.language)),
      ],
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final col = color ?? context.eco.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: col, fontWeight: FontWeight.w700)),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(text, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.eco.inkSoft)),
      );
}

class Kpi extends StatelessWidget {
  const Kpi({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: EcoCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: t.headlineSmall?.copyWith(color: color ?? c.ink)),
          const SizedBox(height: 2),
          Text(label, style: t.bodySmall?.copyWith(color: c.inkSoft)),
        ]),
      ),
    );
  }
}

/// Full width action button. `outlined` is the quiet version, `danger` the destructive one.
class BigButton extends StatelessWidget {
  const BigButton(this.label, {super.key, required this.onTap, this.icon, this.outlined = false, this.danger = false, this.color});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool outlined;
  final bool danger;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ]);
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), foregroundColor: danger ? c.danger : c.ink),
        child: child,
      );
    }
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(backgroundColor: danger ? c.danger : (color ?? c.primary), foregroundColor: Colors.white),
      child: child,
    );
  }
}

/// Number input with minus and plus. Used for bag counts and weights.
class StepperField extends StatelessWidget {
  const StepperField({super.key, required this.value, required this.onChanged, this.step = 1, this.min = 0, this.max = 9999, this.unit});
  final double value;
  final ValueChanged<double> onChanged;
  final double step;
  final double min;
  final double max;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    Widget btn(IconData i, VoidCallback? f) => IconButton.filledTonal(onPressed: f, icon: Icon(i), style: IconButton.styleFrom(backgroundColor: c.surfaceAlt, foregroundColor: c.ink));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove_rounded, value - step >= min ? () => onChanged(value - step) : null),
      SizedBox(
        width: 74,
        child: Text('${fmt(value)}${unit == null ? '' : ' $unit'}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      btn(Icons.add_rounded, value + step <= max ? () => onChanged(value + step) : null),
    ]);
  }
}

/// A camera slot. In preview mode tapping it marks the photo as taken; the real camera is wired in later.
class PhotoSlot extends StatelessWidget {
  const PhotoSlot({super.key, required this.taken, required this.onTap, required this.takeLabel, required this.doneLabel});
  final bool taken;
  final VoidCallback onTap;
  final String takeLabel;
  final String doneLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.base,
        height: 108,
        decoration: BoxDecoration(
          color: taken ? c.surfaceAlt : c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: taken ? c.primary : c.line, width: taken ? 2 : 1.4),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(taken ? Icons.check_circle_rounded : Icons.photo_camera_rounded, size: 30, color: taken ? c.primary : c.inkSoft),
          const SizedBox(height: 8),
          Text(taken ? doneLabel : takeLabel, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: taken ? c.primary : c.ink)),
        ]),
      ),
    );
  }
}

/// A list row inside a card: leading widget, title, subtitle, trailing widget.
class Row3 extends StatelessWidget {
  const Row3({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap});
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.eco;
    final t = Theme.of(context).textTheme;
    return EcoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.titleSmall),
            if (subtitle != null) Text(subtitle!, style: t.bodySmall?.copyWith(color: c.inkSoft)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

void pushPage(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
void replacePage(BuildContext context, Widget page) => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
void popToRoot(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

/// Keeps a phone layout readable on wide screens (web, tablet): a centered column on the paper background.
class PhoneColumn extends StatelessWidget {
  const PhoneColumn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.eco.surfaceAlt,
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child)),
      );
}
