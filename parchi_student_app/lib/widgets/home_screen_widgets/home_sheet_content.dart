import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../utils/colours.dart';
import '../../providers/offers_provider.dart';
import '../../providers/brands_provider.dart';
import '../../providers/merchants_provider.dart';
import 'package:parchi_student_app/widgets/home_screen_restraunts_widgets/brand_card.dart';
import '../home_screen_restraunts_widgets/restaurant_big_card.dart';
import '../home_screen_restraunts_widgets/restaurant_medium_card.dart';
import '../common/blinking_skeleton.dart';

import '../../screens/home/merchant_details_screen.dart';
import '../../models/merchant_detail_model.dart';
import '../../models/student_merchant_model.dart';

import '../../providers/home_ui_provider.dart'; // [NEW]
import '../../providers/user_provider.dart'; // [NEW] Added for explicit refresh if needed

class HomeSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final String searchQuery;

  const HomeSheetContent({
    super.key,
    required this.scrollController,
    this.searchQuery = "",
  });

  @override
  ConsumerState<HomeSheetContent> createState() => _HomeSheetContentState();
}

class _HomeSheetContentState extends ConsumerState<HomeSheetContent> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      ref.read(studentMerchantsProvider.notifier).loadMore();
    }
  }

  bool get _isBottom {
    if (!widget.scrollController.hasClients) return false;
    final maxScroll = widget.scrollController.position.maxScrollExtent;
    final currentScroll = widget.scrollController.position.pixels;
    return currentScroll >= (maxScroll * 0.9);
  }

  // --- REFRESH LOGIC ---
  Future<void> _refreshData() async {
    // 1. Force the spinner to show for at least 1 second (per requirement)
    await Future.delayed(const Duration(seconds: 1));
    
    // 2. Trigger the Pulse -> Skeleton -> Data Fetch sequence
    // We don't await this because we want the spinner to close while the rest happens
    ref.read(homeUIProvider.notifier).startRefreshSequence();
  }

  // --- NAVIGATION LOGIC ---




  // --- SKELETON LOADERS ---
  Widget _buildBrandSkeleton() {
    return Column(
      children: [
        BlinkingSkeleton(
          width: 70,
          height: 70,
          borderRadius: 35, // Circle
          baseColor: Colors.grey.withOpacity(0.15),
        ),
        const SizedBox(height: 8),
        BlinkingSkeleton(
            width: 50, height: 10, baseColor: Colors.grey.withOpacity(0.15)),
      ],
    );
  }

  Widget _buildOfferSkeleton() {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.lightCanvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BlinkingSkeleton(
              width: double.infinity,
              height: 80, // Reduced to prevent overflow (100 -> 80)
              borderRadius: 12,
              baseColor: Colors.grey.withOpacity(0.15)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: BlinkingSkeleton(
                width: 140, height: 16, baseColor: Colors.grey.withOpacity(0.15)),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: BlinkingSkeleton(
                width: 80, height: 10, baseColor: Colors.grey.withOpacity(0.15)),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantListItemSkeleton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: AppColors.lightCanvas,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
      child: Column(
        children: [
          BlinkingSkeleton(
              width: double.infinity,
              height: 160,
              borderRadius: 20,
              baseColor: Colors.grey.withOpacity(0.15)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BlinkingSkeleton(
                        width: 150,
                        height: 20,
                        baseColor: Colors.grey.withOpacity(0.15)),
                    BlinkingSkeleton(
                        width: 60,
                        height: 24,
                        borderRadius: 12,
                        baseColor: Colors.grey.withOpacity(0.15)),
                  ],
                ),
                const SizedBox(height: 8),
                BlinkingSkeleton(
                    width: 100, height: 12, baseColor: Colors.grey.withOpacity(0.15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _onMerchantTap(BuildContext context, String merchantId) {
    // Navigate to merchant details screen which will fetch data using the provider
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MerchantDetailsScreenWrapper(merchantId: merchantId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeUIState = ref.watch(homeUIProvider);
    final isSkeletonLoading = homeUIState.isSkeletonLoading;

    // effective data providers (force loading if sequence dictates)
    // We don't change the actual provider state, we just ignore data and show skeleton
    
    final offersAsync = ref.watch(featuredOffersProvider);
    final merchantState = ref.watch(studentMerchantsProvider);
    const double indicatorSize = 100.0;

    final isSearching = widget.searchQuery.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.lightCanvas,
      ),
      child: CustomRefreshIndicator(
        onRefresh: _refreshData,
        offsetToArmed: indicatorSize,
        builder: (BuildContext context, Widget child,
            IndicatorController controller) {
          return Stack(
            children: <Widget>[
              // 1. The Animated Custom Loader (Stays at the top)
              AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  return SizedBox(
                    height: controller.value * indicatorSize,
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

              // 2. The Main Content (Pushes down as you drag)
              Transform.translate(
                offset: Offset(0.0, controller.value * indicatorSize),
                child: child,
              ),
            ],
          );
        },
        child: CustomScrollView(
          controller: widget.scrollController,
          physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // --- SECTION 1: TOP BRANDS (GRID) ---
            if (!isSearching)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.0),
                child: Text(
                  "Top Brands",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
              ),
            ),


            if (!isSearching) const SliverToBoxAdapter(child: SizedBox(height: 18)),

            if (!isSearching)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240, // Height for 2 rows of items
                        child: ref.watch(brandsProvider).when(
                      loading: () => GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.05,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return _buildBrandSkeleton();
                        },
                      ),
                      error: (err, stack) => GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.05,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return _buildBrandSkeleton();
                        },
                      ),
                      data: (brands) {
                        if (isSkeletonLoading) {
                           return GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 1.05,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: 6, // Show 6 dummy skeletons
                            itemBuilder: (context, index) {
                              return _buildBrandSkeleton();
                            },
                          );
                        }

                        if (brands.isEmpty) {
                          return const Center(
                              child: Text("No brands available"));
                        }
                        // Take first 6 brands for 2x3 grid
                        final displayBrands = brands.take(6).toList();

                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 1.05,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: displayBrands.length,
                          itemBuilder: (context, index) {
                            final brand = displayBrands[index];
                            return GestureDetector(
                              onTap: () => _onMerchantTap(
                                context,
                                brand.id,
                              ),
                              child: BrandCard(
                                name: brand.businessName,
                                image: brand.logoPath ??
                                    "https://placehold.co/100x100/png?text=No+Image",
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ),

            // --- SECTION 2: ACTIVE OFFERS (CAROUSEL) ---
            if (!isSearching)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Featured Offers",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                    
                  ],
                ),
              ),
            ),

            if (!isSearching)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 158,
                child: offersAsync.when(
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildOfferSkeleton();
                    },
                  ),
                  error: (err, stack) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return _buildOfferSkeleton();
                    },
                  ),
                  data: (offers) {
                    if (isSkeletonLoading) {
                        return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        itemBuilder: (context, index) {
                          return _buildOfferSkeleton();
                        },
                      );
                    }

                    if (offers.isEmpty) {
                      return const Center(
                        child: Text(
                          "No active offers right now.",
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: offers.length,
                      itemBuilder: (context, index) {
                        final offer = offers[index];
                        final String displayImage = offer.merchant?.bannerUrl ??
                            offer.imageUrl ??
                            "https://placehold.co/600x300/png?text=No+Image";

                        final branchNames = offer.branches != null && offer.branches!.isNotEmpty
                            ? offer.branches!.map((b) => b.branchName).join(', ')
                            : (offer.branchName ?? "All Branches");

                        return GestureDetector(
                          onTap: () {
                            if (offer.merchant != null) {
                              _onMerchantTap(context, offer.merchant!.id);
                            }
                          },
                          child: RestaurantMediumCard(
                            name: offer.title,
                            image: displayImage,
                            discount: offer.formattedDiscount,
                            branchName: branchNames,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // --- SECTION 3: ALL RESTAURANTS HEADER ---
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 24, 18, 18),
                child: Text(
                  "All Restaurants",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary),
                ),
              ),
            ),

            // --- ALL RESTAURANTS LIST ---
            // --- FAKE ASYNC HANDLING FOR NEW STATE ---
            if (isSkeletonLoading || (merchantState.isLoading && merchantState.items.isEmpty))
               SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _buildRestaurantListItemSkeleton();
                    },
                    childCount: 4,
                  ),
                ),
              )
            else if (merchantState.error != null && merchantState.items.isEmpty)
               SliverToBoxAdapter(
                 child: Padding(
                   padding: const EdgeInsets.all(20),
                   child: Center(child: Text("Error: ${merchantState.error}")),
                 ),
               )
            else
               Builder(
                builder: (context) {
                final merchants = merchantState.items;
                // [FILTERING LOGIC]
                final filteredMerchants = widget.searchQuery.isEmpty
                    ? merchants
                    : merchants.where((m) {
                        final query = widget.searchQuery.toLowerCase();
                        final name = (m.businessName).toLowerCase();
                        final cat = (m.category ?? "").toLowerCase();
                        return name.contains(query) || cat.contains(query);
                      }).toList();

                if (filteredMerchants.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          widget.searchQuery.isNotEmpty
                              ? "No results found for '${widget.searchQuery}'"
                              : "No restaurants available yet.",
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == filteredMerchants.length) {
                           // Load More Indicator
                           if (merchantState.isLoadingMore) {
                             return const Padding(
                               padding: EdgeInsets.all(16.0),
                               child: Center(
                                 child: SizedBox(
                                   height: 60,
                                   width: 60,
                                   child: ParchiLoader(isLoading: true, progress: 0),
                                 ),
                               ),
                             );
                           }
                           return const SizedBox(height: 50); // Bottom padding
                        }
                        final merchant = filteredMerchants[index];
                        return GestureDetector(
                          onTap: () => _onMerchantTap(context, merchant.id),
                          child: RestaurantBigCard(
                            name: merchant.businessName,
                            image: merchant.bannerUrl ??
                                "https://placehold.co/600x300/png?text=No+Image",
                            category: merchant.category ?? "General",
                          ),
                        );
                      },
                      childCount: filteredMerchants.length + (widget.searchQuery.isEmpty ? 1 : 0),
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ),
      ),
    );
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onFilterTap;

  _FilterHeaderDelegate({required this.onFilterTap});

  @override
  double get minExtent => 50.0;
  @override
  double get maxExtent => 50.0;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.lightCanvas,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
              ),
              child: const Row(
                children: [
                  Text("Offers",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down,
                      size: 18, color: AppColors.textPrimary)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) => false;
}

// --- CUSTOM LOADER WIDGET ---
class ParchiLoader extends StatefulWidget {
  final bool isLoading;
  final double progress;

  const ParchiLoader(
      {super.key, required this.isLoading, required this.progress});

  @override
  State<ParchiLoader> createState() => _ParchiLoaderState();
}

class _ParchiLoaderState extends State<ParchiLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1), // Adjust speed here if needed
      vsync: this,
    );
  }

  @override
  void didUpdateWidget(ParchiLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isLoading && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Rotation Logic:
        // Spin continuously if loading, or rotate based on pull distance
        final double rotationValue = widget.isLoading
            ? _controller.value * 2 * math.pi
            : widget.progress * 2 * math.pi;

        return Transform.rotate(
          angle: rotationValue,
          child: Image.asset(
            'assets/parchi-icon.png',
            width: 120,
            height: 120,
          ),
        );
      },
    );
  }
}

// Wrapper widget to handle loading and error states for merchant details
class _MerchantDetailsScreenWrapper extends ConsumerWidget {
  final String merchantId;

  const _MerchantDetailsScreenWrapper({required this.merchantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantAsync = ref.watch(merchantDetailsProvider(merchantId));

    return merchantAsync.when(
      data: (merchant) => MerchantDetailsScreen(merchant: merchant),
      loading: () => const MerchantDetailsSkeleton(),
      error: (error, stack) => Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Error',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to load merchant details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(merchantDetailsProvider(merchantId));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
