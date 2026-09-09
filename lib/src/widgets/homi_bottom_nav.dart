import 'package:flutter/material.dart';

import '../theme/homi_theme.dart';
import 'homi_brand.dart';

class HomiBottomNav extends StatelessWidget {
  const HomiBottomNav({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _labels = <String>[
    'Overview',
    'Tasks',
    'Home',
    'Supplies',
    'People',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemCount = 5;
        const activeSize = 50.0;
        const activeTop = 8.0;
        final itemWidth = constraints.maxWidth / itemCount;
        final centerX = itemWidth * (selectedIndex + 0.5);
        final activeLeft = centerX - (activeSize / 2);

        return SizedBox(
          height: 88,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HomiNavBackgroundPainter(centerX: centerX),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 230),
                curve: Curves.easeOutCubic,
                left: activeLeft,
                top: activeTop,
                width: activeSize,
                height: activeSize,
                child: IgnorePointer(
                  child: _ActiveBubble(index: selectedIndex),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 68,
                child: Row(
                  children: List<Widget>.generate(itemCount, (index) {
                    final selected = index == selectedIndex;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: _labels[index],
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onSelected(index),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 4, 2, 7),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (selected)
                                  const SizedBox(height: 30)
                                else ...[
                                  _NavIcon(
                                    index: index,
                                    selected: false,
                                    inBubble: false,
                                  ),
                                  const SizedBox(height: 5),
                                ],
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 160),
                                  style: TextStyle(
                                    fontSize: 11.2,
                                    height: 1,
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w700,
                                    color: selected
                                        ? HomiColors.coral
                                        : HomiColors.slate,
                                  ),
                                  child: Text(
                                    _labels[index],
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActiveBubble extends StatelessWidget {
  const _ActiveBubble({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final isHome = index == 2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isHome ? HomiColors.cream : HomiColors.coral,
        shape: BoxShape.circle,
        border: Border.all(
          color: isHome
              ? HomiColors.coral.withValues(alpha: 0.28)
              : HomiColors.coral,
          width: isHome ? 1.2 : 0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 3),
            color: Color(0x15000000),
          ),
        ],
      ),
      child: Center(
        child: _NavIcon(index: index, selected: true, inBubble: true),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.index,
    required this.selected,
    required this.inBubble,
  });

  final int index;
  final bool selected;
  final bool inBubble;

  @override
  Widget build(BuildContext context) {
    if (index == 2) {
      return HomiMark(size: inBubble ? 29 : 22);
    }

    final icon = switch (index) {
      0 => selected
          ? Icons.space_dashboard_rounded
          : Icons.space_dashboard_outlined,
      1 => selected ? Icons.checklist_rounded : Icons.checklist_outlined,
      3 => selected
          ? Icons.inventory_2_rounded
          : Icons.inventory_2_outlined,
      4 => selected ? Icons.people_rounded : Icons.people_outline_rounded,
      _ => Icons.circle_outlined,
    };

    return Icon(
      icon,
      size: inBubble ? 23 : 22,
      color: inBubble && index != 2 ? Colors.white : HomiColors.slate,
    );
  }
}

class _HomiNavBackgroundPainter extends CustomPainter {
  const _HomiNavBackgroundPainter({required this.centerX});

  final double centerX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _surfacePath(size);
    canvas.drawShadow(path, const Color(0x1C000000), 11, false);

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fill);

    final border = Paint()
      ..color = HomiColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(path, border);
  }

  Path _surfacePath(Size size) {
    const bodyTop = 27.0;
    const bodyRadius = 23.0;
    const haloRadius = 33.0;
    const haloCenterY = 33.0;

    final cx = centerX
        .clamp(haloRadius + 1, size.width - haloRadius - 1)
        .toDouble();

    final base = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, bodyTop, size.width, size.height - bodyTop),
          const Radius.circular(bodyRadius),
        ),
      );
    final halo = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(cx, haloCenterY),
          radius: haloRadius,
        ),
      );

    // Unioning a true circle with the rounded bar keeps the active halo
    // circular at every destination, including Overview and People. It avoids
    // the pointed edge created by hand-drawn mound control points.
    return Path.combine(PathOperation.union, base, halo);
  }

  @override
  bool shouldRepaint(covariant _HomiNavBackgroundPainter oldDelegate) {
    return oldDelegate.centerX != centerX;
  }
}
