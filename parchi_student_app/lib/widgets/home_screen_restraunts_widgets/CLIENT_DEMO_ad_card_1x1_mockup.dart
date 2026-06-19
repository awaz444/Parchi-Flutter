// =========================================================
// CLIENT DEMO MOCKUP — NOT FOR PRODUCTION
// =========================================================
// Shows what a sponsored 1:1 ad would look like occupying one box in the
// "Top Brands" grid. Renders a static sample image from sample_ads/1_1.jpg —
// there is no backend, ad provider, or tracking wired up. Delete this file
// (and its single usage in home_sheet_content.dart) once the client has
// reviewed the placement.
import 'package:flutter/material.dart';
import '../../utils/colours.dart';

class AdCard1x1Mockup extends StatelessWidget {
  const AdCard1x1Mockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(color: AppColors.backgroundLight),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'sample_ads/1_1.jpg',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      "Ad",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
