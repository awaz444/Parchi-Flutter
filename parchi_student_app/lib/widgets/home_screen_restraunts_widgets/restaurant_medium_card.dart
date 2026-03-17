import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class RestaurantMediumCard extends StatelessWidget {
  final String name;
  final String image;
  final String discount; // "30% OFF"
  final String branchName; // "Downtown Branch"

  const RestaurantMediumCard({
    super.key,
    required this.name,
    required this.image,
    required this.discount,
    required this.branchName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160, // Fixed width for horizontal scrolling
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: image,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => BlinkingSkeleton(
                    width: double.infinity,
                    height: 100,
                    borderRadius: 12,
                    baseColor: AppColors.textSecondary.withOpacity(0.1),
                  ),
                  errorWidget: (ctx, url, err) => Container(
                    height: 100,
                    color: AppColors.textSecondary.withOpacity(0.3),
                    child: const Center(
                        child: Icon(Icons.broken_image,
                            color: AppColors.textSecondary)),
                  ),
                ),
              ),
              // Discount Tag
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    discount,
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Details Section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  branchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
