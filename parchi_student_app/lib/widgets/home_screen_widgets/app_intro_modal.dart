import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/colours.dart';

class AppIntroModal extends StatelessWidget {
  final VoidCallback onDismiss;

  const AppIntroModal({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.lightSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header SVG Icon
            Center(
              child: Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/parchi-icon.svg',
                  colorFilter: const ColorFilter.mode(
                    AppColors.primary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Welcome to Parchi!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIntroPoint(
                      icon: Icons.map_rounded,
                      text:
                          'Explore the app to discover 50+ partner locations in Karachi where your Parchi ID is essentially "student currency." From coffee to textbooks, find where you’re saving next.',
                    ),
                    const SizedBox(height: 16),
                    _buildIntroPoint(
                      icon: Icons.qr_code_rounded,
                      text:
                          'When you\'re at the counter, it\'s simple: tell them your Parchi ID. The app handles the rest while the cashier applies your "Parchi Exclusive" discount.',
                    ),
                    const SizedBox(height: 16),
                    _buildIntroPoint(
                      icon: Icons.loyalty_rounded,
                      text:
                          'Every time you redeem, you’ll see the "punch holes" on your digital ticket fill up. Reach the goal at your favorite spot to unlock exclusive Loyalty Bonuses that regular customers can\'t get.',
                    ),
                    const SizedBox(height: 16),
                    _buildIntroPoint(
                      icon: Icons.leaderboard_rounded,
                      text:
                          'Every "Parchi" you use isn\'t just a discount—it’s a point. Watch yourself climb the city-wide leaderboard and show everyone who the real master of saving is.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dismiss Button
            ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Got it!",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroPoint({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 24,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
