import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/merchant_detail_model.dart';
import '../../utils/colours.dart';
import '../../widgets/common/parchi_refresh_loader.dart';
import '../../widgets/common/blinking_skeleton.dart';
import '../../providers/merchants_provider.dart';

class MerchantDetailsScreen extends ConsumerWidget {
  final MerchantDetailModel merchant;

  const MerchantDetailsScreen({super.key, required this.merchant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleBranches =
        merchant.branches.where((b) => b.offers.isNotEmpty).toList();

    Future<void> refresh() async {
      return ref.refresh(merchantDetailsProvider(merchant.id).future);
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            // --- 1. SLIVER APP BAR WITH BANNER ---
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.surface,
              surfaceTintColor: AppColors.surface,
              leading: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.8),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: AppColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: merchant.bannerUrl != null
                    ? CachedNetworkImage(
                        imageUrl: merchant.bannerUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) =>
                            Container(color: AppColors.surfaceVariant),
                      )
                    : Container(color: AppColors.surfaceVariant),
              ),
            ),
          ];
        },
        body: CustomRefreshIndicator(
          onRefresh: refresh,
          offsetToArmed: 100.0,
          builder: (BuildContext context, Widget child,
              IndicatorController controller) {
            return Stack(
              children: <Widget>[
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return SizedBox(
                      height: controller.value * 100.0,
                      width: double.infinity,
                      child: Center(
                        child: ParchiLoader(
                          isLoading: controller.isLoading,
                          progress: controller.value,
                        ),
                      ),
                    );
                  },
                ),
                Transform.translate(
                  offset: Offset(0.0, controller.value * 100.0),
                  child: child,
                ),
              ],
            );
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // --- 2. MERCHANT INFO HEADER ---
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Logo
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.surfaceVariant
                                      .withOpacity(0.5)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: merchant.logoPath != null
                                  ? CachedNetworkImage(
                                      imageUrl: merchant.logoPath!,
                                      fit: BoxFit.contain,
                                      errorWidget: (ctx, url, err) =>
                                          const Icon(Icons.store,
                                              size: 30,
                                              color: AppColors.textSecondary),
                                    )
                                  : const Icon(Icons.store,
                                      size: 30,
                                      color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Name & Category
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant.businessName,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (merchant.category != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      merchant.category!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Terms & Conditions
                      if (merchant.termsAndConditions != null &&
                          merchant.termsAndConditions!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Terms & Conditions",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          merchant.termsAndConditions!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // --- 3. SPACER ---
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // --- 4. BRANCHES & OFFERS LIST ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final branch = visibleBranches[index];
                      return _buildBranchItem(branch);
                    },
                    childCount: visibleBranches.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBranchItem(BranchModel branch) {
    final bonus = branch.bonusSettings;
    final int remaining =
        bonus != null ? (bonus.nextGoal - (bonus.currentRedemptions ?? 0)) : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branch Name & Location
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${branch.address}${branch.city != null ? ', ${branch.city}' : ''}",
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          if (branch.contactPhone != null && branch.contactPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  branch.contactPhone!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          const SizedBox(height: 16),

          // --- OFFERS SECTION ---
          if (branch.offers.isNotEmpty) ...[
            const Text(
              "AVAILABLE OFFERS",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            ...branch.offers.map((offer) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                         padding: const EdgeInsets.all(6),
                         decoration: BoxDecoration(
                           color: AppColors.primary.withOpacity(0.1),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: const Icon(Icons.local_offer_outlined, 
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offer.formattedDiscount,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            if (offer.title.isNotEmpty)
                              Text(
                                offer.title,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ] else
            const Text(
              "No active offers at this branch.",
              style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),

          // --- BONUS SECTION ---
          if (branch.bonusSettings != null &&
              branch.bonusSettings!.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceVariant),
              ),
              child: Column(
                children: [
                   Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "LOYALTY BONUS",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[800],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                   ),
                   const SizedBox(height: 12),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Redeem $remaining more times to unlock ${branch.bonusSettings!.discountDescription}",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "${branch.bonusSettings!.currentRedemptions ?? 0}/${branch.bonusSettings!.nextGoal}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: branch.bonusSettings!.cycleProgress,
                      backgroundColor: Colors.white,
                      color: Colors.amber,
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Keeping Skeleton simple but functional for now
class MerchantDetailsSkeleton extends StatelessWidget {
  const MerchantDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            backgroundColor: AppColors.surface,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Back',
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
               background: Container(color: Colors.grey.withOpacity(0.1)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                 Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    BlinkingSkeleton(width: 60, height: 60, borderRadius: 12, baseColor: Colors.grey.withOpacity(0.2)),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                       BlinkingSkeleton(width: 200, height: 24, baseColor: Colors.grey.withOpacity(0.2)),
                       const SizedBox(height: 8),
                       BlinkingSkeleton(width: 100, height: 16, baseColor: Colors.grey.withOpacity(0.2)),
                    ])
                 ]),
                 const SizedBox(height: 24),
                 BlinkingSkeleton(width: 150, height: 16, baseColor: Colors.grey.withOpacity(0.2)),
                 const SizedBox(height: 8),
                  BlinkingSkeleton(width: double.infinity, height: 12, baseColor: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 8),
                  BlinkingSkeleton(width: 250, height: 12, baseColor: Colors.grey.withOpacity(0.2)),
                 const SizedBox(height: 32),
                 BlinkingSkeleton(width: double.infinity, height: 200, borderRadius: 16, baseColor: Colors.grey.withOpacity(0.2)),
                 const SizedBox(height: 16),
                  BlinkingSkeleton(width: double.infinity, height: 200, borderRadius: 16, baseColor: Colors.grey.withOpacity(0.2)),
              ]),
            ),
          )
        ],
      ),
    );
  }
}