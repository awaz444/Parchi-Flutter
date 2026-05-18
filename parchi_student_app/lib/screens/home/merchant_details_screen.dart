import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import '../../widgets/common/hagrid_text.dart';
import '../../models/merchant_detail_model.dart';
import '../../utils/colours.dart';
import '../../widgets/common/parchi_refresh_loader.dart';
import '../../widgets/common/blinking_skeleton.dart';
import '../../providers/merchants_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design concept: each branch is a physical redeemable coupon/ticket.
// The offer stub sits at the top of the card (bold discount badge, perforated
// divider), the branch details live in the body below it. The loyalty bonus
// renders as a row of "punch holes" that fill as the user redeems — tactile,
// collectible, memorable.
// ─────────────────────────────────────────────────────────────────────────────

class MerchantDetailsScreen extends ConsumerWidget {
  final MerchantDetailModel merchant;

  const MerchantDetailsScreen({super.key, required this.merchant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchantAsync = ref.watch(merchantDetailsProvider(merchant.id));
    final resolvedMerchant = merchantAsync.valueOrNull ?? merchant;
    final bool hasOffers = resolvedMerchant.offers.isNotEmpty;

    Future<void> refresh() async {
      ref.invalidate(merchantDetailsProvider(merchant.id));
      await ref.read(merchantDetailsProvider(merchant.id).future);
    }

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              // Title is invisible while banner is expanded; fades in on collapse.
              title: HagridText(
                resolvedMerchant.businessName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              titleSpacing: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                collapseMode: CollapseMode.pin,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Banner image
                    resolvedMerchant.bannerUrl != null
                        ? CachedNetworkImage(
                            imageUrl: resolvedMerchant.bannerUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: const Color(0xFF1A1A1A)),
                          )
                        : Container(color: const Color(0xFF1A1A1A)),
                    // Bottom gradient so content below reads cleanly
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 80,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: CustomRefreshIndicator(
          onRefresh: refresh,
          offsetToArmed: 100.0,
          builder: (context, child, controller) {
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) => SizedBox(
                    height: controller.value * 100.0,
                    width: double.infinity,
                    child: Center(
                      child: ParchiLoader(
                        isLoading: controller.isLoading,
                        progress: controller.value,
                        color: AppColors.secondary,
                        size: 50,
                      ),
                    ),
                  ),
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
              // ── Merchant identity block ────────────────────────────────
              SliverToBoxAdapter(
                child: _MerchantIdentityBlock(merchant: resolvedMerchant),
              ),

              // ── Merchant unified loyalty (Merchant-wide) ────────────────
              if (resolvedMerchant.merchantLoyalty != null &&
                  resolvedMerchant.merchantLoyalty!.isActive)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: _MerchantLoyaltyCard(merchant: resolvedMerchant),
                  ),
                ),

              // ── Offers List (Each as a ticket) ──────────────────────────
              if (hasOffers)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _OfferCard(
                        merchant: resolvedMerchant,
                        offer: resolvedMerchant.offers[index],
                      ),
                      childCount: resolvedMerchant.offers.length,
                    ),
                  ),
                ),

              // ── "AVAILABLE AT" Section Header ───────────────────────────
              if (resolvedMerchant.branches.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "AVAILABLE AT",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Branch location list ───────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _BranchLocationItem(branch: resolvedMerchant.branches[index]),
                    childCount: resolvedMerchant.branches.length,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Merchant identity: logo + name + category + T&C
// ─────────────────────────────────────────────────────────────────────────────
class _MerchantIdentityBlock extends StatelessWidget {
  final MerchantDetailModel merchant;

  const _MerchantIdentityBlock({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.lightSurface,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: Colors.black.withOpacity(0.08), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: merchant.logoPath != null
                      ? CachedNetworkImage(
                          imageUrl: merchant.logoPath!,
                          fit: BoxFit.contain,
                          errorWidget: (ctx, url, err) => const Icon(
                              Icons.store,
                              size: 28,
                              color: AppColors.textSecondary),
                        )
                      : const Icon(Icons.store,
                          size: 28, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(width: 16),
              // Name + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.businessName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (merchant.category != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          merchant.category!,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
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
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.black.withOpacity(0.07), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 15, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      merchant.termsAndConditions!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.55,
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Standalone card for Merchant-wide loyalty
// ─────────────────────────────────────────────────────────────────────────────
class _MerchantLoyaltyCard extends StatelessWidget {
  final MerchantDetailModel merchant;

  const _MerchantLoyaltyCard({required this.merchant});

  @override
  Widget build(BuildContext context) {
    final loyalty = merchant.merchantLoyalty!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _LoyaltyBonusSection(
        loyalty: loyalty,
        isMerchantWide: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offer card — renders as a physical redeemable ticket.
// ─────────────────────────────────────────────────────────────────────────────
class _OfferCard extends StatelessWidget {
  final MerchantDetailModel merchant;
  final BranchOffer offer;

  const _OfferCard({required this.merchant, required this.offer});

  @override
  Widget build(BuildContext context) {
    final loyalty = offer.offerLoyalty;
    final bool hasOfferLoyalty = loyalty != null && loyalty.isActive;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // ── TOP STUB: discount offer ──────────────────────────────
            _OfferStub(offer: offer),

            // ── PERFORATED DIVIDER ────────────────────────────────────
            const _PerforatedDivider(),

            // ── BOTTOM BODY: merchant info ────────────────────────────
            _OfferTicketBody(merchant: merchant, hasLoyalty: hasOfferLoyalty),

            // ── OFFER-SPECIFIC LOYALTY (if active) ────────────────────
            if (hasOfferLoyalty)
              _LoyaltyBonusSection(
                loyalty: loyalty,
                isMerchantWide: false,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top stub: the big discount badge
// ─────────────────────────────────────────────────────────────────────────────
class _OfferStub extends StatelessWidget {
  final BranchOffer offer;

  const _OfferStub({required this.offer});

  @override
  Widget build(BuildContext context) {
    // Use the brand primary color as the stub background — makes it vivid
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Discount value — very large and dominant
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "PARCHI EXCLUSIVE" label
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.25), width: 1),
                  ),
                  child: const Text(
                    "PARCHI EXCLUSIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // The actual discount — big and proud
                Text(
                  offer.formattedDiscount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                    height: 1.0,
                  ),
                ),
                if (offer.title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  // Support \n line breaks for custom offers
                  Text(
                    offer.title.replaceAll(r'\n', '\n'),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Decorative ticket icon on the right
          Opacity(
            opacity: 0.12,
            child: Transform.rotate(
              angle: -0.25,
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 72,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Perforated tear-line divider
// ─────────────────────────────────────────────────────────────────────────────
class _PerforatedDivider extends StatelessWidget {
  const _PerforatedDivider();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 26),
      painter: _PerforationPainter(),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background fill — bridges stub and body seamlessly
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Left and right notch semicircles (the classic ticket cut-outs)
    // Notch color must match the page scaffold background exactly
    final notchPaint = Paint()..color = AppColors.lightSurface;
    final notchRadius = size.height / 2;

    // Left notch
    canvas.drawCircle(Offset(-notchRadius + 4, size.height / 2),
        notchRadius, notchPaint);
    // Right notch
    canvas.drawCircle(Offset(size.width + notchRadius - 4, size.height / 2),
        notchRadius, notchPaint);

    // Dashed line across the middle
    final dashPaint = Paint()
      ..color = const Color(0xFFDDDAD4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashGap = 5.0;
    double startX = notchRadius + 8;
    final endX = size.width - notchRadius - 8;
    final y = size.height / 2;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, endX), y),
        dashPaint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch body: address, phone
// ─────────────────────────────────────────────────────────────────────────────
class _OfferTicketBody extends StatelessWidget {
  final MerchantDetailModel merchant;
  final bool hasLoyalty;

  const _OfferTicketBody({required this.merchant, required this.hasLoyalty});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 16, 20, hasLoyalty ? 4 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Business name
          Text(
            merchant.businessName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 5),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1.5),
                child: Icon(Icons.info_outline,
                    size: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  "Earn progress on every visit at a valid branch to unlock loyalty rewards.",
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (!hasLoyalty) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _BranchLocationItem extends StatelessWidget {
  final BranchModel branch;

  const _BranchLocationItem({required this.branch});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            branch.name,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${branch.address}${branch.city != null ? ', ${branch.city}' : ''}",
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          if (branch.contactPhone != null &&
              branch.contactPhone!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  branch.contactPhone!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LoyaltyBonusSection extends StatelessWidget {
  final LoyaltySettingsModel loyalty;
  final bool isMerchantWide;

  const _LoyaltyBonusSection({
    required this.loyalty,
    required this.isMerchantWide,
  });

  @override
  Widget build(BuildContext context) {
    final int req = loyalty.redemptionsRequired > 0 ? loyalty.redemptionsRequired : 1;
    final int total = req;
    final int current = (loyalty.currentRedemptions ?? 0) % req;
    final int remaining = total - current;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.star_rounded,
                        color: Color(0xFFD4920A), size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMerchantWide ? "MERCHANT LOYALTY" : "OFFER LOYALTY",
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFD4920A),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              // Counter badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBFBFB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFEEEEEE), width: 1),
                ),
                child: Text(
                  "$current / $total",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            remaining > 0
                ? "Redeem $remaining more time${remaining == 1 ? '' : 's'} to unlock ${loyalty.discountDescription}"
                : "🎉 Bonus unlocked! Enjoy ${loyalty.discountDescription}",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
              height: 1.3,
            ),
          ),

          const SizedBox(height: 14),

          // Punch-hole progress row
          _PunchHoleProgress(total: total, current: current),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Punch hole progress — dots that look like physical ticket punches
// ─────────────────────────────────────────────────────────────────────────────
class _PunchHoleProgress extends StatelessWidget {
  final int total;
  final int current;

  const _PunchHoleProgress({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    // Cap at 10 dots for display; if more, show a regular progress bar instead
    if (total > 10) {
      return _LinearBonusBar(total: total, current: current);
    }

    return Row(
      children: List.generate(total, (index) {
        final bool filled = index < current;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < total - 1 ? 6 : 0),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300 + index * 40),
              curve: Curves.easeOutBack,
              height: 28,
              decoration: BoxDecoration(
                color: filled
                    ? const Color(0xFFD4920A)
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: filled
                      ? const Color(0xFFD4920A)
                      : const Color(0xFFDDDAD4),
                  width: 1.5,
                ),
                boxShadow: filled
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD4920A).withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: filled
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : Text(
                        "${index + 1}",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFBBB8B2),
                        ),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// Falls back to a clean linear bar when goal > 10
class _LinearBonusBar extends StatelessWidget {
  final int total;
  final int current;

  const _LinearBonusBar({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    final double progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppColors.lightSurface,
            valueColor: const AlwaysStoppedAnimation(Color(0xFFD4920A)),
            minHeight: 10,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading state
// ─────────────────────────────────────────────────────────────────────────────
class MerchantDetailsSkeleton extends StatelessWidget {
  const MerchantDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final grey = Colors.grey.withOpacity(0.15);

    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          // Banner skeleton
          SliverAppBar(
            expandedHeight: 220,
            backgroundColor: Colors.grey.withOpacity(0.1),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.grey.withOpacity(0.12)),
            ),
          ),

          // Identity block skeleton
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      BlinkingSkeleton(
                          width: 64,
                          height: 64,
                          borderRadius: 14,
                          baseColor: grey),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlinkingSkeleton(
                              width: 180, height: 22, baseColor: grey),
                          const SizedBox(height: 8),
                          BlinkingSkeleton(
                              width: 80, height: 14, borderRadius: 20, baseColor: grey),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  BlinkingSkeleton(
                      width: double.infinity,
                      height: 48,
                      borderRadius: 10,
                      baseColor: grey),
                  const SizedBox(height: 24),
                  BlinkingSkeleton(width: 100, height: 12, baseColor: grey),
                ],
              ),
            ),
          ),

          // Branch card skeletons
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Column(
                      children: [
                        // Stub skeleton
                        BlinkingSkeleton(
                            width: double.infinity,
                            height: 110,
                            borderRadius: 0,
                            baseColor:
                                AppColors.primary.withOpacity(0.15)),
                        // Body skeleton
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BlinkingSkeleton(
                                  width: 160, height: 18, baseColor: grey),
                              const SizedBox(height: 10),
                              BlinkingSkeleton(
                                  width: double.infinity,
                                  height: 12,
                                  baseColor: grey),
                              const SizedBox(height: 6),
                              BlinkingSkeleton(
                                  width: 200, height: 12, baseColor: grey),
                              const SizedBox(height: 10),
                              BlinkingSkeleton(
                                  width: 120, height: 12, baseColor: grey),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                childCount: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}