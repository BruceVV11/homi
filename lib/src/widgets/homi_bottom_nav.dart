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
    'Routines',
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
        final itemWidth = constraints.maxWidth / itemCount;
        final centerX = itemWidth * (selectedIndex + 0.5);
        final activeLeft = centerX - (activeSize / 2);

        return SizedBox(
          height: 82,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HomiNavBackgroundPainter(centerX: centerX),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: activeLeft,
                top: 0,
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
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => onSelected(index),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (selected)
                                    const SizedBox(height: 29)
                                  else ...[
                                    _NavIcon(
                                      index: index,
                                      selected: false,
                                      inBubble: false,
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
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
          color: isHome ? HomiColors.border : HomiColors.coral,
          width: isHome ? 1 : 0,
        ),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 6),
            color: Color(0x1C000000),
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
      return HomiMark(size: inBubble ? 31 : 23);
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
      size: inBubble ? 24 : 22,
      color: inBubble ? Colors.white : HomiColors.slate,
    );
  }
}

class _HomiNavBackgroundPainter extends CustomPainter {
  const _HomiNavBackgroundPainter({required this.centerX});

  final double centerX;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    canvas.drawShadow(path, const Color(0x26000000), 14, false);

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

  Path _path(Size size) {
    const top = 14.0;
    const corner = 27.0;
    const bumpHalf = 38.0;
    final cx = centerX.clamp(42.0, size.width - 42.0).toDouble();

    return Path()
      ..moveTo(corner, top)
      ..lineTo(cx - bumpHalf, top)
      ..cubicTo(cx - 27, top, cx - 27, 1, cx, 1)
      ..cubicTo(cx + 27, 1, cx + 27, top, cx + bumpHalf, top)
      ..lineTo(size.width - corner, top)
      ..quadraticBezierTo(size.width, top, size.width, top + corner)
      ..lineTo(size.width, size.height - corner)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - corner,
        size.height,
      )
      ..lineTo(corner, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - corner)
      ..lineTo(0, top + corner)
      ..quadraticBezierTo(0, top, corner, top)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _HomiNavBackgroundPainter oldDelegate) {
    return oldDelegate.centerX != centerX;
  }
}
