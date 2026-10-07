import 'package:flutter/material.dart';
import '../../utils/colours.dart';

/// Shared "ALL DONE!" success UI used by merchant QR redemption and partner
/// (Inside Karachi / events) discount redemptions.
class RedemptionSuccessView extends StatefulWidget {
  final String headline;
  final String statusLabel;
  final String? subtitle;
  final String redeemedAtPrimary;
  final String? redeemedAtSecondary;
  final bool isBonus;
  final VoidCallback onDone;

  const RedemptionSuccessView({
    super.key,
    required this.headline,
    this.statusLabel = 'Discount Unlocked',
    this.subtitle,
    required this.redeemedAtPrimary,
    this.redeemedAtSecondary,
    this.isBonus = false,
    required this.onDone,
  });

  @override
  State<RedemptionSuccessView> createState() => _RedemptionSuccessViewState();
}

class _RedemptionSuccessViewState extends State<RedemptionSuccessView>
    with TickerProviderStateMixin {
  late final AnimationController _checkController;
  late final AnimationController _morphController;
  late final AnimationController _successFadeController;
  late final Animation<double> _checkAnimation;
  late final Animation<double> _morphAnimation;
  late final Animation<double> _successFadeAnimation;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _checkAnimation = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _morphAnimation = CurvedAnimation(parent: _morphController, curve: Curves.easeInOutBack);

    _checkController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _morphController.forward();
        });
      }
    });

    _successFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _successFadeAnimation = CurvedAnimation(
      parent: _successFadeController,
      curve: Curves.easeOut,
    );

    _successFadeController.forward();
    _checkController.forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    _morphController.dispose();
    _successFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bonusVisit = widget.isBonus;
    return FadeTransition(
      opacity: _successFadeAnimation,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bonusVisit
                ? const [
                    Color(0xFFFFF6DC),
                    Color(0xFFFFFAF0),
                    Colors.white,
                  ]
                : const [
                    Color(0xFFEEF2FE),
                    Color(0xFFF9FAFF),
                    Colors.white,
                  ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          bonusVisit ? 'BONUS UNLOCKED!' : 'ALL DONE!',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: bonusVisit
                                ? const Color(0xFFB8860B)
                                : const Color(0xFF2D2A3A),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ..._buildConfettiParticles(),
                            ScaleTransition(
                              scale: _checkAnimation,
                              child: _FlippingSuccessIcon(
                                animation: _morphAnimation,
                                front: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: bonusVisit
                                        ? const Color(0xFFFFF3CD)
                                        : const Color(0xFFE2FBE9),
                                    border: Border.all(
                                      color: bonusVisit
                                          ? const Color(0xFFFFE08A)
                                          : const Color(0xFFB3F5C7),
                                      width: 2,
                                    ),
                                  ),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: bonusVisit
                                            ? const [Color(0xFFFFD54F), Color(0xFFFF8F00)]
                                            : const [Color(0xFF2ECC71), Color(0xFF27AE60)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (bonusVisit
                                                  ? const Color(0xFFFF8F00)
                                                  : const Color(0xFF2ECC71))
                                              .withValues(alpha: 0.3),
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      bonusVisit
                                          ? Icons.stars_rounded
                                          : Icons.check_rounded,
                                      size: 46,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                back: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: bonusVisit
                                        ? const Color(0xFFFFF3CD)
                                        : const Color(0xFFE8F1FF),
                                    border: Border.all(
                                      color: bonusVisit
                                          ? const Color(0xFFFFE08A)
                                          : const Color(0xFFB3D4FF),
                                      width: 2,
                                    ),
                                  ),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (bonusVisit
                                                  ? const Color(0xFFFF8F00)
                                                  : const Color(0xFF0069db))
                                              .withValues(alpha: 0.15),
                                          blurRadius: 20,
                                          spreadRadius: 4,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/parchi-app-icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          widget.headline,
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D2A3A),
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.statusLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: bonusVisit
                                ? const Color(0xFFB8860B)
                                : const Color(0xFF8E8E93),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (!bonusVisit &&
                            widget.subtitle != null &&
                            widget.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              widget.subtitle!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8E8E93),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        if (bonusVisit) ...[
                          const SizedBox(height: 28),
                          _buildPremiumBonusSection(widget.headline),
                        ],
                        const SizedBox(height: 28),
                        Container(
                          width: 48,
                          height: 1.5,
                          color: const Color(0xFFE5E5EA),
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'REDEEMED AT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8E8E93),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.redeemedAtPrimary,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D2A3A),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.redeemedAtSecondary != null &&
                            widget.redeemedAtSecondary!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.redeemedAtSecondary!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8E8E93),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: widget.onDone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBonusSection(String headline) {
    return CustomPaint(
      painter: TicketPainter(
        borderColor: const Color(0xFFB8860B),
        borderRadius: 20,
        clipRadius: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, color: Color(0xFF2C2205), size: 16),
                SizedBox(width: 6),
                Text(
                  'LOYALTY BONUS EARNED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C2205),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2C2205),
                height: 1.15,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfettiParticles() {
    return [
      Positioned(
        top: 30,
        left: 15,
        child: Transform.rotate(
          angle: -0.4,
          child: Container(
            width: 8,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 40,
        left: 25,
        child: Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: Color(0xFFFF4081),
            shape: BoxShape.circle,
          ),
        ),
      ),
      Positioned(
        top: 40,
        right: 15,
        child: Transform.rotate(
          angle: 0.6,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4081).withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 30,
        right: 20,
        child: Transform.rotate(
          angle: 0.5,
          child: Container(
            width: 8,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5722),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      Positioned(
        top: 90,
        left: 5,
        child: Transform.rotate(
          angle: 0.8,
          child: Container(
            width: 6,
            height: 12,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      const Positioned(
        top: 100,
        right: 5,
        child: Icon(
          Icons.star_rounded,
          color: Color(0xFFFFD600),
          size: 14,
        ),
      ),
    ];
  }
}

class _FlippingSuccessIcon extends AnimatedWidget {
  final Widget front;
  final Widget back;

  const _FlippingSuccessIcon({
    required Animation<double> animation,
    required this.front,
    required this.back,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final double value = animation.value;
    final double angle = value * 3.141592653589793;
    final bool isFront = angle < 3.141592653589793 / 2;

    return Transform(
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      alignment: Alignment.center,
      child: isFront
          ? front
          : Transform(
              transform: Matrix4.identity()..rotateY(3.141592653589793),
              alignment: Alignment.center,
              child: back,
            ),
    );
  }
}

class TicketPainter extends CustomPainter {
  final Color borderColor;
  final double borderRadius;
  final double clipRadius;

  TicketPainter({
    required this.borderColor,
    this.borderRadius = 16.0,
    this.clipRadius = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF8F00).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final path = Path();

    path.moveTo(borderRadius, 0);
    path.lineTo(size.width - borderRadius, 0);

    path.arcToPoint(
      Offset(size.width, borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );

    path.lineTo(size.width, size.height / 2 - clipRadius);
    path.arcToPoint(
      Offset(size.width, size.height / 2 + clipRadius),
      radius: Radius.circular(clipRadius),
      clockwise: false,
    );

    path.lineTo(size.width, size.height - borderRadius);
    path.arcToPoint(
      Offset(size.width - borderRadius, size.height),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );

    path.lineTo(borderRadius, size.height);

    path.arcToPoint(
      Offset(0, size.height - borderRadius),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );

    path.lineTo(0, size.height / 2 + clipRadius);
    path.arcToPoint(
      Offset(0, size.height / 2 - clipRadius),
      radius: Radius.circular(clipRadius),
      clockwise: false,
    );

    path.lineTo(0, borderRadius);
    path.arcToPoint(
      Offset(borderRadius, 0),
      radius: Radius.circular(borderRadius),
      clockwise: true,
    );

    path.close();

    canvas.save();
    canvas.translate(0, 5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    final gradient = const LinearGradient(
      colors: [
        Color(0xFFFFF7C2),
        Color(0xFFFFD54F),
        Color(0xFFFF8F00),
      ],
      stops: [0.0, 0.45, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);

    final paint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final innerPath = Path();
    const inset = 4.0;
    const innerRadius = 12.0;

    innerPath.moveTo(innerRadius + inset, inset);
    innerPath.lineTo(size.width - innerRadius - inset, inset);
    innerPath.arcToPoint(
      Offset(size.width - inset, innerRadius + inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(size.width - inset, size.height / 2 - clipRadius - 2);
    innerPath.arcToPoint(
      Offset(size.width - inset, size.height / 2 + clipRadius + 2),
      radius: Radius.circular(clipRadius + 2),
      clockwise: false,
    );
    innerPath.lineTo(size.width - inset, size.height - innerRadius - inset);
    innerPath.arcToPoint(
      Offset(size.width - innerRadius - inset, size.height - inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(innerRadius + inset, size.height - inset);
    innerPath.arcToPoint(
      Offset(inset, size.height - innerRadius - inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.lineTo(inset, size.height / 2 + clipRadius + 2);
    innerPath.arcToPoint(
      Offset(inset, size.height / 2 - clipRadius - 2),
      radius: Radius.circular(clipRadius + 2),
      clockwise: false,
    );
    innerPath.lineTo(inset, innerRadius + inset);
    innerPath.arcToPoint(
      const Offset(innerRadius + inset, inset),
      radius: const Radius.circular(innerRadius),
      clockwise: true,
    );
    innerPath.close();

    canvas.drawPath(innerPath, glowPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    canvas.drawPath(path, borderPaint);

    final dashPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double startY = 8.0;
    final double dashX = size.width - 108.0;
    while (startY < size.height - 8.0) {
      canvas.drawLine(Offset(dashX, startY), Offset(dashX, startY + dashHeight), dashPaint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
