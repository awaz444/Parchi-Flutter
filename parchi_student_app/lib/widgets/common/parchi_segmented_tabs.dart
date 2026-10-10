import 'package:flutter/material.dart';

import '../../utils/colours.dart';

class ParchiSegmentedTab {
  final String label;
  final int? badgeCount;

  const ParchiSegmentedTab({required this.label, this.badgeCount});
}

/// Sliding-pill segmented control driven by a [TabController] so the
/// highlight tracks finger-swipes on the matching [TabBarView].
class ParchiSegmentedTabs extends StatelessWidget {
  final TabController controller;
  final List<ParchiSegmentedTab> tabs;
  final Duration animateDuration;
  final Curve animateCurve;

  const ParchiSegmentedTabs({
    super.key,
    required this.controller,
    required this.tabs,
    this.animateDuration = const Duration(milliseconds: 280),
    this.animateCurve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    assert(tabs.length == controller.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF1F4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final gap = tabs.length > 1 ? 4.0 : 0.0;
            final totalGaps = gap * (tabs.length - 1);
            final tabWidth = (constraints.maxWidth - totalGaps) / tabs.length;

            return AnimatedBuilder(
              animation: controller.animation!,
              builder: (context, _) {
                final t = controller.animation!.value
                    .clamp(0.0, (tabs.length - 1).toDouble());
                final pillLeft = t * (tabWidth + gap);

                return Stack(
                  children: [
                    Positioned(
                      left: pillLeft,
                      top: 0,
                      bottom: 0,
                      width: tabWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++) ...[
                          if (i > 0) SizedBox(width: gap),
                          Expanded(
                            child: _SegmentLabel(
                              tab: tabs[i],
                              selectedAmount:
                                  (1.0 - (t - i).abs()).clamp(0.0, 1.0),
                              onTap: () {
                                if (controller.index != i) {
                                  controller.animateTo(
                                    i,
                                    duration: animateDuration,
                                    curve: animateCurve,
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  final ParchiSegmentedTab tab;
  final double selectedAmount;
  final VoidCallback onTap;

  const _SegmentLabel({
    required this.tab,
    required this.selectedAmount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(
      AppColors.textSecondary,
      AppColors.primary,
      selectedAmount,
    )!;
    final badgeBg = Color.lerp(
      Colors.black.withValues(alpha: 0.07),
      AppColors.primary.withValues(alpha: 0.12),
      selectedAmount,
    )!;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.lerp(
                      FontWeight.w600,
                      FontWeight.w800,
                      selectedAmount,
                    ) ??
                    FontWeight.w600,
                color: color,
              ),
            ),
            if (tab.badgeCount != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tab.badgeCount.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
