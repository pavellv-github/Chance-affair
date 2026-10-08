import 'package:flutter/material.dart';

import '../theme.dart';

/// Логотип: оранжевая четырёхлучевая звезда.
class SparkLogo extends StatelessWidget {
  const SparkLogo({super.key, this.size = 28, this.color = AppColors.onInk});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _SparkPainter(color));
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final path = Path()
      ..moveTo(c.dx, 0)
      ..quadraticBezierTo(c.dx, c.dy, w, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, h)
      ..quadraticBezierTo(c.dx, c.dy, 0, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.color != color;
}

/// Шапка экрана: логотип, дата/действие справа, крупный заголовок.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const SparkLogo(), const Spacer(), ?trailing]),
          const SizedBox(height: 20),
          Text(title, style: theme.textTheme.displaySmall),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onInkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Таблетки-переключатели как Day / Week / Month на референсе.
class PillSelector<T> extends StatelessWidget {
  const PillSelector({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.dark = true,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T>? onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final v in values)
          Semantics(
            selected: v == selected,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: onChanged == null ? null : () => onChanged!(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: v == selected ? AppColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  labelOf(v),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: v == selected
                        ? Colors.white
                        : dark
                        ? AppColors.onInk
                        : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Оранжевый бейдж справа сверху (как «Friday, 9 Dec [1]»).
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.onInkMuted, fontWeight: FontWeight.w600),
    );
  }
}

/// Скруглённая секция-панель.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = AppColors.sage,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: child,
    );
  }
}
