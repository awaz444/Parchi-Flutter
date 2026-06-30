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
import 'filter_bottom_sheet.dart';
// import 'CLIENT_DEMO_ad_banner_16x9_mockup.dart'; // CLIENT DEMO ONLY — disabled
// import '../../widgets/home_screen_restraunts_widgets/CLIENT_DEMO_ad_card_1x1_mockup.dart'; // CLIENT DEMO ONLY — disabled

import '../../screens/home/merchant_details_screen.dart';
import '../../models/merchant_detail_model.dart';
import '../../models/student_merchant_model.dart';

import '../../providers/home_ui_provider.dart';
import '../../providers/user_provider.dart';

class HomeSheetContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final String searchQuery;

  /// Height of the collapsed header bar — used as top spacer so content
  /// starts below the fixed header overlay.
  final double headerSpacerHeight;

  /// The fully-built ParchiCard widget, constructed in HomeScreen and passed
  /// down so this widget stays provider-agnostic for the card.
  final Widget parchiCardWidget;

  /// True when the user has typed something in the search bar.
  /// When true: card, brands, offers, and the "All Restaurants" header are
  /// hidden — only the search bar (in the fixed header) and the filtered
  /// restaurant cards remain visible.
  final bool isSearching;

  const HomeSheetContent({
    super.key,
    required this.scrollController,
    required this.headerSpacerHeight,
    required this.parchiCardWidget,
    this.searchQuery = "",
    this.isSearching = false,
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

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
    final merchantState = ref.watch(studentMerchantsProvider);
    int filterCount = 0;
    if (merchantState.selectedCategory != null) filterCount++;
    if (merchantState.selectedSubCategory != null) filterCount++;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const FilterBottomSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filterCount > 0
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.lightCanvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: filterCount > 0 ? AppColors.primary : Colors.grey[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: filterCount > 0 ? AppColors.primary : AppColors.textPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              "Filter",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color:
                    filterCount > 0 ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            if (filterCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  filterCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

  // ── Refresh ────────────────────────────────────────────────────────────────

  Future<void> _refreshData() async {
    ref.read(homeUIProvider.notifier).startRefreshSequence();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _onMerchantTap(BuildContext context, String merchantId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            _MerchantDetailsScreenWrapper(merchantId: merchantId),
      ),
    );
  }

  // ── Skeleton helpers ───────────────────────────────────────────────────────

  Widget _buildBrandSkeleton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Match the Card boundary
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.backgroundLight),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BlinkingSkeleton(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 12,
                baseColor: AppColors.textSecondary.withOpacity(0.1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Match the Brand Name formatting
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: BlinkingSkeleton(
              width: double.infinity,
              height: 11,
              baseColor: Colors.grey.withOpacity(0.15)),
        ),
      ],
    );
  }

  Widget _buildOfferSkeleton() {
    return Container(
      width: 160,
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
          BlinkingSkeleton(
              width: double.infinity,
              height: 105,
              borderRadius: 12,
              baseColor: Colors.grey.withOpacity(0.15)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BlinkingSkeleton(
                    width: 100,
                    height: 14,
                    baseColor: Colors.grey.withOpacity(0.15)),
                const SizedBox(height: 4),
                BlinkingSkeleton(
                    width: 60,
                    height: 12,
                    baseColor: Colors.grey.withOpacity(0.15)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantListItemSkeleton() {
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
          BlinkingSkeleton(
              width: double.infinity,
              height: 180,
              borderRadius: 16,
              baseColor: Colors.grey.withOpacity(0.15)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    BlinkingSkeleton(
                        width: 150,
                        height: 16,
                        baseColor: Colors.grey.withOpacity(0.15)),
                    BlinkingSkeleton(
                        width: 16,
                        height: 16,
                        borderRadius: 4,
                        baseColor: Colors.grey.withOpacity(0.15)),
                  ],
                ),
                const SizedBox(height: 4),
                BlinkingSkeleton(
                    width: 80,
                    height: 13,
                    baseColor: Colors.grey.withOpacity(0.15)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Oops!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 160,
              height: 48,
              child: ElevatedButton(
                onPressed: () => ref.read(studentMerchantsProvider.notifier).loadInitial(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Try Again",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final homeUIState = ref.watch(homeUIProvider);
    final isSkeletonLoading = homeUIState.isSkeletonLoading;

    final offersAsync = ref.watch(featuredOffersProvider);
    final merchantState = ref.watch(studentMerchantsProvider);

    // Pull-to-refresh indicator height
    const double indicatorSize = 100.0;

    return CustomRefreshIndicator(
      onRefresh: _refreshData,
      offsetToArmed: indicatorSize,
      builder: (BuildContext context, Widget child,
          IndicatorController controller) {
        return Stack(
          children: <Widget>[
            // ── The pull-to-refresh loader ────────────────────────────────
            // Because the card is now part of the scroll content, this loader
            // renders between the fixed header and the card — exactly the right
            // place visually (right above the card when you pull).
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return SizedBox(
                  // Positioned just below the header spacer so it lands
                  // snugly between the search bar and the card.
                  height: widget.headerSpacerHeight +
                      controller.value * indicatorSize,
                  width: double.infinity,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: controller.value * indicatorSize,
                      child: Center(
                        child: ParchiLoader(
                          isLoading: controller.isLoading,
                          progress: controller.value,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── Main content (pushed down by indicator) ───────────────────
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
          // ── Spacer: behind the fixed header ──────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(height: widget.headerSpacerHeight),
          ),

          // ── Parchi Card ───────────────────────────────────────────────────
          // Hidden when user is searching. AnimatedSize collapses it smoothly
          // so the restaurant list slides straight up to the header.
          SliverToBoxAdapter(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: widget.isSearching
                  ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                      child: widget.parchiCardWidget,
                    ),
            ),
          ),

          // ── CLIENT DEMO MOCKUP: 16:9 ad banner under the Parchi Card ──────
          // Disabled.
          // if (!widget.isSearching)
          //   const SliverToBoxAdapter(
          //     child: Padding(
          //       padding: EdgeInsets.only(top: 12),
          //       child: AdBanner16x9Mockup(),
          //     ),
          //   ),

          // ── Gap between card and first section ───────────────────────────
          if (!widget.isSearching)
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // ── SECTION 1: TOP BRANDS ─────────────────────────────────────────
          if (!widget.isSearching)
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

          if (!widget.isSearching)
            const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // Brands grid — SliverGrid measures its own height, no fixed SizedBox needed.
          if (!widget.isSearching)
            ref.watch(brandsProvider).when(
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildBrandSkeleton(),
                    childCount: 6,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                  ),
                ),
              ),
              error: (err, stack) => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildBrandSkeleton(),
                    childCount: 6,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                  ),
                ),
              ),
              data: (brands) {
                if (isSkeletonLoading) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildBrandSkeleton(),
                        childCount: 6,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 18,
                      ),
                    ),
                  );
                }

                if (brands.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("No brands available"),
                    ),
                  );
                }

                final displayBrands = brands.take(6).toList();

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // CLIENT DEMO MOCKUP (disabled): last grid box was a
                        // 1:1 ad instead of a brand.
                        // if (index == displayBrands.length - 1) {
                        //   return const AdCard1x1Mockup();
                        // }
                        final brand = displayBrands[index];
                        return GestureDetector(
                          onTap: () => _onMerchantTap(context, brand.id),
                          child: BrandCard(
                            name: brand.businessName,
                            image: brand.logoPath ??
                                "https://placehold.co/100x100/png?text=No+Image",
                          ),
                        );
                      },
                      childCount: displayBrands.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 18,
                    ),
                  ),
                );
              },
            ),

          // ── SECTION 2: FEATURED OFFERS ────────────────────────────────────
          if (!widget.isSearching)
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

          if (!widget.isSearching)
            SliverToBoxAdapter(
              child: SizedBox(
                // Proportional to screen width so it scales across all devices.
                // 0.42 gives ~158px on a 375px-wide phone and ~180px on wider phones.
                height: MediaQuery.sizeOf(context).width * 0.42,
                child: offersAsync.when(
                  loading: () => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) =>
                        _buildOfferSkeleton(),
                  ),
                  error: (err, stack) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    itemBuilder: (context, index) =>
                        _buildOfferSkeleton(),
                  ),
                  data: (offers) {
                    if (isSkeletonLoading) {
                      return ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: 3,
                        itemBuilder: (context, index) =>
                            _buildOfferSkeleton(),
                      );
                    }

                    if (offers.isEmpty) {
                      return const Center(
                        child: Text(
                          "No active offers right now.",
                          style:
                              TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: offers.length,
                      itemBuilder: (context, index) {
                        final offer = offers[index];
                        final String displayImage =
                            offer.merchant?.bannerUrl ??
                                offer.imageUrl ??
                                "https://placehold.co/600x300/png?text=No+Image";

                        final branchNames = offer.branches != null &&
                                offer.branches!.isNotEmpty
                            ? offer.branches!
                                .map((b) => b.branchName)
                                .join(', ')
                            : (offer.branchName ?? "All Branches");

                        return GestureDetector(
                          onTap: () {
                            if (offer.merchant != null) {
                              _onMerchantTap(
                                  context, offer.merchant!.id);
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

          // ── SECTION 3: ALL RESTAURANTS header ────────────────────────────
          // Hidden when searching — we go straight to cards.
          if (!widget.isSearching)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Explore",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    _buildFilterButton(context, ref),
                  ],
                ),
              ),
            ),

          // When searching, add a small top gap so cards don't appear right
          // against the header bar.
          if (widget.isSearching)
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Restaurant list (always shown, filtered when searching) ───────
          if (isSkeletonLoading ||
              (merchantState.isLoading && merchantState.items.isEmpty))
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildRestaurantListItemSkeleton(),
                  childCount: 4,
                ),
              ),
            )
          else if (merchantState.error != null &&
              merchantState.items.isEmpty)
            _buildErrorState(merchantState.error!)
          else
            Builder(
              builder: (context) {
                final filteredMerchants = merchantState.items;

                if (filteredMerchants.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          widget.searchQuery.isNotEmpty
                              ? "No results found for '${widget.searchQuery}'"
                              : "No restaurants available yet.",
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == filteredMerchants.length) {
                          if (merchantState.isLoadingMore) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child: SizedBox(
                                  height: 60,
                                  width: 60,
                                  child: ParchiLoader(
                                      isLoading: true, progress: 0),
                                ),
                              ),
                            );
                          }
                          return const SizedBox(height: 50);
                        }
                        final merchant = filteredMerchants[index];
                        return GestureDetector(
                          onTap: () =>
                              _onMerchantTap(context, merchant.id),
                          child: RestaurantBigCard(
                            name: merchant.businessName,
                            image: merchant.bannerUrl ??
                                "https://placehold.co/600x300/png?text=No+Image",
                            category:
                                merchant.category ?? "General",
                          ),
                        );
                      },
                      childCount: filteredMerchants.length +
                          (merchantState.hasMore || widget.searchQuery.isEmpty ? 1 : 0),
                    ),
                  ),
                );
              },
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter header delegate (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.textSecondary.withOpacity(0.3)),
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
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) =>
      false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom loader widget (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
      duration: const Duration(seconds: 1),
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

// ─────────────────────────────────────────────────────────────────────────────
// Merchant details wrapper (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
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
            icon:
                const Icon(Icons.arrow_back, color: AppColors.textPrimary),
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
                const Text(
                  'Failed to load merchant details',
                  style: TextStyle(
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