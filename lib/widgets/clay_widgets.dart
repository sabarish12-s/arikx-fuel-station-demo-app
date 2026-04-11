import 'package:flutter/material.dart';

import 'responsive_text.dart';

const kClayBg = Color(0xFFECEFF8);
const kClayPrimary = Color(0xFF1A2561);
const kClaySub = Color(0xFF8A93B8);
const kClayHeroStart = Color(0xFF1A3A7A);
const kClayHeroEnd = Color(0xFF0D2460);

BoxDecoration clayCardDecoration({double radius = 20}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFB8C0DC).withValues(alpha: 0.75),
        offset: const Offset(6, 6),
        blurRadius: 16,
      ),
      const BoxShadow(
        color: Colors.white,
        offset: Offset(-5, -5),
        blurRadius: 12,
      ),
    ],
  );
}

class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: clayCardDecoration(radius: radius),
      child: child,
    );
  }
}

class ClaySubHeader extends StatelessWidget {
  const ClaySubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB8C0DC).withValues(alpha: 0.65),
                      offset: const Offset(4, 4),
                      blurRadius: 10,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-3, -3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: kClayPrimary,
                    ),
                    SizedBox(width: 4),
                    OneLineScaleText(
                      'Back',
                      style: TextStyle(
                        color: kClayPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OneLineScaleText(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: kClayPrimary,
              ),
            ),
          ),
          ...(trailing == null ? const <Widget>[] : <Widget>[trailing!]),
        ],
      ),
    );
  }
}
