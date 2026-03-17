import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A skeleton placeholder powered by the [shimmer] package.
/// All instances on screen share ONE underlying AnimationController
/// (driven by the Shimmer widget's SingleTickerProviderStateMixin),
/// eliminating the per-instance AnimationController from the old
/// StatefulWidget implementation.
class BlinkingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  /// Used to derive light/dark shimmer colours.
  final Color baseColor;

  const BlinkingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
    this.baseColor = const Color(0x40FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    // Decide shimmer palette based on base colour brightness.
    // White-ish (card skeletons on dark bg): light shimmer.
    // Grey-ish (card skeletons on light bg): grey shimmer.
    final bool isLightVariant = baseColor.red > 150 ||
        baseColor.green > 150 ||
        baseColor.blue > 150;

    final Color shimmerBase = isLightVariant
        ? Colors.white.withOpacity(0.2)
        : Colors.grey.withOpacity(0.25);
    final Color shimmerHighlight = isLightVariant
        ? Colors.white.withOpacity(0.55)
        : Colors.grey.withOpacity(0.55);

    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
