import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;

class ParchiLoader extends StatefulWidget {
  final bool isLoading;
  final double progress;
  final double size;
  final Color color;

  const ParchiLoader({
    super.key,
    required this.isLoading,
    required this.progress,
    this.size = 40.0,
    this.color = Colors.white,
  });

  @override
  State<ParchiLoader> createState() => _ParchiLoaderState();
}

class _ParchiLoaderState extends State<ParchiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ParchiLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rotation Logic:
        // Spin continuously if loading, or rotate based on pull distance
        final double rotationValue = widget.isLoading
            ? _controller.value * 2 * math.pi
            : widget.progress * 2 * math.pi;

        return Transform.rotate(
          angle: rotationValue,
          child: SvgPicture.asset(
            'assets/parchi-icon-new.svg',
            width: widget.size,
            height: widget.size,
            colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
          ),
        );
      },
    );
  }
}
