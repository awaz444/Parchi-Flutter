import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class BrandCard extends StatelessWidget {
  final String name;
  final String image;

  const BrandCard({
    super.key,
    required this.name,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo Box
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CachedNetworkImage(
              imageUrl: image,
              height: 50,
              width: 50,
              fit: BoxFit.contain,
              placeholder: (context, url) => BlinkingSkeleton(
                width: 50,
                height: 50,
                borderRadius: 8,
                baseColor: AppColors.textSecondary.withOpacity(0.1),
              ),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.restaurant, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 4),

          // Brand Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              name,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}