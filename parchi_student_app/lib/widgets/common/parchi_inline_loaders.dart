import 'package:flutter/material.dart';

import '../../utils/colours.dart';
import 'parchi_loader.dart';

/// Centered blocking loader for a full page or a section.
class ParchiPageLoader extends StatelessWidget {
  final Color color;
  final double size;

  const ParchiPageLoader({
    super.key,
    this.color = AppColors.primary,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ParchiLoader(
        isLoading: true,
        progress: 0,
        size: size,
        color: color,
      ),
    );
  }
}

/// Footer spinner for infinite-scroll "load more".
class ParchiLoadMoreIndicator extends StatelessWidget {
  final Color color;
  final double size;

  const ParchiLoadMoreIndicator({
    super.key,
    this.color = AppColors.secondary,
    this.size = 25,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: ParchiLoader(
          isLoading: true,
          progress: 1.0,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
