import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class RestaurantMiniCard extends StatelessWidget {
  const RestaurantMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: "https://placehold.co/100x100/png",
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => BlinkingSkeleton(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
                baseColor: AppColors.textSecondary.withOpacity(0.1),
              ),
              errorWidget: (ctx, url, err) => Container(
                color: AppColors.textSecondary.withOpacity(0.1),
                child: const Center(
                  child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "KFC",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary),
        ),
        const Text(
          "20% OFF",
          // Used Error color (Red) for discounts as it grabs attention
          style: TextStyle(
              fontSize: 10,
              color: AppColors.error,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
