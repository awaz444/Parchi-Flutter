import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import '../../utils/colours.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/redemption_provider.dart';
import '../../models/redemption_model.dart';
import '../common/blinking_skeleton.dart';
import '../../screens/auth/login_screens/login_screen.dart';

// =========================================================
// 1. ENTRY POINT
// =========================================================
class ParchiCard extends ConsumerStatefulWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final bool isFoundersClub;
  final bool isLoading;
  final bool isGuest;
  final bool hasError;

  const ParchiCard({
    super.key,
    this.studentName = "",
    this.studentId = "",
    this.universityName = "",
    this.isGolden = false,
    this.isFoundersClub = false,
    this.isLoading = false,
    this.isGuest = false,
    this.hasError = false,
  });

  @override
  ConsumerState<ParchiCard> createState() => _ParchiCardState();
}

class _ParchiCardState extends ConsumerState<ParchiCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    ));

    if (!widget.isGuest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.invalidate(redemptionStatsProvider);
      });
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) return _buildGuestCard();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: _flipCard,
        child: AnimatedBuilder(
          animation: _flipAnimation,
          builder: (context, child) {
            final angle = _flipAnimation.value * pi;
            final flipTransform = Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle);

            return Transform(
              transform: flipTransform,
              alignment: Alignment.center,
              child: angle < pi / 2
                  ? _buildFrontFace()
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(pi),
                      child: _buildBackFace(),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
        child: Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color:
                widget.isFoundersClub ? AppColors.foundersClub : AppColors.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const _GuestCardContent(),
        ),
      ),
    );
  }

  Widget _buildFrontFace() {
    final goldGradient = const LinearGradient(
      colors: [AppColors.goldStart, AppColors.goldMid, AppColors.goldEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: [0.1, 0.5, 0.9],
    );

    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient = widget.isFoundersClub
        ? null
        : (widget.isGolden ? goldGradient : null);

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: widget.isGolden
            ? [
                BoxShadow(
                  color: AppColors.goldShadow.withOpacity(0.6),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: CardFrontContent(
        studentName: widget.studentName,
        studentId: widget.studentId,
        universityName: widget.universityName,
        isGolden: widget.isGolden,
        isFoundersClub: widget.isFoundersClub,
        isLoading: widget.isLoading,
        hasError: widget.hasError,
      ),
    );
  }

  Widget _buildBackFace() {
    final goldGradient = const LinearGradient(
      colors: [AppColors.goldStart, AppColors.goldMid],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final Color? cardColor = widget.isFoundersClub
        ? AppColors.foundersClub
        : (widget.isGolden ? null : AppColors.primary);

    final Gradient? cardGradient = widget.isFoundersClub
        ? null
        : (widget.isGolden ? goldGradient : null);

    final Color borderColor = widget.isFoundersClub
        ? Colors.white.withOpacity(0.5)
        : (widget.isGolden
            ? AppColors.goldShadow
            : AppColors.primary.withOpacity(0.5));

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildBackContent(),
      ),
    );
  }

  Widget _buildBackContent() {
    final statsAsync = ref.watch(redemptionStatsProvider);

    if (statsAsync.hasValue) {
      return _buildStatsContent(statsAsync.value!);
    } else if (statsAsync.isLoading) {
      return _buildLoadingStats();
    } else if (statsAsync.hasError) {
      return Center(
          child: Text("Error loading stats",
              style: TextStyle(color: AppColors.error, fontSize: 12)));
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildStatsContent(RedemptionStats stats) {
    final dividerColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);

    return Center(
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSingleStat(
                value: "${stats.totalRedemptions}",
                label: "Visits",
                subLabel: "Lifetime"),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSingleStat(
                value: "${stats.bonusesUnlocked}",
                label: "Bonuses",
                subLabel: "Earned"),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSingleStat(
                value: stats.leaderboardPosition > 0
                    ? "#${stats.leaderboardPosition}"
                    : "-",
                label: "Rank",
                subLabel: "Nationwide"),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleStat({
    required String value,
    required String label,
    required String subLabel,
  }) {
    final valueColor =
        widget.isGolden ? AppColors.textPrimary : Colors.white;
    final labelColor =
        widget.isGolden ? AppColors.primary : const Color(0xFFE3E935);
    final subLabelColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.5)
        : Colors.white.withOpacity(0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.0)),
        const SizedBox(height: 6),
        Text(label.toUpperCase(),
            style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 2),
        Text(subLabel,
            style: TextStyle(
                color: subLabelColor,
                fontSize: 9,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildLoadingStats() {
    final dividerColor = widget.isGolden
        ? AppColors.textPrimary.withOpacity(0.1)
        : Colors.white.withOpacity(0.2);
    final skeletonBaseColor = widget.isGolden
        ? Colors.black.withOpacity(0.1)
        : Colors.white.withOpacity(0.3);

    return Center(
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildSkeletonColumn(skeletonBaseColor),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSkeletonColumn(skeletonBaseColor),
            VerticalDivider(
                color: dividerColor, indent: 10, endIndent: 10, width: 1),
            _buildSkeletonColumn(skeletonBaseColor),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonColumn(Color baseColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlinkingSkeleton(width: 40, height: 28, baseColor: baseColor),
        const SizedBox(height: 6),
        BlinkingSkeleton(width: 50, height: 10, baseColor: baseColor),
        const SizedBox(height: 2),
        BlinkingSkeleton(width: 30, height: 9, baseColor: baseColor),
      ],
    );
  }
}

// =========================================================
// 1b. GUEST CARD CONTENT
// =========================================================
class _GuestCardContent extends StatelessWidget {
  const _GuestCardContent();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.credit_card_rounded, color: Colors.white70, size: 36),
          SizedBox(height: 10),
          Text(
            'Sign in to get your Parchi card',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'Tap to create a free account',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// 3. UI HELPER (Front Face Content)
// =========================================================
class CardFrontContent extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final bool isFoundersClub;
  final bool isLoading;
  final bool hasError;

  const CardFrontContent({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    required this.isGolden,
    this.isFoundersClub = false,
    this.isLoading = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.87)
        : AppColors.textOnPrimary;
    final secondaryTextColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.54)
        : AppColors.textOnPrimary.withOpacity(0.7);
    final iconColor = isGolden
        ? AppColors.textOnPrimary.withOpacity(0.3)
        : AppColors.surface.withOpacity(0.05);

    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sentiment_dissatisfied_rounded,
                color: Colors.white70, size: 36),
            const SizedBox(height: 10),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Please check your network',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned(
          right: -90,
          top: -80,
          child: isGolden
              ? Icon(Icons.emoji_events, size: 150, color: iconColor)
              : Transform.flip(
                  flipX: true,
                  child: SvgPicture.asset(
                    'assets/parchi-icon.svg',
                    height: 300,
                    colorFilter: ColorFilter.mode(
                      Colors.white.withOpacity(0.1),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SvgPicture.asset(
                    'assets/ParchiFullTextYellow.svg',
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                        Color(0xFFE3E935), BlendMode.srcIn),
                  ),
                  if (isFoundersClub)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "FOUNDER'S CLUB",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isLoading
                            ? BlinkingSkeleton(
                                width: 150,
                                height: 24,
                                baseColor: Colors.white.withOpacity(0.3))
                            : Text(
                                studentName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: textColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.1),
                              ),
                        const SizedBox(height: 2),
                        isLoading
                            ? BlinkingSkeleton(
                                width: 100,
                                height: 10,
                                baseColor: Colors.white.withOpacity(0.3))
                            : Text(
                                universityName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1),
                              ),
                      ],
                    ),
                  ),
                  isLoading
                      ? BlinkingSkeleton(
                          width: 80,
                          height: 24,
                          baseColor: Colors.white.withOpacity(0.3))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              studentId,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0),
                            ),
                            Text(
                              "PARCHI ID",
                              style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =========================================================
// 4. COMPACT HEADER (Sticky)
// =========================================================

/// The transition design:
///
/// The big ParchiCard (primary-colored rounded rect) and this header share
/// the same background color (AppColors.primary). As the user scrolls, the
/// card physically scrolls up and disappears beneath the header — the header
/// simultaneously materialises from the top. Because both surfaces are the
/// same color, the visual effect is that the card "melts" into the header
/// rather than two separate widgets fading over each other.
///
/// On top of that physical scroll we add:
///   • The card's content fades out quickly (handled in HomeSheetContent
///     via scroll-position-based opacity).
///   • The header's content fades + slides in from a slight upward offset,
///     using [scrollProgress] driven animations — no separate AnimationController
///     needed, the scroll IS the animation timeline.
///
/// Search mode:
///   • When [isSearching] is true, profile avatar slides out to the left and
///     is replaced by a cancel (✕) circle via AnimatedSwitcher.
///   • Notification bell also hides so the search bar can use full width.
class CompactParchiHeader extends StatelessWidget {
  final String studentName;
  final String studentId;
  final String universityName;
  final bool isGolden;
  final String? profilePicture;
  final String studentInitials;
  final VoidCallback onProfileTap;
  final double scrollProgress;
  final VoidCallback onNotificationTap;
  final bool isLoading;
  final bool hasError;
  final bool hasUnreadNotifications;

  // Search
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCancelSearch;

  const CompactParchiHeader({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.universityName,
    this.isGolden = false,
    required this.scrollProgress,
    required this.onNotificationTap,
    this.profilePicture,
    required this.studentInitials,
    required this.onProfileTap,
    required this.searchController,
    required this.searchFocus,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onCancelSearch,
    this.isLoading = false,
    this.hasError = false,
    this.hasUnreadNotifications = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.87)
        : AppColors.textOnPrimary;
    final secondaryTextColor = isGolden
        ? AppColors.textPrimary.withOpacity(0.54)
        : AppColors.textOnPrimary.withOpacity(0.7);

    // ── Background color ──────────────────────────────────────────────────
    // At progress=0 the header is completely transparent (you see the card
    // sitting below it in the scroll view). As the card scrolls up and
    // progress→1 the header fades to fully opaque primary — but because
    // the card beneath is also primary, there is never a visible seam.
    final backgroundColor = Color.lerp(
      Colors.transparent,
      isGolden ? AppColors.goldStart : AppColors.primary,
      scrollProgress,
    );

    // ── Content slide-in ──────────────────────────────────────────────────
    // The student info row (name, uni, ID) in the expanded header slides
    // down from -8px to 0 as progress goes 0→1. This removes the "pop-in"
    // feeling and makes it feel like it flows out of the card.
    // Curve it so most of the motion happens in the second half of the scroll.
    final double contentSlide =
        (1.0 - Curves.easeOut.transform(scrollProgress.clamp(0.0, 1.0))) * -8.0;

    final iconColor = isGolden
        ? AppColors.textOnPrimary.withOpacity(0.3)
        : AppColors.surface.withOpacity(0.05);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        gradient: (isGolden && scrollProgress > 0.5)
            ? LinearGradient(
                colors: [
                  AppColors.goldStart.withOpacity(scrollProgress),
                  AppColors.goldMid.withOpacity(scrollProgress),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        boxShadow: scrollProgress > 0.1
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12 * scrollProgress),
                  blurRadius: 8 * scrollProgress,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Decorative background icon — fades in with scroll
          if (scrollProgress > 0.1)
            Positioned(
              right: -110,
              top: -90,
              child: Opacity(
                opacity: scrollProgress.clamp(0.0, 1.0),
                child: isGolden
                    ? Icon(Icons.emoji_events, size: 150, color: iconColor)
                    : Transform.flip(
                        flipX: true,
                        child: SvgPicture.asset(
                          'assets/parchi-icon.svg',
                          height: 400,
                          colorFilter: ColorFilter.mode(
                            Colors.white.withOpacity(0.1),
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              ),
            ),

          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Row 1: profile / search / notifications ─────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      // Left button: profile avatar OR cancel (when searching)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) {
                          // Slide from left when switching in, slide to left when out
                          final offsetAnim = Tween<Offset>(
                            begin: const Offset(-0.5, 0),
                            end: Offset.zero,
                          ).animate(anim);
                          return SlideTransition(
                            position: offsetAnim,
                            child: FadeTransition(opacity: anim, child: child),
                          );
                        },
                        child: isSearching
                            ? GestureDetector(
                                key: const ValueKey('cancel_btn'),
                                onTap: onCancelSearch,
                                child: Container(
                                  width: 35,
                                  height: 35,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(
                                        scrollProgress > 0.5 ? 0.2 : 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: scrollProgress > 0.5
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              )
                            : isLoading
                                ? Padding(
                                    key: const ValueKey('skeleton_btn'),
                                    padding:
                                        const EdgeInsets.only(right: 8.0),
                                    child: BlinkingSkeleton(
                                      width: 35,
                                      height: 35,
                                      borderRadius: 17.5,
                                      baseColor: AppColors.lightSurface,
                                    ),
                                  )
                                : GestureDetector(
                                    key: const ValueKey('profile_btn'),
                                    onTap: onProfileTap,
                                    child: Container(
                                      width: 35,
                                      height: 35,
                                      margin:
                                          const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: scrollProgress > 0.3
                                            ? Colors.white.withOpacity(0.2)
                                            : AppColors.surfaceVariant,
                                        shape: BoxShape.circle,
                                      ),
                                      child: ClipOval(
                                        child: profilePicture != null
                                            ? CachedNetworkImage(
                                                imageUrl: profilePicture!,
                                                fit: BoxFit.cover,
                                                errorWidget: (context, url,
                                                        error) =>
                                                    Center(
                                                      child: Text(
                                                        studentInitials,
                                                        style: TextStyle(
                                                          color: scrollProgress >
                                                                  0.3
                                                              ? Colors.white
                                                              : AppColors
                                                                  .textSecondary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                              )
                                            : Center(
                                                child: Text(
                                                  studentInitials,
                                                  style: TextStyle(
                                                    color: scrollProgress > 0.3
                                                        ? Colors.white
                                                        : AppColors
                                                            .textSecondary,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                      ),

                      // Search bar
                      Expanded(
                        child: Container(
                          height: 35,
                          decoration: BoxDecoration(
                            color: scrollProgress > 0.5
                                ? Colors.white
                                : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: searchController,
                            focusNode: searchFocus,
                            onChanged: onSearchChanged,
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: "Search restaurants...",
                                hintStyle: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.search,
                                    color: AppColors.textSecondary,
                                    size: 20,
                                  ),
                                ),
                                prefixIconConstraints:
                                    const BoxConstraints(minWidth: 35),
                                border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.only(bottom: 18),
                              ),
                          ),
                        ),
                      ),

                      // Notification bell — hidden when searching
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        child: isSearching
                            ? const SizedBox(width: 0, height: 35)
                            : Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: scrollProgress > 0.5
                                            ? Colors.white.withOpacity(0.2)
                                            : AppColors.lightSurface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: Icon(
                                          Icons.notifications_none,
                                          size: 20,
                                          color: scrollProgress > 0.5
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                        onPressed: onNotificationTap,
                                      ),
                                    ),
                                    if (hasUnreadNotifications)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: scrollProgress > 0.5
                                                ? Colors.white
                                                : AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: scrollProgress > 0.5
                                                  ? AppColors.primary
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // ── Row 2: Student info — slides + fades in ──────────────
                // Uses ClipRect + Align heightFactor trick (existing approach)
                // plus a translate for the smooth slide.
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor:
                        scrollProgress.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, contentSlide),
                      child: Opacity(
                        opacity: scrollProgress.clamp(0.0, 1.0),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 16, 20, 20),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    SizedBox(
                                      width: 180,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 5),
                                          isLoading
                                              ? BlinkingSkeleton(
                                                  width: 120,
                                                  height: 16,
                                                  baseColor: Colors.white
                                                      .withOpacity(0.3),
                                                )
                                              : Text(
                                                  studentName,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: textColor,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w900,
                                                  ),
                                                ),
                                          const SizedBox(height: 1),
                                          isLoading
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4.0),
                                                  child: BlinkingSkeleton(
                                                    width: 80,
                                                    height: 10,
                                                    baseColor: Colors.white
                                                        .withOpacity(0.3),
                                                  ),
                                                )
                                              : Text(
                                                  universityName
                                                      .toUpperCase(),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color:
                                                        secondaryTextColor,
                                                    fontSize: 10,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                    isLoading
                                        ? BlinkingSkeleton(
                                            width: 60,
                                            height: 20,
                                            baseColor: Colors.white
                                                .withOpacity(0.3),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                studentId,
                                                style: TextStyle(
                                                  color: textColor,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                "PARCHI ID",
                                                style: TextStyle(
                                                  color: secondaryTextColor,
                                                  fontSize: 7,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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