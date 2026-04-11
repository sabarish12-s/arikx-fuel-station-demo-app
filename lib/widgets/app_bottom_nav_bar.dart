import 'package:flutter/material.dart';

import 'clay_widgets.dart';
import 'responsive_text.dart';

class AppBottomNavItem {
  const AppBottomNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppBottomNavItem> items;

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveScale.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB8C0DC).withValues(alpha: 0.3),
            offset: const Offset(0, -6),
            blurRadius: 18,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: scale.isCompactPhone ? 68 : 72,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _AppBottomNavTile(
                    item: items[index],
                    selected: index == selectedIndex,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBottomNavTile extends StatelessWidget {
  const _AppBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scale = ResponsiveScale.of(context);
    final color = selected ? kClayHeroStart : kClaySub;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: scale.gap(4),
            vertical: scale.gap(7),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                width: scale.isCompactPhone ? 44 : 48,
                height: 28,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? kClayHeroStart.withValues(alpha: 0.12)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(item.icon, color: color, size: 22),
              ),
              SizedBox(height: scale.gap(3)),
              SizedBox(
                width: double.infinity,
                height: 15,
                child: OneLineScaleText(
                  item.label,
                  alignment: Alignment.center,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    fontSize: scale.font(11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
