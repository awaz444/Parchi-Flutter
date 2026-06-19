import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class BrandCard extends StatelessWidget {
  final String name;
  final String image;
  final bool showName;

  const BrandCard({
    super.key,
    required this.name,
    required this.image,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Card (Logo only)
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (context, url) => BlinkingSkeleton(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 12,
                  baseColor: AppColors.textSecondary.withOpacity(0.1),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.restaurant, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 8),

          // Brand Name (Outside the card)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}