import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

import '../../utils/colours.dart';
import 'parchi_loader.dart';

/// Shared pull-to-refresh: the Parchi icon spins on the way down, then
/// retracts as soon as [onRefresh] returns. Pass a fire-and-forget
/// [onRefresh] (set a skeleton flag, kick off the fetch, return) so the
/// indicator does not sit over a skeleton.
class ParchiPullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color color;
  final double topInset;
  final double indicatorSize;

  const ParchiPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
    this.color = AppColors.secondary,
    this.topInset = 0,
    this.indicatorSize = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: indicatorSize,
      builder:
          (BuildContext context, Widget child, IndicatorController controller) {
        return Stack(
          children: <Widget>[
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return SizedBox(
                  height: topInset + controller.value * indicatorSize,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: controller.value * indicatorSize,
                      child: Center(
                        child: ParchiLoader(
                          isLoading: controller.isLoading,
                          progress: controller.value,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Transform.translate(
              offset: Offset(0.0, controller.value * indicatorSize),
              child: child,
            ),
          ],
        );
      },
      child: child,
    );
  }
}
