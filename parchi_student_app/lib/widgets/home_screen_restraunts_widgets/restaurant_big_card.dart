import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class RestaurantBigCard extends StatelessWidget {
  final String name;
  final String image;
  final String category; // "Fast Food"

  // Default dummy values provided
  const RestaurantBigCard({
    super.key,
    this.name = "Del Frio",
    this.image = "https://placehold.co/600x300/png",
    this.category = "Fast Food",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. IMAGE SECTION
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
            child: CachedNetworkImage(
              imageUrl: image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => BlinkingSkeleton(
                width: double.infinity,
                height: 180,
                borderRadius: 16,
                baseColor: AppColors.textSecondary.withOpacity(0.1),
              ),
              errorWidget: (ctx, url, err) => Container(
                height: 180,
                color: AppColors.textSecondary.withOpacity(0.3),
                child: const Center(
                    child: Icon(Icons.broken_image,
                        color: AppColors.textSecondary)),
              ),
            ),
          ),

          // 2. DETAILS SECTION
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios,
                        size: 16, color: AppColors.textSecondary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  category,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
