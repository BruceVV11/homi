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
    'Today',
    'Home',
    'Routines',
    'Supplies',
    'People',
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const itemCount = 5;
        const bubbleSize = 54.0;
        final itemWidth = constraints.maxWidth / itemCount;
        final bubbleLeft =
            (itemWidth * selectedIndex) + ((itemWidth - bubbleSize) / 2);

        return SizedBox(
          height: 84,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: HomiColors.border),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 26,
                        offset: Offset(0, 10),
                        color: Color(0x14000000),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: bubbleLeft,
                top: 0,
                width: bubbleSize,
                height: bubbleSize,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: HomiColors.border),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 18,
                          offset: Offset(0, 6),
                          color: Color(0x16000000),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: HomiColors.peach.withValues(alpha: 0.30),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: _NavIcon(index: selectedIndex, selected: true),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: Row(
                  children: List<Widget>.generate(itemCount, (index) {
                    final selected = index == selectedIndex;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: selected,
                        label: _labels[index],
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => onSelected(index),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(2, 7, 2, 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (selected)
                                  const SizedBox(height: 29)
                                else ...[
                                  _NavIcon(index: index, selected: false),
                                  const SizedBox(height: 4),
                                ],
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  style: TextStyle(
                                    fontSize: 11.5,
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

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.index, required this.selected});

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (index == 1) {
      return HomiMark(size: selected ? 30 : 24);
    }

    final icon = switch (index) {
      0 => selected ? Icons.today_rounded : Icons.today_outlined,
      2 => selected ? Icons.checklist_rounded : Icons.checklist_outlined,
      3 => selected ? Icons.inventory_2_rounded : Icons.inventory_2_outlined,
      4 => selected ? Icons.people_rounded : Icons.people_outline_rounded,
      _ => Icons.circle_outlined,
    };

    return Icon(
      icon,
      size: selected ? 25 : 23,
      color: selected ? HomiColors.coral : HomiColors.slate,
    );
  }
}
