import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart'; // [NEW] Import SVG
import 'dart:math' as math;

class SpinningLoader extends StatefulWidget {
  final double size;
  final Color? color; 

  const SpinningLoader({super.key, this.size = 24.0, this.color});

  @override
  State<SpinningLoader> createState() => _SpinningLoaderState();
}

class _SpinningLoaderState extends State<SpinningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
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
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SvgPicture.asset(
            'assets/parchi-icon-new.svg',
            width: widget.size,
            height: widget.size,
            colorFilter: widget.color != null 
                ? ColorFilter.mode(widget.color!, BlendMode.srcIn)
                : null,
          ),
        );
      },
    );
  }
}
