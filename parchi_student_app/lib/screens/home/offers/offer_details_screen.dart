import 'package:flutter/material.dart';
import '../../../utils/colours.dart';
import '../../../models/offer_model.dart';
import '../../../services/offers_service.dart';

class OfferDetailsScreen extends StatefulWidget {
  final String offerId;

  const OfferDetailsScreen({super.key, required this.offerId});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  late Future<OfferModel> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = offersService.getOfferDetails(widget.offerId);
  }

  @override
  void didUpdateWidget(covariant OfferDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offerId != widget.offerId) {
      setState(() {
        _detailsFuture = offersService.getOfferDetails(widget.offerId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: FutureBuilder<OfferModel>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            // 1. Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            // 2. Error
            else if (snapshot.hasError) {
              return Center(child: Text("Failed to load: ${snapshot.error}"));
            }
            // 3. Data Loaded
            else if (snapshot.hasData) {
              final offer = snapshot.data!;

              return Column(
                children: [
                  // --- TOP NAVIGATION ---
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Row(
                          children: [
                            IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: AppColors.textPrimary),
                                onPressed: () {}),
                            IconButton(
                                icon: const Icon(Icons.favorite_border,
                                    color: AppColors.textPrimary),
                                onPressed: () {}),
                            IconButton(
                                icon: const Icon(Icons.share,
                                    color: AppColors.textPrimary),
                                onPressed: () {}),
                          ],
                        )
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 1. MERCHANT HEADER ---
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  offer.merchant?.businessName ?? "Merchant",
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight
                                        .w900, // Extra bold like the screenshot
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star,
                                        color: AppColors.warning, size: 18),
                                    SizedBox(width: 4),
                                    Text(
                                      "4.2",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      " (1000+ ratings)",
                                      style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          const SizedBox(height: 24),

                          // --- 4. "SPECIAL OFFERS" SECTION HEADER ---
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.local_offer,
                                        color: AppColors.secondary, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Special offers for you",
                                      style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  offer.formattedDiscount, // e.g. "30% OFF"
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // --- 5. OFFER CARDS (Horizontal List Style) ---
                          // Since API returns 1 offer, we display it as a card.
                          // I'll make a grid-like item but sitting in a horizontal scroll view to match layout.
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _buildOfferProductCard(offer),
                                // Mocking a second card just to show the layout effect,
                                // referencing the same offer but you can remove this
                                const SizedBox(width: 16),
                                Opacity(
                                    opacity: 0.5,
                                    child: _buildOfferProductCard(offer)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return const SizedBox();
          },
        ),
      ),
    );
  }

  // --- HELPER WIDGET: THE PRODUCT CARD ---
  Widget _buildOfferProductCard(OfferModel offer) {
    // Logic to get image
    final displayImage = offer.imageUrl ??
        offer.merchant?.logoPath ??
        "https://placehold.co/600x600/png?text=Offer";

    return Container(
      width: 160, // Fixed width like the "Half Dozen Box" card
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Box
          Stack(
            children: [
              Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(displayImage),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Add (+) Button
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  height: 32,
                  width: 32,
                  decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.textPrimary.withOpacity(0.12),
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ]),
                  child:
                      const Icon(Icons.add, color: AppColors.primary, size: 20),
                ),
              )
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            offer.title, // e.g., "Half Dozen Box"
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          // Price / Discount Row
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Redeem Now",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary, // Pink color like the screenshot
                ),
              ),
              const SizedBox(height: 2),
              if (offer.discountValue > 0)
                Text(
                  "Valid until ${offer.validUntil.day}/${offer.validUntil.month}",
                  style: const TextStyle(
                    fontSize: 12,
                    decoration: TextDecoration
                        .none, // Removed strikethrough as we don't have old price
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
