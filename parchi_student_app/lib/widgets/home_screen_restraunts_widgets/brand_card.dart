import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/colours.dart';
import '../common/blinking_skeleton.dart';

class BrandCard extends StatelessWidget {
  // ── Label metrics ─────────────────────────────────────────────────────────
  // The name block is sized to exactly two lines of text — no more — so the
  // whitespace between the grid and whatever sits below it stays tight even
  // when every brand name is short enough to fit on one line.
  static const double _nameFontSize = 10.5;
  static const double _nameLineHeight = 1.15;
  static const double _nameGap = 8.0; // logo box → first text line

  /// Height of just the two-line text box (respects the user's text scale).
  static double nameBoxHeight(BuildContext context) {
    final line =
        MediaQuery.textScalerOf(context).scale(_nameFontSize) * _nameLineHeight;
    return (line * 2).ceilToDouble();
  }

  /// Total vertical space the card spends below the square logo box:
  /// gap + two-line text box. Feed this into the grid's childAspectRatio so
  /// the logo box stays exactly square.
  static double labelBlockHeight(BuildContext context) =>
      _nameGap + nameBoxHeight(context);

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
          const SizedBox(height: _nameGap),

          // Fixed-height label block so short (1-line) names don't let the
          // Expanded image box grow taller than its neighbours. Sized to two
          // lines exactly — see nameBoxHeight().
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: SizedBox(
              height: nameBoxHeight(context),
              child: Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: _nameFontSize,
                  height: _nameLineHeight,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}